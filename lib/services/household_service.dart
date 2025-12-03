import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
    try {
      // Generate unique invite code (check for collisions)
      String inviteCode;
      bool codeExists = true;
      int attempts = 0;
      const maxAttempts = 10;

      do {
        inviteCode = _generateInviteCode();
        final existing = await _db
            .collection('households')
            .where('inviteCode', isEqualTo: inviteCode)
            .limit(1)
            .get();
        codeExists = existing.docs.isNotEmpty;
        attempts++;
      } while (codeExists && attempts < maxAttempts);

      if (codeExists) {
        throw "Unable to generate unique invite code. Please try again.";
      }

      // Create the household document
      final docRef = _db.collection('households').doc();
      final household = Household(
        id: docRef.id,
        name: name.trim(),
        ownerId: ownerId,
        inviteCode: inviteCode,
        createdAt: DateTime.now(),
      );

      await docRef.set(household.toMap());
      debugPrint("✅ Created household: ${docRef.id} with code: $inviteCode");
      return docRef.id;
    } catch (e) {
      debugPrint("❌ Error creating household: $e");
      rethrow;
    }
  }

  /// Find household by invite code
  Future<Household?> findByInviteCode(String code) async {
    try {
      final normalizedCode = code.trim().toUpperCase();
      final snapshot = await _db
          .collection('households')
          .where('inviteCode', isEqualTo: normalizedCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return Household.fromMap(snapshot.docs.first.data());
    } catch (e) {
      debugPrint("Error finding household by invite code: $e");
      return null;
    }
  }

  /// Get household by ID
  Future<Household?> getHousehold(String householdId) async {
    try {
      final doc = await _db.collection('households').doc(householdId).get();
      if (!doc.exists) return null;
      return Household.fromMap(doc.data()!);
    } catch (e) {
      debugPrint("Error getting household: $e");
      return null;
    }
  }

  /// Stream household data
  Stream<Household?> watchHousehold(String householdId) {
    return _db
        .collection('households')
        .doc(householdId)
        .snapshots()
        .map((doc) => doc.exists ? Household.fromMap(doc.data()!) : null)
        .handleError((e) {
          debugPrint("Error watching household: $e");
          return null;
        });
  }

  /// Update household name
  Future<void> updateHouseholdName(String householdId, String newName) async {
    try {
      await _db.collection('households').doc(householdId).update({
        'name': newName.trim(),
      });
      debugPrint("✅ Household renamed to: $newName");
    } catch (e) {
      debugPrint("❌ Error updating household name: $e");
      rethrow;
    }
  }

  /// Regenerate invite code (useful if code was compromised)
  Future<String> regenerateInviteCode(String householdId) async {
    try {
      String inviteCode;
      bool codeExists = true;
      int attempts = 0;
      const maxAttempts = 10;

      do {
        inviteCode = _generateInviteCode();
        final existing = await _db
            .collection('households')
            .where('inviteCode', isEqualTo: inviteCode)
            .limit(1)
            .get();
        codeExists = existing.docs.isNotEmpty;
        attempts++;
      } while (codeExists && attempts < maxAttempts);

      if (codeExists) {
        throw "Unable to generate unique invite code. Please try again.";
      }

      await _db.collection('households').doc(householdId).update({
        'inviteCode': inviteCode,
      });

      debugPrint("✅ Regenerated invite code: $inviteCode");
      return inviteCode;
    } catch (e) {
      debugPrint("❌ Error regenerating invite code: $e");
      rethrow;
    }
  }

  /// Check if user is owner of household
  Future<bool> isOwner(String householdId, String userId) async {
    try {
      final household = await getHousehold(householdId);
      return household?.ownerId == userId;
    } catch (e) {
      debugPrint("Error checking ownership: $e");
      return false;
    }
  }

  /// Transfer ownership to another member
  Future<void> transferOwnership(String householdId, String newOwnerId) async {
    try {
      // Verify the new owner is a member of this household
      final userDoc = await _db.collection('users').doc(newOwnerId).get();
      if (!userDoc.exists) {
        throw "User not found";
      }
      final userData = userDoc.data();
      if (userData?['householdId'] != householdId) {
        throw "User is not a member of this household";
      }

      await _db.collection('households').doc(householdId).update({
        'ownerId': newOwnerId,
      });
      debugPrint("✅ Ownership transferred to: $newOwnerId");
    } catch (e) {
      debugPrint("❌ Error transferring ownership: $e");
      rethrow;
    }
  }

  /// Delete household and remove all members from it
  Future<void> deleteHousehold(String householdId) async {
    try {
      debugPrint("🗑️ Deleting household: $householdId");

      // First, get all users in this household and clear their householdId
      final usersSnapshot = await _db
          .collection('users')
          .where('householdId', isEqualTo: householdId)
          .get();

      final batch = _db.batch();

      // Update all users to remove them from the household
      for (final userDoc in usersSnapshot.docs) {
        batch.update(userDoc.reference, {
          'householdId': null,
          'onboardingComplete': false,
        });
      }
      debugPrint("📋 Marked ${usersSnapshot.docs.length} users for update");

      // Delete all subcollections (recipes, meal_plan, custom_ingredients)
      final recipesSnapshot = await _db
          .collection('households')
          .doc(householdId)
          .collection('recipes')
          .get();
      for (final doc in recipesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      debugPrint(
        "📋 Marked ${recipesSnapshot.docs.length} recipes for deletion",
      );

      final mealPlanSnapshot = await _db
          .collection('households')
          .doc(householdId)
          .collection('meal_plan')
          .get();
      for (final doc in mealPlanSnapshot.docs) {
        batch.delete(doc.reference);
      }
      debugPrint(
        "📋 Marked ${mealPlanSnapshot.docs.length} meal plans for deletion",
      );

      final ingredientsSnapshot = await _db
          .collection('households')
          .doc(householdId)
          .collection('custom_ingredients')
          .get();
      for (final doc in ingredientsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      debugPrint(
        "📋 Marked ${ingredientsSnapshot.docs.length} custom ingredients for deletion",
      );

      // Delete the household document itself
      batch.delete(_db.collection('households').doc(householdId));

      // Commit all changes
      await batch.commit();
      debugPrint("✅ Household deleted successfully");
    } catch (e) {
      debugPrint("❌ Error deleting household: $e");
      rethrow;
    }
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

// Provider for current user's household ID
final currentHouseholdIdProvider = StreamProvider<String?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data()?['householdId'] as String?)
      .handleError((e) {
        debugPrint("Error watching household ID: $e");
        return null;
      });
});
