import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_button.dart';
import '../application/food_app_controller.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.controller,
    this.isEntryFlow = false,
    super.key,
  });

  final FoodAppController controller;
  final bool isEntryFlow;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      if (_isRegistering) {
        await widget.controller.register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.controller.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (mounted && !widget.isEntryFlow) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AuthHeader(onBack: () => Navigator.of(context).maybePop()),
                  Transform.translate(
                    offset: const Offset(0, -22),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _authCard(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _authCard(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFE8ECE8)),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFF0F2EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F3D25),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthModeSelector(
            isRegistering: _isRegistering,
            onChanged: _isSubmitting
                ? null
                : (isRegistering) => setState(() {
                    _isRegistering = isRegistering;
                    _error = null;
                  }),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Column(
              key: ValueKey(_isRegistering),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isRegistering ? 'Create your account' : 'Welcome back',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 27,
                    height: 1.15,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _isRegistering
                      ? 'Join Savor and make your next meal memorable.'
                      : 'Sign in to continue to your favorite meals.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 23),
          Form(
            key: _formKey,
            child: Column(
              children: [
                if (_isRegistering) ...[
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                      filled: true,
                      fillColor: AppTheme.canvas,
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: inputBorder.copyWith(
                        borderSide: const BorderSide(
                          color: AppTheme.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter your name'
                        : null,
                  ),
                  const SizedBox(height: 13),
                ],
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                    filled: true,
                    fillColor: AppTheme.canvas,
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: inputBorder.copyWith(
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (value) =>
                      value != null &&
                          RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(value.trim())
                      ? null
                      : 'Enter a valid email address',
                ),
                const SizedBox(height: 13),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: [
                    _isRegistering
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    filled: true,
                    fillColor: AppTheme.canvas,
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: inputBorder.copyWith(
                      borderSide: const BorderSide(
                        color: AppTheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (value) => (value?.length ?? 0) < 8
                      ? 'Use at least 8 characters'
                      : null,
                ),
              ],
            ),
          ),
          if (_isRegistering) ...[
            const SizedBox(height: 9),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Use at least 8 characters for your password.',
                style: TextStyle(fontSize: 11, color: AppTheme.muted),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            _ErrorMessage(message: _error!),
          ],
          const SizedBox(height: 21),
          PrimaryButton(
            label: _isRegistering ? 'Create account' : 'Sign in',
            icon: Icons.arrow_forward_rounded,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: 17),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 14,
                color: AppTheme.primary,
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Your password is securely encrypted.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppTheme.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 47),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF117746), AppTheme.primary, Color(0xFF37A56B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: 33,
            child: Icon(
              Icons.restaurant_rounded,
              size: 150,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Go back',
                    onPressed: onBack,
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.restaurant_menu_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SAVOR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Good food.\nGreat moments.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'Fresh favorites are just a few taps away.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthModeSelector extends StatelessWidget {
  const _AuthModeSelector({
    required this.isRegistering,
    required this.onChanged,
  });

  final bool isRegistering;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _AuthModeOption(
            label: 'Sign in',
            selected: !isRegistering,
            onTap: onChanged == null ? null : () => onChanged!(false),
          ),
          _AuthModeOption(
            label: 'Create account',
            selected: isRegistering,
            onTap: onChanged == null ? null : () => onChanged!(true),
          ),
        ],
      ),
    );
  }
}

class _AuthModeOption extends StatelessWidget {
  const _AuthModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: selected ? AppTheme.primary : AppTheme.muted,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEFEC),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFAE4536),
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}
