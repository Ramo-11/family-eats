import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/shopping_list_provider.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/recipe_provider.dart';
import '../models/ingredient_item.dart';

class ShoppingListScreen extends ConsumerWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shoppingList = ref.watch(shoppingListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Groceries"),
        actions: [
          // Button to Generate List from Meals
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: "Sync from Meal Plan",
            onPressed: () {
              _syncWithMealPlan(context, ref);
            },
          ),
        ],
      ),
      body: shoppingList.isEmpty
          ? _buildEmptyState(context, ref)
          : Column(
              children: [
                _buildQuickAddBar(context, ref),
                Expanded(
                  child: ListView.separated(
                    itemCount: shoppingList.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = shoppingList[index];
                      return _ShoppingListTile(item: item);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _syncWithMealPlan(BuildContext context, WidgetRef ref) {
    final meals = ref.read(mealPlanProvider);
    final recipesAsync = ref.read(recipeProvider);

    // Still loading?
    if (!recipesAsync.hasValue) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Recipes still loading...")));
      return;
    }

    final recipes = recipesAsync.value!; // <--- now it's List<Recipe>

    if (meals.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No meals planned!")));
      return;
    }

    ref
        .read(shoppingListProvider.notifier)
        .generateFromMealPlan(meals, recipes);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Grocery list updated!")));
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.shopping_basket_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            "Your list is empty",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _syncWithMealPlan(context, ref),
            child: const Text("Generate from Weekly Plan"),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddBar(BuildContext context, WidgetRef ref) {
    final textController = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: textController,
        decoration: InputDecoration(
          hintText: "Quick add (e.g., Milk)...",
          suffixIcon: IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              if (textController.text.isNotEmpty) {
                ref
                    .read(shoppingListProvider.notifier)
                    .addManualItem(textController.text, 1, 'item');
                textController.clear();
              }
            },
          ),
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (val) {
          if (val.isNotEmpty) {
            ref
                .read(shoppingListProvider.notifier)
                .addManualItem(val, 1, 'item');
          }
        },
      ),
    );
  }
}

class _ShoppingListTile extends ConsumerWidget {
  final IngredientItem item;
  const _ShoppingListTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Checkbox(
        value: item.isPurchased,
        onChanged: (val) {
          ref.read(shoppingListProvider.notifier).toggleItem(item.id);
        },
      ),
      title: Text(
        item.name,
        style: TextStyle(
          decoration: item.isPurchased ? TextDecoration.lineThrough : null,
          color: item.isPurchased ? Colors.grey : Colors.black,
        ),
      ),
      subtitle: Text("${item.quantity} ${item.unit}"),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
        onPressed: () {
          ref.read(shoppingListProvider.notifier).removeItem(item.id);
        },
      ),
    );
  }
}
