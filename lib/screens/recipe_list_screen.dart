import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/recipe.dart';
import 'add_recipe_screen.dart';
import 'paywall_screen.dart';
import 'recipe_detail_screen.dart'; // Assuming you have this

class RecipeListScreen extends ConsumerWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipeProvider);
    final recipes = recipesAsync.value ?? [];

    // 1. My Personal Status
    final amIPro = ref.watch(isProProvider);
    // 2. Household Owner's Status
    final isHouseholdPro = ref.watch(householdLimitProvider).value ?? false;

    // Effective Status: If either I am Pro OR my Household Owner is Pro, I have no limits.
    final hasUnlimitedAccess = amIPro || isHouseholdPro;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Recipe Bank"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // --- LIMIT LOGIC ---
              if (!hasUnlimitedAccess && recipes.length >= 5) {
                // Limit reached
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                );
              } else {
                // Allow adding
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddRecipeScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: recipesAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    "No recipes yet",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      if (!hasUnlimitedAccess && data.length >= 5) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaywallScreen(),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddRecipeScreen(),
                          ),
                        );
                      }
                    },
                    child: const Text("Add your first recipe"),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.length,
            itemBuilder: (context, index) {
              final recipe = data[index];
              return _RecipeListTile(recipe: recipe);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }
}

class _RecipeListTile extends StatelessWidget {
  final Recipe recipe;

  const _RecipeListTile({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          recipe.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe.description != null &&
                recipe.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                recipe.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.restaurant_menu,
                  size: 14,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  "${recipe.ingredients.length} ingredients",
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (c) => RecipeDetailScreen(recipe: recipe),
            ),
          );
        },
      ),
    );
  }
}
