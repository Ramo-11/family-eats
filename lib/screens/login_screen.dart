import 'package:firebase_auth/firebase_auth.dart'; // Import required for direct instance access
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
      } else {
        // --- SIGN UP FLOW ---
        final name = _nameController.text.trim();
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        // 1. Create the Auth User
        await ref.read(authServiceProvider).signUp(email, password, name);

        // 2. Initialize Firestore Document (CRITICAL FIX)
        // We use FirebaseAuth.instance.currentUser directly because the
        // Riverpod provider (authServiceProvider) might not have updated yet.
        final firebaseUser = FirebaseAuth.instance.currentUser;

        if (firebaseUser != null) {
          final userService = UserService(firebaseUser.uid);
          // Create the user doc in Firestore
          await userService.initializeUser(name, email);

          // 3. Force Refresh
          // Tell Riverpod to reload the user/household providers immediately
          ref.invalidate(userServiceProvider);
          ref.invalidate(currentHouseholdIdProvider);
        } else {
          throw Exception(
            "Account created but user not found. Please try logging in.",
          );
        }
      }

      // 4. Navigation
      // If your main.dart is listening to authStateChanges, this might happen automatically.
      // If not, we manually pop the login screen or navigate.
      if (mounted) {
        // Option A: If LoginScreen was pushed on top of something, pop it.
        // Navigator.pop(context);

        // Option B: If LoginScreen is your root, the stream in main.dart will handle it.
        // However, to be safe, you can try to unfocus the keyboard.
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
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

      // 2. Get User (CRITICAL FIX: Use direct instance)
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // 3. Initialize a generic User document
        final userService = UserService(user.uid);
        await userService.initializeUser('Guest Chef', '');

        // 4. Auto-create a household (Skip onboarding)
        final householdService = ref.read(householdServiceProvider);
        await userService.createAndJoinHousehold(
          'My Kitchen',
          householdService,
        );

        // 5. Force Refresh
        ref.invalidate(userServiceProvider);
        ref.invalidate(currentHouseholdIdProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Guest login failed: $e")));
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
                  'assets/images/logo.png', // Ensure this asset exists
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
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _formKey.currentState?.reset();
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
                TextButton(
                  onPressed: _isLoading ? null : _handleGuestLogin,
                  child: const Text(
                    "Skip for now (Continue as Guest)",
                    style: TextStyle(
                      color: Colors.grey,
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
