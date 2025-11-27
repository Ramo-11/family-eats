import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../providers/shopping_list_provider.dart';
import 'add_recipe_screen.dart';

class RecipeDetailScreen extends ConsumerWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch shopping list to see what we already have for visual feedback
    final shoppingList = ref.watch(shoppingListProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Collapsing Header
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            actions: [
              // EDIT BUTTON
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.black87),
                tooltip: "Edit Recipe",
                onPressed: () {
                  // Navigate to Add Screen, but pass this recipe to edit
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => AddRecipeScreen(recipeToEdit: recipe),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                recipe.title,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                color: Colors.grey.shade200,
                child: Center(
                  child: Icon(
                    Icons.restaurant_menu,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          ),

          // Description
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (recipe.description != null &&
                      recipe.description!.isNotEmpty)
                    Text(
                      recipe.description!,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    "Ingredients",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Ingredient List
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final ingredient = recipe.ingredients[index];

              // Logic: Check if ingredient is already in shopping list (unpurchased)
              final isInShoppingList = shoppingList.any(
                (item) =>
                    item.name.toLowerCase() == ingredient.name.toLowerCase() &&
                    !item.isPurchased,
              );

              return ListTile(
                leading: const Icon(
                  Icons.circle,
                  size: 8,
                  color: Color(0xFF4A6C47),
                ),
                title: Text(
                  ingredient.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text("${ingredient.quantity} ${ingredient.unit}"),
                trailing: isInShoppingList
                    ? const Chip(
                        label: Text("To Buy"),
                        backgroundColor: Colors.orangeAccent,
                        labelStyle: TextStyle(fontSize: 12),
                        side: BorderSide.none,
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.add_shopping_cart,
                          color: Color(0xFF4A6C47),
                        ),
                        tooltip: "Add to Grocery List",
                        onPressed: () {
                          ref
                              .read(shoppingListProvider.notifier)
                              .addManualItem(
                                ingredient.name,
                                ingredient.quantity,
                                ingredient.unit,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Added ${ingredient.name} to list"),
                            ),
                          );
                        },
                      ),
              );
            }, childCount: recipe.ingredients.length),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }
}
