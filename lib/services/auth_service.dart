import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../providers/subscription_provider.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Listen to Auth State (Logged In vs Logged Out)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get Current User
  User? get currentUser => _auth.currentUser;

  // Login
  Future<void> signIn(String email, String password) async {
    try {
      // Clear any cached household ID from previous session
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('householdId');

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (credential.user != null) {
        // 1. Sync RevenueCat Identity (Non-blocking)
        await _syncRevenueCatIdentity(credential.user!);

        // 2. Sync display name from Firestore if it's missing in Auth
        await _syncDisplayName(credential.user!);

        debugPrint("✅ Sign in successful for ${credential.user!.email}");
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  Future<void> _syncRevenueCatIdentity(User user) async {
    // Don't sync if we're in the middle of deleting an account
    if (AccountDeletionState.isDeleting) return;

    try {
      await Purchases.logIn(user.uid);
      debugPrint("✅ RevenueCat identity synced");
    } catch (e) {
      debugPrint("⚠️ [AuthService] RevenueCat login failed: $e");
      // Non-fatal - continue even if RevenueCat fails
    }
  }

  Future<void> _syncDisplayName(User user) async {
    try {
      if (user.displayName == null || user.displayName!.isEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final storedName = userDoc.data()?['name'] as String?;
        if (storedName != null && storedName.isNotEmpty) {
          await user.updateDisplayName(storedName);
          await user.reload();
          debugPrint("✅ Display name synced from Firestore: $storedName");
        }
      }
    } catch (e) {
      debugPrint("⚠️ [AuthService] Display name sync failed: $e");
      // Non-fatal - continue even if sync fails
    }
  }

  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("❌ [AuthService] Reauth failed: User is null");
      throw "No user currently signed in";
    }

    debugPrint(
      "🔐 [AuthService] Attempting re-authentication for ${user.email}...",
    );

    if (!user.isAnonymous && user.email != null) {
      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        debugPrint("✅ [AuthService] Re-authentication successful");
      } on FirebaseAuthException catch (e) {
        debugPrint("❌ [AuthService] Re-authentication failed: ${e.code}");
        throw _handleAuthError(e);
      }
    } else {
      debugPrint("⚠️ [AuthService] Skipped re-auth (Guest or No Email)");
    }
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("❌ [AuthService] Delete failed: No user");
      throw "No user to delete";
    }

    try {
      debugPrint(
        "🚫 [AuthService] Deleting Firebase Auth User: ${user.uid}...",
      );

      // Clear RevenueCat identity first (but don't let it trigger Firestore writes)
      // The AccountDeletionState.isDeleting flag should already be set
      try {
        await Purchases.logOut();
        debugPrint("✅ RevenueCat logged out");
      } catch (e) {
        debugPrint(
          "⚠️ [AuthService] RevenueCat logout during delete failed: $e",
        );
        // Continue with deletion even if RevenueCat fails
      }

      // Clear local preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        debugPrint("✅ Local preferences cleared");
      } catch (e) {
        debugPrint("⚠️ [AuthService] Failed to clear preferences: $e");
      }

      // Small delay to ensure RevenueCat listener callbacks have been processed
      // and blocked by the AccountDeletionState.isDeleting flag
      await Future.delayed(const Duration(milliseconds: 100));

      // Delete the Firebase Auth user
      await user.delete();
      debugPrint("✅ [AuthService] Firebase Auth User deleted successfully.");
    } on FirebaseAuthException catch (e) {
      debugPrint("❌ [AuthService] Delete failed: ${e.code} - ${e.message}");
      throw _handleAuthError(e);
    } catch (e) {
      debugPrint("❌ [AuthService] Delete failed with unknown error: $e");
      rethrow;
    }
  }

  Future<void> signInAnonymously() async {
    try {
      // Clear any cached data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('householdId');

      final result = await _auth.signInAnonymously();

      // Sync RevenueCat Identity for anonymous user
      if (result.user != null) {
        await _syncRevenueCatIdentity(result.user!);
        debugPrint("✅ Anonymous sign in successful");
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Sign Up (Create new account)
  Future<void> signUp(String email, String password, String name) async {
    try {
      // Clear any cached data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('householdId');

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update the Profile with the name
      if (credential.user != null) {
        await credential.user!.updateDisplayName(name.trim());
        await credential.user!.reload();

        // Sync RevenueCat Identity
        try {
          await Purchases.logIn(credential.user!.uid);
          await Purchases.setDisplayName(name.trim());
          await Purchases.setEmail(email.trim());
          debugPrint("✅ RevenueCat identity set for new user");
        } catch (e) {
          debugPrint("⚠️ [AuthService] RevenueCat signup sync failed: $e");
          // Non-fatal
        }

        debugPrint("✅ Sign up successful for ${credential.user!.email}");
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      debugPrint("🚪 [AuthService] Signing out...");

      // Reset RevenueCat to anonymous/empty state so next user doesn't inherit Pro
      try {
        await Purchases.logOut();
        debugPrint("✅ RevenueCat logged out");
      } catch (e) {
        debugPrint("⚠️ [AuthService] RevenueCat logout failed: $e");
        // Continue with sign out even if RevenueCat fails
      }

      // Clear local preferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('householdId');
        await prefs.remove('has_seen_tutorial');
      } catch (e) {
        debugPrint("⚠️ [AuthService] Failed to clear preferences: $e");
      }

      // Proceed with Firebase Sign Out
      await _auth.signOut();
      debugPrint("✅ [AuthService] Sign out successful");
    } catch (e) {
      debugPrint("❌ [AuthService] Sign out error: $e");
      // Even if there's an error, try to sign out
      await _auth.signOut();
    }
  }

  // Helper to make Firebase errors readable for humans
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support for help.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.';
      case 'requires-recent-login':
        return 'Please log out and log back in to perform this action.';
      default:
        return 'Authentication failed: ${e.message ?? e.code}';
    }
  }
}

// Providers
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});
