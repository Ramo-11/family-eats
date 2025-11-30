import 'package:family_eats/providers/ingredient_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IngredientManagerScreen extends ConsumerStatefulWidget {
  const IngredientManagerScreen({super.key});

  @override
  ConsumerState<IngredientManagerScreen> createState() =>
      _IngredientManagerScreenState();
}

class _IngredientManagerScreenState
    extends ConsumerState<IngredientManagerScreen> {
  final TextEditingController _addController = TextEditingController();

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  void _showAddIngredientDialog() {
    _addController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Add Ingredient"),
        content: TextField(
          controller: _addController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: "Ingredient Name",
            hintText: "e.g., Quinoa",
            prefixIcon: const Icon(Icons.restaurant),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _addIngredient(dialogContext),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => _addIngredient(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6C47),
              foregroundColor: Colors.white,
            ),
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _addIngredient(BuildContext dialogContext) {
    final name = _addController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter an ingredient name"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final firestore = ref.read(firestoreServiceProvider);
    firestore.addCustomIngredient(name);
    Navigator.pop(dialogContext);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$name" added to your ingredient bank'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // We get the stream of custom ingredients
    final firestore = ref.watch(firestoreServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Custom Ingredient Bank")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddIngredientDialog,
        backgroundColor: const Color(0xFF4A6C47),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Add Ingredient"),
      ),
      body: StreamBuilder<List<String>>(
        stream: firestore.getCustomIngredients(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading"));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final customIngredients = snapshot.data!;

          if (customIngredients.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.kitchen_outlined,
                      size: 64,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No custom ingredients yet",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tap the button below to add ingredients,\nor add them while creating recipes!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: customIngredients.length,
            separatorBuilder: (c, i) => const Divider(),
            itemBuilder: (context, index) {
              final ing = customIngredients[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A6C47).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: Color(0xFF4A6C47),
                    size: 20,
                  ),
                ),
                title: Text(ing),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    // Confirm Delete
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text("Delete Ingredient?"),
                        content: Text(
                          'Remove "$ing" from your autocomplete list?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text("Cancel"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              firestore.removeCustomIngredient(ing);
                              Navigator.pop(c);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"$ing" removed'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text("Delete"),
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
