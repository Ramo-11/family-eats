import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';
import 'household_service.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String uid;

  UserService(this.uid);

  /// Get the current user's profile stream
  Stream<Map<String, dynamic>?> getUserProfile() {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      return snapshot.data();
    });
  }

  /// Initialize a new user (called after signup)
  Future<void> initializeUser(String name, String email) async {
    // Changed to merge: true to prevents accidental overwrites if called twice
    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'householdId': null,
      'onboardingComplete': false,
      'isPro': false,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateProStatus(bool isPro) async {
    await _db.collection('users').doc(uid).set({
      'isPro': isPro,
    }, SetOptions(merge: true));
  }

  /// Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['onboardingComplete'] == true;
  }

  /// Stream to check onboarding status
  Stream<bool> watchOnboardingStatus() {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      return doc.data()?['onboardingComplete'] == true;
    });
  }

  /// Get user's Pro status
  Future<bool> getProStatus() async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['isPro'] == true;
  }

  /// Get user's household ID
  Future<String?> getHouseholdId() async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['householdId'] as String?;
  }

  /// Join an existing household by ID
  /// Also syncs the user's display name from Firebase Auth
  Future<void> joinHousehold(String householdId, {String? displayName}) async {
    final updateData = <String, dynamic>{
      'householdId': householdId,
      'onboardingComplete': true,
    };
    if (displayName != null && displayName.isNotEmpty) {
      updateData['name'] = displayName;
    }
    await _db
        .collection('users')
        .doc(uid)
        .set(updateData, SetOptions(merge: true));
  }

  /// Create and join a new household
  Future<String> createAndJoinHousehold(
    String householdName,
    HouseholdService householdService,
  ) async {
    final householdId = await householdService.createHousehold(
      name: householdName,
      ownerId: uid,
    );
    await _db.collection('users').doc(uid).set({
      'householdId': householdId,
      'onboardingComplete': true,
    }, SetOptions(merge: true));
    return householdId;
  }

  /// Leave current household (returns to having no household - must rejoin or create)
  Future<void> leaveHousehold() async {
    await _db.collection('users').doc(uid).set({
      'householdId': null,
      'onboardingComplete': false,
    }, SetOptions(merge: true));
  }

  /// Delete user's Firestore document
  Future<void> deleteUserData() async {
    await _db.collection('users').doc(uid).delete();
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
      // Step 1: Handle household cleanup
      if (householdId != null && householdId.isNotEmpty) {
        if (isOwner && memberCount <= 1) {
          // Owner + Single Member: Delete the entire household
          await householdService.deleteHousehold(householdId);
        }
        // CRITICAL FIX:
        // If they are a member (not owner), we do NOT call leaveHousehold().
        // We simply delete their user document in Step 2.
        // Calling leaveHousehold() writes to the doc we are about to delete, causing conflicts.
      }

      // Step 2: Delete user document from Firestore
      await deleteUserData();

      return DeleteAccountResult(success: true);
    } catch (e) {
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
        });
  }

  /// Update user's display name
  Future<void> updateName(String name) async {
    await _db.collection('users').doc(uid).update({'name': name.trim()});
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
