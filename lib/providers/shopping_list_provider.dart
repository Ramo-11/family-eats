import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/ingredient_item.dart';
import '../models/recipe.dart';
import '../models/meal_plan_entry.dart';

class ShoppingListNotifier extends StateNotifier<List<IngredientItem>> {
  ShoppingListNotifier() : super([]);

  // Toggle "Check off" status
  void toggleItem(String id) {
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(isPurchased: !item.isPurchased)
        else
          item,
    ];
  }

  // Add a manual item (e.g., "Paper Towels")
  void addManualItem(String name, double qty, String unit) {
    state = [
      ...state,
      IngredientItem(
        id: const Uuid().v4(),
        name: name,
        quantity: qty,
        unit: unit,
      ),
    ];
  }

  // Remove item
  void removeItem(String id) {
    state = state.where((i) => i.id != id).toList();
  }

  // THE ALGORITHM: Generate list from Meal Plan
  void generateFromMealPlan(
    List<MealPlanEntry> mealPlan,
    List<Recipe> allRecipes,
  ) {
    // 1. Create a map to aggregate items by name + unit key
    // Key format: "chicken breast_lbs" (to separate Chicken lbs from Chicken oz)
    final Map<String, IngredientItem> aggregatedMap = {};

    // 2. Loop through every meal in the plan
    for (final mealEntry in mealPlan) {
      // Find the full recipe object
      final recipe = allRecipes.firstWhere(
        (r) => r.id == mealEntry.recipeId,
        orElse: () => const Recipe(id: '0', title: 'Unknown'),
      );

      // Loop through ingredients of that recipe
      for (final ing in recipe.ingredients) {
        // Create a unique key for aggregation (lowercase to be case-insensitive)
        final key =
            "${ing.name.toLowerCase().trim()}_${ing.unit.toLowerCase().trim()}";

        if (aggregatedMap.containsKey(key)) {
          // If exists, just add quantity
          final existing = aggregatedMap[key]!;
          aggregatedMap[key] = existing.copyWith(
            quantity: existing.quantity + ing.quantity,
          );
        } else {
          // If new, add to map. We generate a NEW ID so it doesn't link back to the recipe reference.
          aggregatedMap[key] = ing.copyWith(
            id: const Uuid().v4(),
            isPurchased: false,
          );
        }
      }
    }

    // 3. Update state with the aggregated list
    // Note: In a real app, you might want to merge this with existing manual items rather than overwriting.
    state = aggregatedMap.values.toList();
  }
}

final shoppingListProvider =
    StateNotifierProvider<ShoppingListNotifier, List<IngredientItem>>((ref) {
      return ShoppingListNotifier();
    });
