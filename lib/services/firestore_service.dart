import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe.dart';
import '../models/meal_plan_entry.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String householdId; // Dynamic ID

  FirestoreService(this.householdId);

  // --- 1. RECIPES ---
  Stream<List<Recipe>> getRecipes() {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('recipes')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Recipe.fromMap(doc.data())).toList(),
        );
  }

  Future<void> addRecipe(Recipe recipe) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('recipes')
        .doc(recipe.id)
        .set(recipe.toMap());
  }

  Future<void> deleteRecipe(String recipeId) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('recipes')
        .doc(recipeId)
        .delete();
  }

  // --- 2. MEAL PLAN ---
  Stream<List<MealPlanEntry>> getMealPlan() {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('meal_plan')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MealPlanEntry.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> addMealPlanEntry(MealPlanEntry entry) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('meal_plan')
        .doc(entry.id)
        .set(entry.toMap());
  }

  Future<void> removeMealPlanEntry(String id) {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('meal_plan')
        .doc(id)
        .delete();
  }

  // --- 3. CUSTOM INGREDIENTS ---
  Stream<List<String>> getCustomIngredients() {
    return _db
        .collection('households')
        .doc(householdId)
        .collection('custom_ingredients')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((d) => d['name'] as String).toList(),
        );
  }

  Future<void> addCustomIngredient(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    // Use the name as the Doc ID to prevent duplicates easily
    await _db
        .collection('households')
        .doc(householdId)
        .collection('custom_ingredients')
        .doc(normalized.toLowerCase())
        .set({'name': normalized});
  }

  Future<void> removeCustomIngredient(String name) async {
    await _db
        .collection('households')
        .doc(householdId)
        .collection('custom_ingredients')
        .doc(name.toLowerCase())
        .delete();
  }
}
