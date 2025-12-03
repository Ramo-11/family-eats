import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/household_service.dart';
import '../services/auth_service.dart';

/// Global flag to prevent Firestore writes during account deletion
class AccountDeletionState {
  static bool isDeleting = false;
}

/// RevenueCat-based Pro status notifier with proper cleanup
class ProStatusNotifier extends StateNotifier<bool> {
  final Ref ref;
  bool _isDisposed = false;

  ProStatusNotifier(this.ref) : super(false) {
    _init();
  }

  Future<void> _init() async {
    try {
      // Check RevenueCat initial status
      final info = await Purchases.getCustomerInfo();
      if (!_isDisposed) {
        await _handleStatusUpdate(info);
      }

      // Listen for RevenueCat updates
      Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    } catch (e) {
      debugPrint("Error initializing RevenueCat Pro status: $e");
      // Fallback: check Firestore
      if (!_isDisposed) {
        await _checkFirestoreStatus();
      }
    }
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    if (!_isDisposed && !AccountDeletionState.isDeleting) {
      _handleStatusUpdate(info);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _checkFirestoreStatus() async {
    if (AccountDeletionState.isDeleting) return;

    try {
      final user = ref.read(authStateProvider).value;
      if (user != null && !_isDisposed) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final firestorePro = doc.data()?['isPro'] == true;
        if (firestorePro && !state && !_isDisposed) {
          state = true;
        }
      }
    } catch (e) {
      debugPrint("Error checking Firestore Pro status: $e");
    }
  }

  Future<void> _handleStatusUpdate(CustomerInfo info) async {
    if (_isDisposed || AccountDeletionState.isDeleting) return;

    // Check for 'pro_access' entitlement OR any active entitlement
    final isPro = info.entitlements.all['pro_access']?.isActive ?? false;
    final hasAnyActive = info.entitlements.active.isNotEmpty;

    final effectivePro = isPro || hasAnyActive;

    if (state != effectivePro) {
      state = effectivePro;
      await _syncToFirestore(effectivePro);
    }
  }

  Future<void> _syncToFirestore(bool isPro) async {
    // CRITICAL: Don't sync if disposed, deleting, or no user
    if (_isDisposed || AccountDeletionState.isDeleting) {
      debugPrint(
        "⚠️ Skipping Firestore sync (disposed: $_isDisposed, deleting: ${AccountDeletionState.isDeleting})",
      );
      return;
    }

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) {
        debugPrint("⚠️ Skipping Firestore sync - no user");
        return;
      }

      // Check if user document still exists before writing
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        debugPrint("⚠️ Skipping Firestore sync - user document doesn't exist");
        return;
      }

      // Use update instead of set to avoid recreating deleted documents
      await docRef.update({
        'isPro': isPro,
        'proUpdatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint("✅ Pro status synced to Firestore: $isPro");
    } catch (e) {
      // Document might not exist anymore, that's OK during deletion
      debugPrint(
        "⚠️ Error syncing Pro status to Firestore (may be expected): $e",
      );
    }
  }

  /// Manual refresh - call after purchase to ensure sync
  Future<void> refresh() async {
    if (_isDisposed || AccountDeletionState.isDeleting) return;

    try {
      final info = await Purchases.getCustomerInfo();
      await _handleStatusUpdate(info);
    } catch (e) {
      debugPrint("Error refreshing Pro status: $e");
      // Fallback to Firestore check
      await _checkFirestoreStatus();
    }
  }

  /// Force sync current state to Firestore
  Future<void> forceSync() async {
    if (!_isDisposed && !AccountDeletionState.isDeleting) {
      await _syncToFirestore(state);
    }
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
      .map((doc) => doc.data()?['isPro'] == true)
      .handleError((e) {
        debugPrint("Error watching user pro status: $e");
        return false;
      });
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
          .map((doc) => doc.data()?['isPro'] == true)
          .handleError((e) {
            debugPrint("Error watching household owner pro status: $e");
            return false;
          });
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
