import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe.dart';

// ConsumerWidget = A widget that can listen to Providers
class RecipeListScreen extends ConsumerWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider. If the list changes, this rebuilds automatically.
    final recipesAsync = ref.watch(recipeProvider);
    final recipes = recipesAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Recipe Bank"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigation to AddScreen will go here
            },
          ),
        ],
      ),
      body: recipes.isEmpty
          ? const Center(child: Text("No recipes yet. Add one!"))
          : ListView.builder(
              itemCount: recipes.length,
              itemBuilder: (context, index) {
                final recipe = recipes[index];
                return _RecipeListTile(recipe: recipe);
              },
            ),
    );
  }
}

// Extracting widgets makes files modular and readable
class _RecipeListTile extends StatelessWidget {
  final Recipe recipe;

  const _RecipeListTile({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          recipe.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe.description != null) ...[
              const SizedBox(height: 4),
              Text(
                recipe.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              "${recipe.ingredients.length} Ingredients",
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // Navigate to details
        },
      ),
    );
  }
}
