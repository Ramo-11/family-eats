import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/recipe_provider.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/recipe.dart';
import '../models/meal_plan_entry.dart';
import 'recipe_detail_screen.dart';
import 'paywall_screen.dart';

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

    // Check if household has pro status
    final isHouseholdPro = ref.watch(householdLimitProvider).value ?? false;
    final mealLimit = isHouseholdPro ? -1 : 5; // -1 means unlimited
    final isLimitReached =
        mealLimit != -1 && mealPlanEntries.length >= mealLimit;

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
        actions: [
          if (!isHouseholdPro)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isLimitReached
                        ? Colors.red.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${mealPlanEntries.length}/$mealLimit meals",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isLimitReached
                          ? Colors.red.shade700
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
      body: Column(
        children: [
          // Limit Warning Banner
          if (isLimitReached)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.amber.shade50,
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Colors.amber.shade700,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Meal limit reached. Upgrade to Pro for unlimited meals!",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaywallScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: const Text(
                      "Upgrade",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
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
                      isLimitReached: isLimitReached,
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
                          backgroundColor: isLimitReached
                              ? Colors.grey.shade400
                              : Colors.black87,
                          foregroundColor: Colors.white,
                        ),
                        icon: Icon(isLimitReached ? Icons.lock : Icons.add),
                        label: Text(
                          isLimitReached
                              ? "Meal Limit Reached"
                              : "Add Meal to Flexible List",
                        ),
                        onPressed: isLimitReached
                            ? () => _showUpgradePrompt(context)
                            : () => _showRecipeSelector(
                                context,
                                null,
                                allRecipes,
                                isLimitReached,
                              ),
                      ),
                    ),
                    Expanded(
                      child: flexibleMeals.isEmpty
                          ? const Center(
                              child: Text("No flexible meals added yet."),
                            )
                          : ListView.builder(
                              itemCount: flexibleMeals.length,
                              itemBuilder: (ctx, i) {
                                final entry = flexibleMeals[i];
                                final recipe = _getRecipe(
                                  allRecipes,
                                  entry.recipeId,
                                );
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
                                          builder: (_) => RecipeDetailScreen(
                                            recipe: recipe,
                                          ),
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

  void _showUpgradePrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber),
            SizedBox(width: 8),
            Text("Upgrade to Pro"),
          ],
        ),
        content: const Text(
          "You've reached the free plan limit of 5 meals. Upgrade to Pro for unlimited meal planning!",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Not Now"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
            child: const Text("Upgrade"),
          ),
        ],
      ),
    );
  }

  void _showRecipeSelector(
    BuildContext context,
    DateTime? date,
    List<Recipe> recipes,
    bool isLimitReached,
  ) {
    if (isLimitReached) {
      _showUpgradePrompt(context);
      return;
    }

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
                            title: Text(recipe.title),
                            subtitle: Text(
                              "${recipe.ingredients.length} ingredients",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
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
  final bool isLimitReached;

  const _DayCard({
    required this.date,
    required this.meals,
    required this.allRecipes,
    required this.ref,
    required this.isLimitReached,
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
                Row(
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
                    if (isToday)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Today",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    isLimitReached
                        ? Icons.lock_outline
                        : Icons.add_circle_outline,
                    color: isLimitReached ? Colors.grey : Colors.grey,
                  ),
                  onPressed: () {
                    final screenState = context
                        .findAncestorStateOfType<_MealPlannerScreenState>();
                    if (isLimitReached) {
                      screenState?._showUpgradePrompt(context);
                    } else {
                      screenState?._showRecipeSelector(
                        context,
                        date,
                        allRecipes,
                        isLimitReached,
                      );
                    }
                  },
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
                      Expanded(
                        child: Text(
                          recipe.title,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
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
