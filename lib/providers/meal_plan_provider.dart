import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/meal_plan_entry.dart';

class MealPlanNotifier extends StateNotifier<List<MealPlanEntry>> {
  MealPlanNotifier() : super([]);

  // Add to specific date
  void addMealToDate(DateTime date, String recipeId) {
    final entry = MealPlanEntry(
      id: const Uuid().v4(),
      date: date,
      recipeId: recipeId,
    );
    state = [...state, entry];
  }

  // Add to "Flexible/Weekly" bucket (No date)
  void addFlexibleMeal(String recipeId) {
    final entry = MealPlanEntry(
      id: const Uuid().v4(),
      date: null,
      recipeId: recipeId,
    );
    state = [...state, entry];
  }

  void removeMeal(String id) {
    state = state.where((m) => m.id != id).toList();
  }
}

final mealPlanProvider =
    StateNotifierProvider<MealPlanNotifier, List<MealPlanEntry>>((ref) {
      return MealPlanNotifier();
    });
