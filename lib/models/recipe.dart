import 'package:equatable/equatable.dart';
import 'ingredient_item.dart';

class Recipe extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl; // URL to storage bucket
  final List<IngredientItem> ingredients;

  const Recipe({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.ingredients = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'ingredients': ingredients.map((x) => x.toMap()).toList(),
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'],
      imageUrl: map['imageUrl'],
      ingredients: List<IngredientItem>.from(
        (map['ingredients'] as List<dynamic>? ?? []).map<IngredientItem>(
          (x) => IngredientItem.fromMap(x),
        ),
      ),
    );
  }

  @override
  List<Object?> get props => [id, title, description, imageUrl, ingredients];
}
