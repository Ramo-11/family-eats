import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/ingredient_item.dart';
import '../models/recipe.dart';
import '../providers/ingredient_provider.dart';

class AddRecipeScreen extends ConsumerStatefulWidget {
  final Recipe? recipeToEdit;

  const AddRecipeScreen({super.key, this.recipeToEdit});

  @override
  ConsumerState<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends ConsumerState<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final List<_IngredientRowControllers> _ingredientRows = [];

  @override
  void initState() {
    super.initState();
    if (widget.recipeToEdit != null) {
      final r = widget.recipeToEdit!;
      _titleController.text = r.title;
      _descController.text = r.description ?? "";
      for (var ing in r.ingredients) {
        final row = _IngredientRowControllers();
        row.name.text = ing.name;
        row.quantity.text = ing.quantity.toString();
        row.selectedUnit = ing.unit;
        _ingredientRows.add(row);
      }
    } else {
      _addIngredientRow();
    }
  }

  void _addIngredientRow() {
    setState(() {
      _ingredientRows.add(_IngredientRowControllers());
    });
  }

  void _removeIngredientRow(int index) {
    if (_ingredientRows.length > 1) {
      setState(() {
        _ingredientRows.removeAt(index);
      });
    }
  }

  void _saveRecipe() {
    if (!_formKey.currentState!.validate()) return;

    final ingredients = _ingredientRows.map((row) {
      return IngredientItem(
        id: const Uuid().v4(),
        name: row.name.text,
        quantity: double.tryParse(row.quantity.text) ?? 0,
        unit: row.selectedUnit ?? 'item',
      );
    }).toList();

    final String idToUse = widget.recipeToEdit?.id ?? const Uuid().v4();

    final recipe = Recipe(
      id: idToUse,
      title: _titleController.text,
      description: _descController.text,
      ingredients: ingredients,
    );

    ref.read(firestoreServiceProvider).addRecipe(recipe);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    for (var row in _ingredientRows) row.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipeToEdit == null ? "New Recipe" : "Edit Recipe"),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Recipe Title",
                border: OutlineInputBorder(),
              ),
              validator: (val) =>
                  val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            const Text(
              "Ingredients",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            ..._ingredientRows.asMap().entries.map((entry) {
              return _IngredientInputRow(
                index: entry.key,
                controllers: entry.value,
                onRemove: () => _removeIngredientRow(entry.key),
                canRemove: _ingredientRows.length > 1,
              );
            }),

            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _addIngredientRow,
              icon: const Icon(Icons.add),
              label: const Text("Add Ingredient"),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveRecipe,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF4A6C47),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                widget.recipeToEdit == null ? "Save Recipe" : "Update Recipe",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientRowControllers {
  final TextEditingController name = TextEditingController();
  final TextEditingController quantity = TextEditingController();
  String? selectedUnit = 'item';
  void dispose() {
    name.dispose();
    quantity.dispose();
  }
}

class _IngredientInputRow extends ConsumerWidget {
  final int index;
  final _IngredientRowControllers controllers;
  final VoidCallback onRemove;
  final bool canRemove;

  const _IngredientInputRow({
    required this.index,
    required this.controllers,
    required this.onRemove,
    required this.canRemove,
  });

  static const List<String> _units = [
    'item',
    'lbs',
    'oz',
    'cup',
    'tbsp',
    'tsp',
    'g',
    'kg',
    'liter',
    'can',
    'box',
    'bag',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncIngredients = ref.watch(allIngredientsProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: TextFormField(
              controller: controllers.quantity,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: "Qty",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 15,
                ),
              ),
              validator: (val) => val!.isEmpty ? '*' : null,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: DropdownButtonFormField<String>(
              value: controllers.selectedUnit,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 15,
                ),
              ),
              items: _units
                  .map(
                    (u) => DropdownMenuItem(
                      value: u,
                      child: Text(u, style: const TextStyle(fontSize: 13)),
                    ),
                  )
                  .toList(),
              onChanged: (val) => controllers.selectedUnit = val,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: asyncIngredients.when(
              loading: () =>
                  const Center(child: LinearProgressIndicator(minHeight: 2)),
              error: (_, __) => TextFormField(controller: controllers.name),
              data: (options) {
                return Autocomplete<String>(
                  initialValue: TextEditingValue(text: controllers.name.text),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '')
                      return const Iterable<String>.empty();

                    final matches = options.where((String option) {
                      return option.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      );
                    }).toList();

                    // Logic: If no exact match, add a trigger string to show the "Create" button
                    final exactMatchExists = options.any(
                      (o) =>
                          o.toLowerCase() ==
                          textEditingValue.text.toLowerCase(),
                    );
                    if (!exactMatchExists && textEditingValue.text.isNotEmpty) {
                      matches.add("CREATE_NEW_ITEM:${textEditingValue.text}");
                    }
                    return matches;
                  },
                  // UI: Custom dropdown look
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.5,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final String option = options.elementAt(index);

                              // Logic: Render "Create" button differently
                              if (option.startsWith("CREATE_NEW_ITEM:")) {
                                final cleanName = option.split(":")[1];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.add_circle,
                                    color: Color(0xFF4A6C47),
                                  ),
                                  title: Text(
                                    "Create \"$cleanName\"",
                                    style: const TextStyle(
                                      color: Color(0xFF4A6C47),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onTap: () {
                                    ref
                                        .read(firestoreServiceProvider)
                                        .addCustomIngredient(cleanName);
                                    onSelected(cleanName);
                                  },
                                );
                              }

                              return ListTile(
                                title: Text(option),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  onSelected: (String selection) {
                    if (!selection.startsWith("CREATE_NEW_ITEM:")) {
                      controllers.name.text = selection;
                    }
                  },
                  fieldViewBuilder:
                      (
                        context,
                        textEditingController,
                        focusNode,
                        onFieldSubmitted,
                      ) {
                        // Sync logic
                        if (controllers.name.text.isNotEmpty &&
                            textEditingController.text !=
                                controllers.name.text) {
                          if (textEditingController.text.isEmpty)
                            textEditingController.text = controllers.name.text;
                        }
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: "Item Name",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 15,
                            ),
                          ),
                          onChanged: (val) => controllers.name.text = val,
                          validator: (val) => val!.isEmpty ? 'Required' : null,
                        );
                      },
                );
              },
            ),
          ),
          if (canRemove)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              padding: const EdgeInsets.only(top: 15),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
