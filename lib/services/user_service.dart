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
  /// Note: householdId is NOT set here - user must go through onboarding
  Future<void> initializeUser(String name, String email) async {
    await _db.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'householdId': null, // Will be set during onboarding
      'onboardingComplete': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
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

  /// Join an existing household by ID
  /// Also syncs the user's display name from Firebase Auth
  Future<void> joinHousehold(String householdId, {String? displayName}) async {
    final updateData = <String, dynamic>{
      'householdId': householdId,
      'onboardingComplete': true,
    };

    // If displayName is provided, update it too
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
      'onboardingComplete': false, // Forces them back to onboarding
    }, SetOptions(merge: true));
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
      if (householdId == null || householdId.isEmpty) {
        return Stream.value([]);
      }
      return userService.getHouseholdMembers(householdId);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});
