import 'package:equatable/equatable.dart';

class IngredientItem extends Equatable {
  final String id;
  final String name;
  final double quantity;
  final String unit; // e.g., "lbs", "cup", "oz", "items"
  final bool isPurchased; // Used later for shopping list logic

  const IngredientItem({
    required this.id,
    required this.name,
    this.quantity = 1.0,
    this.unit = 'item',
    this.isPurchased = false,
  });

  // "copyWith" is standard in Flutter to modify immutable objects
  IngredientItem copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    bool? isPurchased,
  }) {
    return IngredientItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isPurchased: isPurchased ?? this.isPurchased,
    );
  }

  // To/From JSON for when we hook up Firebase/Mongo
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'isPurchased': isPurchased,
    };
  }

  factory IngredientItem.fromMap(Map<String, dynamic> map) {
    return IngredientItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'item',
      isPurchased: map['isPurchased'] ?? false,
    );
  }

  @override
  List<Object> get props => [id, name, quantity, unit, isPurchased];
}
