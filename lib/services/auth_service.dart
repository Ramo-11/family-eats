import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Listen to Auth State (Logged In vs Logged Out)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get Current User
  User? get currentUser => _auth.currentUser;

  // Login
  Future<void> signIn(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('householdId');
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // 1. Sync RevenueCat Identity (Non-blocking)
        try {
          await Purchases.logIn(credential.user!.uid);
        } catch (e) {
          debugPrint("⚠️ [AuthService] RevenueCat login failed: $e");
        }

        // 2. Sync display name from Firestore if it's missing in Auth
        if (credential.user!.displayName == null ||
            credential.user!.displayName!.isEmpty) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(credential.user!.uid)
              .get();
          final storedName = userDoc.data()?['name'] as String?;
          if (storedName != null && storedName.isNotEmpty) {
            await credential.user!.updateDisplayName(storedName);
            await credential.user!.reload();
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint("❌ [AuthService] Reauth failed: User is null");
      return;
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
    try {
      debugPrint(
        "🚫 [AuthService] Deleting Firebase Auth User: ${_auth.currentUser?.uid}...",
      );

      // Attempt to clear RevenueCat identity first
      try {
        await Purchases.logOut();
      } catch (e) {
        debugPrint(
          "⚠️ [AuthService] RevenueCat logout during delete failed: $e",
        );
      }

      await _auth.currentUser?.delete();
      debugPrint("✅ [AuthService] Firebase Auth User deleted successfully.");
    } on FirebaseAuthException catch (e) {
      debugPrint("❌ [AuthService] Delete failed: ${e.code} - ${e.message}");
      throw _handleAuthError(e);
    } catch (e) {
      debugPrint("❌ [AuthService] Delete failed with unknown error: $e");
      throw e.toString();
    }
  }

  Future<void> signInAnonymously() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('householdId');
      final result = await _auth.signInAnonymously();

      // Sync RevenueCat Identity
      if (result.user != null) {
        try {
          await Purchases.logIn(result.user!.uid);
        } catch (e) {
          debugPrint("⚠️ [AuthService] RevenueCat anon login failed: $e");
        }
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Sign Up (Create new account)
  Future<void> signUp(String email, String password, String name) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('householdId');

      // Update the Profile with the name
      await credential.user?.updateDisplayName(name);
      await credential.user?.reload();

      // Sync RevenueCat Identity
      if (credential.user != null) {
        try {
          await Purchases.logIn(credential.user!.uid);
          await Purchases.setDisplayName(name);
          await Purchases.setEmail(email);
        } catch (e) {
          debugPrint("⚠️ [AuthService] RevenueCat signup failed: $e");
        }
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Sign Out
  Future<void> signOut() async {
    // Reset RevenueCat to anonymous/empty state so next user doesn't inherit Pro
    try {
      await Purchases.logOut();
    } catch (e) {
      debugPrint("⚠️ [AuthService] RevenueCat logout failed: $e");
    }

    // Proceed with Firebase Sign Out
    await _auth.signOut();
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
