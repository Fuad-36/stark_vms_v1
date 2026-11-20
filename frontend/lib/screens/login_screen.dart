import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_routes.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/error_banner.dart';

/// Modern SaaS login screen with form validation, accessibility, and error handling.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  final FocusNode _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    // Prevent duplicate submissions while in progress
    if (_isSubmitting) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.isLoading) return;

    authProvider.clearError();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final success = await authProvider.login(username, password);

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      // Clear password on successful login, navigate to vehicles
      _passwordController.clear();
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.vehicles,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final isLoading = _isSubmitting || authProvider.isLoading;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Logo & Header
                        Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.local_shipping_rounded,
                              size: 30,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Stark VMS',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to your vehicle management account',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Error Banner (Display server error or session invalidation)
                        if (authProvider.errorMessage != null) ...[
                          ErrorBanner(
                            message: authProvider.errorMessage!,
                            onDismiss: () => authProvider.clearError(),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Username Field
                        CustomTextField(
                          controller: _usernameController,
                          label: 'Username',
                          hintText: 'Enter your username',
                          prefixIcon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                          enabled: !isLoading,
                          validator: _validateUsername,
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).requestFocus(_passwordFocusNode);
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password Field
                        CustomTextField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          label: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          enabled: !isLoading,
                          validator: _validatePassword,
                          onFieldSubmitted: (_) => _handleLogin(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                              color: theme.colorScheme.outline,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Submit Button
                        CustomButton(
                          text: 'Sign In',
                          isLoading: isLoading,
                          icon: Icons.login_rounded,
                          onPressed: isLoading ? null : _handleLogin,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
