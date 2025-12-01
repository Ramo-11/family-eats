import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/household_service.dart';
import '../services/user_service.dart';

// 1. The Local User's Status (Syncs to Firestore)
final isProProvider = StateNotifierProvider<ProStatusNotifier, bool>((ref) {
  return ProStatusNotifier(ref);
});

class ProStatusNotifier extends StateNotifier<bool> {
  final Ref ref;

  ProStatusNotifier(this.ref) : super(false) {
    _init();
  }

  Future<void> _init() async {
    try {
      // Check initial
      CustomerInfo info = await Purchases.getCustomerInfo();
      _handleStatusUpdate(info);

      // Listen for updates
      Purchases.addCustomerInfoUpdateListener((info) {
        _handleStatusUpdate(info);
      });
    } catch (e) {
      // Handle error
    }
  }

  void _handleStatusUpdate(CustomerInfo info) {
    final isPro = info.entitlements.all['pro_access']?.isActive ?? false;
    state = isPro;

    // SYNC TO FIRESTORE
    final userService = ref.read(userServiceProvider);
    if (userService != null) {
      userService.updateProStatus(isPro);
    }
  }
}

// 2. The HOUSEHOLD'S Status (Based on the Owner)
final householdLimitProvider = StreamProvider<bool>((ref) {
  final householdAsync = ref.watch(currentHouseholdProvider);

  return householdAsync.when(
    data: (household) {
      if (household == null)
        return Stream.value(false); // No household = Free limits

      // Watch the OWNER'S user document to see if 'isPro' is true
      return FirebaseFirestore.instance
          .collection('users')
          .doc(household.ownerId)
          .snapshots()
          .map((doc) {
            return doc.data()?['isPro'] == true;
          });
    },
    loading: () => Stream.value(false),
    error: (_, __) => Stream.value(false),
  );
});
