import 'package:equatable/equatable.dart';

class MealPlanEntry extends Equatable {
  final String id;
  final DateTime? date;
  final String recipeId;

  const MealPlanEntry({required this.id, this.date, required this.recipeId});

  // --- fromMap ---
  factory MealPlanEntry.fromMap(Map<String, dynamic> map) {
    return MealPlanEntry(
      id: map['id'] as String,
      recipeId: map['recipeId'] as String,
      date: map['date'] != null ? DateTime.parse(map['date'] as String) : null,
    );
  }

  // --- toMap ---
  Map<String, dynamic> toMap() {
    return {'id': id, 'recipeId': recipeId, 'date': date?.toIso8601String()};
  }

  @override
  List<Object?> get props => [id, date, recipeId];
}
