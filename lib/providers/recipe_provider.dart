import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../services/household_service.dart';
import '../models/recipe.dart';

// Service Provider - depends on household ID from the new provider
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  final asyncHouseholdId = ref.watch(currentHouseholdIdProvider);
  final householdId = asyncHouseholdId.asData?.value ?? '';
  return FirestoreService(householdId);
});

// The Data Stream - reactive to household switches
final recipeProvider = StreamProvider<List<Recipe>>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore.householdId.isEmpty) return const Stream.empty();
  return firestore.getRecipes();
});
