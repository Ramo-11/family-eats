import 'package:family_eats/providers/ingredient_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IngredientManagerScreen extends ConsumerWidget {
  const IngredientManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We get the stream of custom ingredients
    final firestore = ref.watch(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Ingredient Bank")),
      body: StreamBuilder<List<String>>(
        stream: firestore.getCustomIngredients(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Center(child: Text("Error loading"));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final customIngredients = snapshot.data!;

          if (customIngredients.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  "No custom ingredients yet. Add them while creating recipes!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: customIngredients.length,
            separatorBuilder: (c, i) => const Divider(),
            itemBuilder: (context, index) {
              final ing = customIngredients[index];
              return ListTile(
                title: Text(ing),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    // Confirm Delete
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text("Delete Ingredient?"),
                        content: Text(
                          "Delete '$ing' from your autocomplete list?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () {
                              firestore.removeCustomIngredient(ing);
                              Navigator.pop(c);
                            },
                            child: const Text(
                              "Delete",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
