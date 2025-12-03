import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io';

import 'firebase_options.dart';

// Services
import 'services/auth_service.dart';
import 'services/user_service.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/household_onboarding_screen.dart';
import 'screens/meal_planner_screen.dart';
import 'screens/shopping_list_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/add_recipe_screen.dart';
import 'screens/recipe_detail_screen.dart';
import 'screens/dashboard_screen.dart';
import 'providers/recipe_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize RevenueCat
  try {
    final config = PurchasesConfiguration(
      Platform.isIOS
          ? 'appl_ADwaqVNAwvKvALzvYbmHkZEfuWX'
          : 'appl_ADwaqVNAwvKvALzvYbmHkZEfuWX', // Use Android key when available
    );
    await Purchases.configure(config);
    debugPrint("✅ RevenueCat configured successfully");
  } catch (e) {
    debugPrint("⚠️ RevenueCat configuration failed: $e");
    // Continue without RevenueCat - app should still work
  }

  runApp(const ProviderScope(child: FamilyEatsApp()));
}

class FamilyEatsApp extends ConsumerWidget {
  const FamilyEatsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'FamilyEats',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A6C47),
          surface: const Color(0xFFF5F7F5),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: authState.when(
        data: (user) {
          if (user == null) {
            return const LoginScreen();
          }
          // User is logged in - check onboarding status
          return const _AuthenticatedWrapper();
        },
        loading: () => const _LoadingScreen(),
        error: (e, stack) {
          debugPrint("Auth error: $e");
          // On auth error, show login screen
          return const LoginScreen();
        },
      ),
    );
  }
}

/// Wrapper that checks if user has completed onboarding
class _AuthenticatedWrapper extends ConsumerWidget {
  const _AuthenticatedWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingComplete = ref.watch(onboardingCompleteProvider);

    return onboardingComplete.when(
      data: (isComplete) {
        if (!isComplete) {
          return const HouseholdOnboardingScreen();
        }
        return const MainTabScaffold();
      },
      loading: () => const _LoadingScreen(),
      error: (e, _) {
        debugPrint("Onboarding check error: $e");
        // On error, show onboarding to let user create/join household
        return const HouseholdOnboardingScreen();
      },
    );
  }
}

/// Simple loading screen
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F7F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Color(0xFF4A6C47)),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFF4A6C47)),
            SizedBox(height: 16),
            Text(
              "Loading...",
              style: TextStyle(
                color: Color(0xFF4A6C47),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Main App Shell (Only shown after login AND onboarding)
class MainTabScaffold extends StatefulWidget {
  const MainTabScaffold({super.key});

  @override
  State<MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends State<MainTabScaffold> {
  int _selectedIndex = 0;

  void _goToTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(
        onNavigateToPlan: () => _goToTab(1),
        onNavigateToShop: () => _goToTab(3),
      ),
      const MealPlannerScreen(),
      const RecipeListScreenWrap(),
      const ShoppingListScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _goToTab,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF4A6C47).withOpacity(0.1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF4A6C47)),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: Color(0xFF4A6C47)),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book, color: Color(0xFF4A6C47)),
            label: 'Recipes',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart, color: Color(0xFF4A6C47)),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Color(0xFF4A6C47)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

/// Wrapper for Recipe List
class RecipeListScreenWrap extends ConsumerWidget {
  const RecipeListScreenWrap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncRecipes = ref.watch(recipeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Cookbook")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (c) => const AddRecipeScreen()),
          );
        },
        backgroundColor: const Color(0xFF4A6C47),
        foregroundColor: Colors.white,
        label: const Text("New Recipe"),
        icon: const Icon(Icons.add),
      ),
      body: asyncRecipes.when(
        data: (recipes) {
          if (recipes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No recipes yet",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap the button below to add your first recipe",
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    recipe.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("${recipe.ingredients.length} ingredients"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => RecipeDetailScreen(recipe: recipe),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) {
          debugPrint("Recipe loading error: $err");
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  "Error loading recipes",
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => ref.invalidate(recipeProvider),
                  child: const Text("Retry"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
