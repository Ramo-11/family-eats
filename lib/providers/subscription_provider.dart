import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/household_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';

/// RevenueCat-based Pro status notifier
class ProStatusNotifier extends StateNotifier<bool> {
  final Ref ref;

  ProStatusNotifier(this.ref) : super(false) {
    _init();
  }

  Future<void> _init() async {
    try {
      // Check RevenueCat initial status
      final info = await Purchases.getCustomerInfo();
      await _handleStatusUpdate(info);

      // Listen for RevenueCat updates
      Purchases.addCustomerInfoUpdateListener((info) {
        _handleStatusUpdate(info);
      });
    } catch (e) {
      debugPrint("Error initializing RevenueCat Pro status: $e");
      // Fallback: check Firestore
      await _checkFirestoreStatus();
    }
  }

  Future<void> _checkFirestoreStatus() async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final firestorePro = doc.data()?['isPro'] == true;
        if (firestorePro && !state) {
          state = true;
        }
      }
    } catch (e) {
      debugPrint("Error checking Firestore Pro status: $e");
    }
  }

  Future<void> _handleStatusUpdate(CustomerInfo info) async {
    final isPro = info.entitlements.all['pro_access']?.isActive ?? false;
    state = isPro;
    await _syncToFirestore(isPro);
  }

  Future<void> _syncToFirestore(bool isPro) async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'isPro': isPro,
        }, SetOptions(merge: true));
        debugPrint("✅ Synced Pro status to Firestore: $isPro");
      }
    } catch (e) {
      debugPrint("❌ Error syncing Pro status to Firestore: $e");
    }
  }

  /// Manual refresh - call after purchase to ensure sync
  Future<void> refresh() async {
    try {
      final info = await Purchases.getCustomerInfo();
      await _handleStatusUpdate(info);
    } catch (e) {
      debugPrint("Error refreshing Pro status: $e");
    }
  }

  /// Force sync current state to Firestore
  Future<void> forceSync() async {
    await _syncToFirestore(state);
  }
}

// 1. RevenueCat-based provider
final isProProvider = StateNotifierProvider<ProStatusNotifier, bool>((ref) {
  return ProStatusNotifier(ref);
});

// 2. Firestore-based provider (source of truth for persistence)
final userProStatusProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(false);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.data()?['isPro'] == true);
});

// 3. COMBINED Pro status - true if EITHER source says Pro
// This is the MAIN provider to use throughout the app
final effectiveProStatusProvider = Provider<bool>((ref) {
  final revenueCatPro = ref.watch(isProProvider);
  final firestoreProAsync = ref.watch(userProStatusProvider);
  final firestorePro = firestoreProAsync.value ?? false;

  // Return true if either source confirms Pro status
  return revenueCatPro || firestorePro;
});

// 4. Loading state for Pro status (useful for UI)
final proStatusLoadingProvider = Provider<bool>((ref) {
  final firestoreProAsync = ref.watch(userProStatusProvider);
  return firestoreProAsync.isLoading;
});

// 5. The HOUSEHOLD'S Pro Status (Based on the Owner)
// This determines limits for the entire household
final householdLimitProvider = StreamProvider<bool>((ref) {
  final householdAsync = ref.watch(currentHouseholdProvider);

  return householdAsync.when(
    data: (household) {
      if (household == null) return Stream.value(false);

      // Watch the OWNER'S user document to see if 'isPro' is true
      return FirebaseFirestore.instance
          .collection('users')
          .doc(household.ownerId)
          .snapshots()
          .map((doc) => doc.data()?['isPro'] == true);
    },
    loading: () => Stream.value(false),
    error: (_, __) => Stream.value(false),
  );
});

// 6. Effective household access - combines user's own Pro + household owner Pro
final hasUnlimitedAccessProvider = Provider<bool>((ref) {
  final userPro = ref.watch(effectiveProStatusProvider);
  final householdPro = ref.watch(householdLimitProvider).value ?? false;
  return userPro || householdPro;
});
