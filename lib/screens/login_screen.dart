import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/household_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // --- LOGIN FLOW ---
        await ref
            .read(authServiceProvider)
            .signIn(
              _emailController.text.trim(),
              _passwordController.text.trim(),
            );
        debugPrint("✅ Login successful");
      } else {
        // --- SIGN UP FLOW ---
        final name = _nameController.text.trim();
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        // 1. Create the Auth User
        await ref.read(authServiceProvider).signUp(email, password, name);
        debugPrint("✅ Auth user created");

        // 2. Wait a moment for Firebase to update
        await Future.delayed(const Duration(milliseconds: 500));

        // 3. Initialize Firestore Document
        // We use FirebaseAuth.instance.currentUser directly because the
        // Riverpod provider might not have updated yet.
        final firebaseUser = FirebaseAuth.instance.currentUser;

        if (firebaseUser != null) {
          final userService = UserService(firebaseUser.uid);
          // Create the user doc in Firestore
          await userService.initializeUser(name, email);
          debugPrint("✅ Firestore user document created");

          // 4. Force Refresh
          // Tell Riverpod to reload the user/household providers immediately
          ref.invalidate(userServiceProvider);
          ref.invalidate(currentHouseholdIdProvider);
          ref.invalidate(onboardingCompleteProvider);
        } else {
          throw Exception(
            "Account created but user not found. Please try logging in.",
          );
        }
      }

      // 5. Unfocus keyboard
      if (mounted) {
        FocusScope.of(context).unfocus();
      }

      // The authStateChanges stream in main.dart will handle navigation
    } catch (e) {
      debugPrint("❌ Auth error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGuestLogin() async {
    setState(() => _isLoading = true);
    try {
      // 1. Sign in Anonymously
      final authService = ref.read(authServiceProvider);
      await authService.signInAnonymously();
      debugPrint("✅ Anonymous sign in successful");

      // 2. Wait a moment for Firebase to update
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. Get User (use direct instance for reliability)
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // 4. Initialize a generic User document
        final userService = UserService(user.uid);
        await userService.initializeUser('Guest Chef', '');
        debugPrint("✅ Guest user document created");

        // 5. Auto-create a household (Skip onboarding)
        final householdService = ref.read(householdServiceProvider);
        await userService.createAndJoinHousehold(
          'My Kitchen',
          householdService,
        );
        debugPrint("✅ Guest household created");

        // 6. Force Refresh
        ref.invalidate(userServiceProvider);
        ref.invalidate(currentHouseholdIdProvider);
        ref.invalidate(onboardingCompleteProvider);
      } else {
        throw Exception("Guest login failed - no user created");
      }
    } catch (e) {
      debugPrint("❌ Guest login error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Guest login failed: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo & Branding
                Image.asset(
                  'assets/images/logo.png',
                  height: 90,
                  width: 90,
                  fit: BoxFit.contain,
                  errorBuilder: (c, o, s) => const Icon(
                    Icons.restaurant_menu,
                    size: 90,
                    color: Color(0xFF4A6C47),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "FamilyEats",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A6C47),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLogin
                      ? "Welcome back! What's cooking?"
                      : "Create an account to start planning meals together.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                ),
                const SizedBox(height: 48),

                // Name field (signup only)
                if (!_isLogin) ...[
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (!_isLogin &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A6C47),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: const Color(
                        0xFF4A6C47,
                      ).withOpacity(0.5),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _isLogin ? "Log In" : "Sign Up",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Toggle login/signup
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isLogin = !_isLogin;
                            // Clear form when switching
                            _formKey.currentState?.reset();
                            _nameController.clear();
                            _emailController.clear();
                            _passwordController.clear();
                          });
                        },
                  child: Text(
                    _isLogin
                        ? "Need an account? Sign Up"
                        : "Already have an account? Log In",
                    style: const TextStyle(
                      color: Color(0xFF4A6C47),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Guest mode
                TextButton(
                  onPressed: _isLoading ? null : _handleGuestLogin,
                  child: Text(
                    "Skip for now (Continue as Guest)",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
