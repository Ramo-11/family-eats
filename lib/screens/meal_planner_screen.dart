import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_provider.dart';
import '../providers/meal_plan_provider.dart';
import '../models/recipe.dart';
import '../models/meal_plan_entry.dart';
import 'recipe_detail_screen.dart'; // Import detail screen

class MealPlannerScreen extends ConsumerStatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  ConsumerState<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends ConsumerState<MealPlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<DateTime> _weekDates = List.generate(
    7,
    (i) => DateTime.now().add(Duration(days: i)),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final mealPlanAsync = ref.watch(mealPlanProvider);
    final recipesAsync = ref.watch(recipeProvider);
    final allRecipes = recipesAsync.value ?? [];
    final mealPlanEntries = mealPlanAsync.value ?? [];

    // Split meals into two lists
    final flexibleMeals = mealPlanEntries.where((m) => m.date == null).toList();
    final scheduledMeals = mealPlanEntries
        .where((m) => m.date != null)
        .toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Meal Plan"),
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: "Scheduled Days"),
            Tab(text: "Flexible / Weekly"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: SCHEDULED
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _weekDates.length,
            itemBuilder: (context, index) {
              final date = _weekDates[index];
              return _DayCard(
                date: date,
                meals: scheduledMeals
                    .where((m) => _isSameDay(m.date!, date))
                    .toList(),
                allRecipes: allRecipes,
                ref: ref,
              );
            },
          ),

          // TAB 2: FLEXIBLE
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text("Add Meal to Flexible List"),
                  onPressed: () =>
                      _showRecipeSelector(context, null, allRecipes),
                ),
              ),
              Expanded(
                child: flexibleMeals.isEmpty
                    ? const Center(child: Text("No flexible meals added yet."))
                    : ListView.builder(
                        itemCount: flexibleMeals.length,
                        itemBuilder: (ctx, i) {
                          final entry = flexibleMeals[i];
                          final recipe = _getRecipe(allRecipes, entry.recipeId);
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.local_dining,
                                  color: Colors.orange,
                                ),
                              ),
                              title: Text(
                                recipe.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: const Text("Anytime this week"),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => ref
                                    .read(mealPlanServiceProvider)
                                    ?.removeMeal(entry.id),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RecipeDetailScreen(recipe: recipe),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Helper Methods ---

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Recipe _getRecipe(List<Recipe> recipes, String id) {
    return recipes.firstWhere(
      (r) => r.id == id,
      orElse: () => const Recipe(id: '0', title: 'Unknown'),
    );
  }

  void _showRecipeSelector(
    BuildContext context,
    DateTime? date,
    List<Recipe> recipes,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 400,
          child: Column(
            children: [
              Text(
                date == null
                    ? "Add Flexible Meal"
                    : "Add for ${_formatDate(date)}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              Expanded(
                child: recipes.isEmpty
                    ? const Center(
                        child: Text("No recipes yet. Add some first!"),
                      )
                    : ListView.builder(
                        itemCount: recipes.length,
                        itemBuilder: (ctx, i) {
                          final recipe = recipes[i];
                          return ListTile(
                            title: Text(recipe.title),
                            onTap: () {
                              final service = ref.read(mealPlanServiceProvider);
                              if (date == null) {
                                service?.addFlexibleMeal(recipe.id);
                              } else {
                                service?.addMealToDate(date, recipe.id);
                              }
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime d) => "${d.month}/${d.day}";
}

// Separate Widget for UI Cleanliness
class _DayCard extends StatelessWidget {
  final DateTime date;
  final List<MealPlanEntry> meals;
  final List<Recipe> allRecipes;
  final WidgetRef ref;

  const _DayCard({
    required this.date,
    required this.meals,
    required this.allRecipes,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = DateTime.now().day == date.day;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isToday
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatFullDate(date),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isToday
                        ? Theme.of(context).primaryColor
                        : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.grey,
                  ),
                  onPressed: () =>
                      (context
                              .findAncestorStateOfType<
                                _MealPlannerScreenState
                              >())
                          ?._showRecipeSelector(context, date, allRecipes),
                ),
              ],
            ),
            if (meals.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Text(
                  "Nothing planned",
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ...meals.map((entry) {
              final recipe = allRecipes.firstWhere(
                (r) => r.id == entry.recipeId,
                orElse: () => const Recipe(id: '0', title: 'Unknown'),
              );
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(recipe: recipe),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 8, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(recipe.title, style: const TextStyle(fontSize: 15)),
                      const Spacer(),
                      InkWell(
                        onTap: () => ref
                            .read(mealPlanServiceProvider)
                            ?.removeMeal(entry.id),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatFullDate(DateTime d) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[d.weekday - 1];
  }
}
