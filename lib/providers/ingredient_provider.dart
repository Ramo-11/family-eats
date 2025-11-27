import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../services/household_service.dart';
import '../constants.dart';

// We align with the logic used in recipe_provider.dart
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  final asyncHouseholdId = ref.watch(currentHouseholdIdProvider);
  final householdId = asyncHouseholdId.asData?.value ?? '';
  return FirestoreService(householdId);
});

final allIngredientsProvider = StreamProvider<List<String>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  // If no household ID is loaded yet, return empty stream
  if (service.householdId.isEmpty) return const Stream.empty();

  return service.getCustomIngredients().map((customList) {
    final combined = {...COMMON_INGREDIENTS, ...customList}.toList()..sort();
    return combined;
  });
});
