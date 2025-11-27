import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../providers/meal_plan_provider.dart';
import '../providers/recipe_provider.dart';
import '../models/recipe.dart';
import 'add_recipe_screen.dart';
import 'recipe_detail_screen.dart'; // Needed for navigation

class DashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToPlan;
  final VoidCallback onNavigateToShop;

  const DashboardScreen({
    super.key,
    required this.onNavigateToPlan,
    required this.onNavigateToShop,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Show tutorial after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showTutorialModal();
    });
  }

  void _showTutorialModal() {
    // In a real app, check SharedPreferences here (e.g., if (!hasSeenTutorial))
    showDialog(
      context: context,
      barrierDismissible: false, // Force user to interact
      builder: (context) => const _TutorialModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final meals = ref.watch(mealPlanProvider);
    final allRecipes = ref.watch(recipeProvider);

    // 1. Logic: Filter Meals
    final now = DateTime.now();

    // A. Scheduled for specific date (Today)
    final todaysMeals = meals
        .where(
          (m) =>
              m.date != null &&
              m.date!.year == now.year &&
              m.date!.month == now.month &&
              m.date!.day == now.day,
        )
        .toList();

    // B. Flexible / Unscheduled
    final flexibleMeals = meals.where((m) => m.date == null).toList();

    // C. Determine what to show
    final bool showFlexible = todaysMeals.isEmpty && flexibleMeals.isNotEmpty;
    final displayMeals = showFlexible ? flexibleMeals : todaysMeals;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text("Home"),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              "Hello, ${user?.displayName?.split(' ')[0] ?? 'Chef'}! 👋",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A6C47),
              ),
            ),
            const SizedBox(height: 24),

            // "On the Menu" Section
            Row(
              children: [
                const Text(
                  "On the Menu",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (showFlexible)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "Flexible Options",
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (displayMeals.isEmpty)
              _buildEmptyState()
            else
              ...displayMeals.map((entry) {
                // Resolve Recipe
                final recipe = allRecipes.asData?.value.firstWhere(
                  (r) => r.id == entry.recipeId,
                  orElse: () => const Recipe(id: '0', title: 'Loading...'),
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: InkWell(
                    onTap: () {
                      if (recipe != null && recipe.id != '0') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => RecipeDetailScreen(recipe: recipe),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: showFlexible
                                  ? Colors.orange.shade50
                                  : const Color(0xFF4A6C47).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.restaurant,
                              color: showFlexible
                                  ? Colors.orange
                                  : const Color(0xFF4A6C47),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recipe?.title ?? "Loading...",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${recipe?.ingredients.length ?? 0} ingredients",
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 32),

            // Quick Actions
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(Icons.add_circle, "Add Recipe", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => const AddRecipeScreen(),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    Icons.calendar_month,
                    "Go to Plan",
                    widget.onNavigateToPlan,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.nightlight_round, color: Colors.grey, size: 48),
          const SizedBox(height: 16),
          const Text(
            "Nothing planned for today.",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          TextButton(
            onPressed: widget.onNavigateToPlan,
            child: const Text(
              "Plan a meal",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: const Color(0xFF4A6C47)),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// --- MODERN TUTORIAL MODAL ---

class _TutorialModal extends StatefulWidget {
  const _TutorialModal();

  @override
  State<_TutorialModal> createState() => _TutorialModalState();
}

class _TutorialModalState extends State<_TutorialModal> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      "icon": Icons.menu_book,
      "title": "Build Your Cookbook",
      "desc":
          "Add your family's favorite recipes. Use our smart ingredient list to quickly build your database.",
    },
    {
      "icon": Icons.calendar_month,
      "title": "Flexible Planning",
      "desc":
          "Assign meals to specific days, or add them to a 'Weekly Flexible' list for busy weeks.",
    },
    {
      "icon": Icons.shopping_cart,
      "title": "Smart Shopping",
      "desc":
          "We automatically generate your grocery list based on your meal plan. Syncs instantly with your partner!",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
        height: 450,
        child: Column(
          children: [
            // Top Right Close Button
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Swipeable Content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (int page) {
                  setState(() => _currentPage = page);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final data = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A6C47).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            data['icon'],
                            size: 64,
                            color: const Color(0xFF4A6C47),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          data['title'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          data['desc'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation Area
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicators (Dots)
                  Row(
                    children: List.generate(_pages.length, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFF4A6C47)
                              : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  // Next / Finish Button
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A6C47),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1
                          ? "Get Started"
                          : "Next",
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
