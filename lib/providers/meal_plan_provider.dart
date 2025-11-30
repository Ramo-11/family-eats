import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_plan_entry.dart';
import '../services/firestore_service.dart';
import '../services/household_service.dart';

/// Stream provider - reactively watches Firestore for real-time sync
final mealPlanProvider = StreamProvider<List<MealPlanEntry>>((ref) {
  final asyncHouseholdId = ref.watch(currentHouseholdIdProvider);
  final householdId = asyncHouseholdId.asData?.value ?? '';

  if (householdId.isEmpty) return const Stream.empty();

  final firestore = FirestoreService(householdId);
  return firestore.getMealPlan();
});

/// Service provider for write operations
final mealPlanServiceProvider = Provider<MealPlanService?>((ref) {
  final asyncHouseholdId = ref.watch(currentHouseholdIdProvider);
  final householdId = asyncHouseholdId.asData?.value ?? '';

  if (householdId.isEmpty) return null;
  return MealPlanService(householdId);
});

class MealPlanService {
  final FirestoreService _firestore;
  final _uuid = const Uuid();

  MealPlanService(String householdId)
      : _firestore = FirestoreService(householdId);

  Future<void> addMealToDate(DateTime date, String recipeId) async {
    final entry = MealPlanEntry(
      id: _uuid.v4(),
      date: date,
      recipeId: recipeId,
    );
    await _firestore.addMealPlanEntry(entry);
  }

  Future<void> addFlexibleMeal(String recipeId) async {
    final entry = MealPlanEntry(
      id: _uuid.v4(),
      date: null,
      recipeId: recipeId,
    );
    await _firestore.addMealPlanEntry(entry);
  }

  Future<void> removeMeal(String id) async {
    await _firestore.removeMealPlanEntry(id);
  }
}