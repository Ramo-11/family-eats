import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';
import 'household_service.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String uid;

  UserService(this.uid);

  /// Get the current user's profile stream
  Stream<Map<String, dynamic>?> getUserProfile() {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.data();
        })
        .handleError((e) {
          debugPrint("Error getting user profile: $e");
          return null;
        });
  }

  /// Initialize a new user (called after signup)
  Future<void> initializeUser(String name, String email) async {
    try {
      // Check if user document already exists
      final existingDoc = await _db.collection('users').doc(uid).get();

      if (existingDoc.exists) {
        // Update existing document
        await _db.collection('users').doc(uid).update({
          'name': name.trim(),
          'email': email.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint("✅ Updated existing user document: $uid");
      } else {
        // Create new document
        await _db.collection('users').doc(uid).set({
          'name': name.trim(),
          'email': email.trim(),
          'householdId': null,
          'onboardingComplete': false,
          'isPro': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint("✅ Created new user document: $uid");
      }
    } catch (e) {
      debugPrint("❌ Error initializing user: $e");
      rethrow;
    }
  }

  Future<void> updateProStatus(bool isPro) async {
    try {
      await _db.collection('users').doc(uid).set({
        'isPro': isPro,
        'proUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("✅ Pro status updated: $isPro");
    } catch (e) {
      debugPrint("❌ Error updating pro status: $e");
      rethrow;
    }
  }

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data()?['onboardingComplete'] == true;
    } catch (e) {
      debugPrint("Error checking onboarding status: $e");
      return false;
    }
  }

  /// Stream to check onboarding status
  Stream<bool> watchOnboardingStatus() {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
          return doc.data()?['onboardingComplete'] == true;
        })
        .handleError((e) {
          debugPrint("Error watching onboarding status: $e");
          return false;
        });
  }

  /// Get user's Pro status
  Future<bool> getProStatus() async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data()?['isPro'] == true;
    } catch (e) {
      debugPrint("Error getting pro status: $e");
      return false;
    }
  }

  /// Get user's household ID
  Future<String?> getHouseholdId() async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data()?['householdId'] as String?;
    } catch (e) {
      debugPrint("Error getting household ID: $e");
      return null;
    }
  }

  /// Join an existing household by ID
  /// Also syncs the user's display name from Firebase Auth
  Future<void> joinHousehold(String householdId, {String? displayName}) async {
    try {
      // Verify household exists first
      final householdDoc = await _db
          .collection('households')
          .doc(householdId)
          .get();
      if (!householdDoc.exists) {
        throw "Household not found";
      }

      final updateData = <String, dynamic>{
        'householdId': householdId,
        'onboardingComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (displayName != null && displayName.isNotEmpty) {
        updateData['name'] = displayName.trim();
      }
      await _db
          .collection('users')
          .doc(uid)
          .set(updateData, SetOptions(merge: true));
      debugPrint("✅ Joined household: $householdId");
    } catch (e) {
      debugPrint("❌ Error joining household: $e");
      rethrow;
    }
  }

  /// Create and join a new household
  Future<String> createAndJoinHousehold(
    String householdName,
    HouseholdService householdService,
  ) async {
    try {
      final householdId = await householdService.createHousehold(
        name: householdName.trim(),
        ownerId: uid,
      );
      await _db.collection('users').doc(uid).set({
        'householdId': householdId,
        'onboardingComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("✅ Created and joined household: $householdId");
      return householdId;
    } catch (e) {
      debugPrint("❌ Error creating household: $e");
      rethrow;
    }
  }

  /// Leave current household (returns to having no household - must rejoin or create)
  Future<void> leaveHousehold() async {
    try {
      await _db.collection('users').doc(uid).set({
        'householdId': null,
        'onboardingComplete': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint("✅ Left household");
    } catch (e) {
      debugPrint("❌ Error leaving household: $e");
      rethrow;
    }
  }

  /// Delete user's Firestore document
  Future<void> deleteUserData() async {
    try {
      await _db.collection('users').doc(uid).delete();
      debugPrint("✅ User document deleted: $uid");
    } catch (e) {
      debugPrint("❌ Error deleting user data: $e");
      rethrow;
    }
  }

  /// Comprehensive account deletion - handles all cleanup
  /// Returns a result object with success/failure info
  Future<DeleteAccountResult> deleteAccountCompletely({
    required HouseholdService householdService,
    String? householdId,
    bool isOwner = false,
    int memberCount = 0,
  }) async {
    try {
      debugPrint(
        "🗑️ Starting account deletion for $uid (household: $householdId, isOwner: $isOwner, members: $memberCount)",
      );

      // Step 1: Handle household cleanup
      if (householdId != null && householdId.isNotEmpty) {
        if (isOwner && memberCount <= 1) {
          // Owner + Single Member (or no members): Delete the entire household
          debugPrint("🏠 Deleting household (owner with $memberCount members)");
          await householdService.deleteHousehold(householdId);
          debugPrint("✅ Household deleted");
        } else if (!isOwner) {
          // Member (not owner): Just leave the household by deleting our user doc
          // We don't call leaveHousehold() as that would write to a doc we're about to delete
          debugPrint(
            "👋 Member leaving household (will be handled by user doc deletion)",
          );
        }
        // If owner with multiple members, this should have been blocked at the UI level
      }

      // Step 2: Delete user document from Firestore
      debugPrint("📄 Deleting user document");
      await deleteUserData();
      debugPrint("✅ User document deleted");

      return DeleteAccountResult(success: true);
    } catch (e) {
      debugPrint("❌ Account deletion error: $e");
      return DeleteAccountResult(success: false, error: e.toString());
    }
  }

  /// Get ALL members of a specific household
  Stream<List<Map<String, dynamic>>> getHouseholdMembers(String householdId) {
    return _db
        .collection('users')
        .where('householdId', isEqualTo: householdId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['uid'] = doc.id;
            return data;
          }).toList();
        })
        .handleError((e) {
          debugPrint("Error getting household members: $e");
          return <Map<String, dynamic>>[];
        });
  }

  /// Update user's display name
  Future<void> updateName(String name) async {
    try {
      await _db.collection('users').doc(uid).update({
        'name': name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint("✅ Name updated: $name");
    } catch (e) {
      debugPrint("❌ Error updating name: $e");
      rethrow;
    }
  }
}

/// Result class for delete account operation
class DeleteAccountResult {
  final bool success;
  final String? error;

  DeleteAccountResult({required this.success, this.error});
}

// PROVIDERS

final userServiceProvider = Provider<UserService?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return UserService(user.uid);
});

// Stream provider for onboarding status
final onboardingCompleteProvider = StreamProvider<bool>((ref) {
  final userService = ref.watch(userServiceProvider);
  if (userService == null) return Stream.value(false);
  return userService.watchOnboardingStatus();
});

// Provider to get the list of household members
final householdMembersProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final userService = ref.watch(userServiceProvider);
  final householdIdAsync = ref.watch(currentHouseholdIdProvider);
  if (userService == null) return const Stream.empty();
  return householdIdAsync.when(
    data: (householdId) {
      if (householdId == null || householdId.isEmpty) return Stream.value([]);
      return userService.getHouseholdMembers(householdId);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});
