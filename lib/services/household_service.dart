import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/household.dart';
import 'auth_service.dart';

class HouseholdService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Generate a short, readable invite code like "EATS-7X4K"
  String _generateInviteCode() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed confusing chars (0,O,1,I)
    final random = Random.secure();
    final code = List.generate(
      4,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return 'EATS-$code';
  }

  /// Create a new household and return its ID
  Future<String> createHousehold({
    required String name,
    required String ownerId,
  }) async {
    // Generate unique invite code (check for collisions)
    String inviteCode;
    bool codeExists = true;

    do {
      inviteCode = _generateInviteCode();
      final existing = await _db
          .collection('households')
          .where('inviteCode', isEqualTo: inviteCode)
          .limit(1)
          .get();
      codeExists = existing.docs.isNotEmpty;
    } while (codeExists);

    // Create the household document
    final docRef = _db.collection('households').doc();
    final household = Household(
      id: docRef.id,
      name: name,
      ownerId: ownerId,
      inviteCode: inviteCode,
      createdAt: DateTime.now(),
    );

    await docRef.set(household.toMap());
    return docRef.id;
  }

  /// Find household by invite code
  Future<Household?> findByInviteCode(String code) async {
    final normalizedCode = code.trim().toUpperCase();
    final snapshot = await _db
        .collection('households')
        .where('inviteCode', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Household.fromMap(snapshot.docs.first.data());
  }

  /// Get household by ID
  Future<Household?> getHousehold(String householdId) async {
    final doc = await _db.collection('households').doc(householdId).get();
    if (!doc.exists) return null;
    return Household.fromMap(doc.data()!);
  }

  /// Stream household data
  Stream<Household?> watchHousehold(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .snapshots()
        .map((doc) => doc.exists ? Household.fromMap(doc.data()!) : null);
  }

  /// Update household name
  Future<void> updateHouseholdName(String householdId, String newName) async {
    await _db.collection('households').doc(householdId).update({
      'name': newName.trim(),
    });
  }

  /// Regenerate invite code (useful if code was compromised)
  Future<String> regenerateInviteCode(String householdId) async {
    String inviteCode;
    bool codeExists = true;

    do {
      inviteCode = _generateInviteCode();
      final existing = await _db
          .collection('households')
          .where('inviteCode', isEqualTo: inviteCode)
          .limit(1)
          .get();
      codeExists = existing.docs.isNotEmpty;
    } while (codeExists);

    await _db.collection('households').doc(householdId).update({
      'inviteCode': inviteCode,
    });

    return inviteCode;
  }

  /// Check if user is owner of household
  Future<bool> isOwner(String householdId, String userId) async {
    final household = await getHousehold(householdId);
    return household?.ownerId == userId;
  }
}

// Provider
final householdServiceProvider = Provider<HouseholdService>((ref) {
  return HouseholdService();
});

// Stream provider for current household data
final currentHouseholdProvider = StreamProvider<Household?>((ref) {
  final householdIdAsync = ref.watch(currentHouseholdIdProvider);
  final householdService = ref.watch(householdServiceProvider);

  return householdIdAsync.when(
    data: (householdId) {
      if (householdId == null || householdId.isEmpty) {
        return Stream.value(null);
      }
      return householdService.watchHousehold(householdId);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// We need to import this from user_service, but to avoid circular deps,
// we'll define the provider reference here
final currentHouseholdIdProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data()?['householdId'] as String?);
});
