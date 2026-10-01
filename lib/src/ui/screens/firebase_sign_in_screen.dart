import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FirebaseSignInScreen extends StatefulWidget {
  const FirebaseSignInScreen({super.key});

  @override
  State<FirebaseSignInScreen> createState() => _FirebaseSignInScreenState();
}

class _FirebaseSignInScreenState extends State<FirebaseSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isBusy = false;
  bool _obscurePassword = true;
  bool _isCreateAccount = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool createAccount}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      final auth = FirebaseAuth.instance;
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (createAccount) {
        await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyAuthError(error, isSigningUp: createAccount)),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to authenticate right now.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter your email first.')));
      return;
    }

    setState(() => _isBusy = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyAuthError(error))));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _friendlyAuthError(
    FirebaseAuthException error, {
    bool isSigningUp = false,
  }) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
        return 'The email or password is not correct. Please try again.';
      case 'user-not-found':
        return 'This account is not registered yet. Create an account to continue.';
      case 'email-already-in-use':
        return 'An account already uses this email. Sign in instead.';
      case 'weak-password':
        return 'Your password needs at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'Please check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment, then try again.';
      case 'user-disabled':
        return 'This account is currently unavailable. Please contact an administrator.';
      default:
        return isSigningUp
            ? 'We could not create your account right now. Please try again.'
            : 'We could not sign you in right now. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6B4423), Color(0xFFF3D9C6), Color(0xFFFFF7EF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surface.withValues(alpha: 0.94),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Image.asset(
                              'assets/haven_logo.png',
                              width: 84,
                              height: 84,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _isCreateAccount
                                ? 'Create your Haven & Co. account'
                                : 'Sign in to Haven & Co.',
                            style: theme.textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isCreateAccount
                                ? 'Create a secure account to access the POS from your devices.'
                                : 'Use your email and password to access the POS and sync data to Firebase.',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Enter an email address.';
                              }
                              if (!text.contains('@')) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  );
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if ((value ?? '').length < 6) {
                                return 'Use at least 6 characters.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _isBusy
                                ? null
                                : () =>
                                      _submit(createAccount: _isCreateAccount),
                            child: Text(
                              _isBusy
                                  ? (_isCreateAccount
                                        ? 'Creating account...'
                                        : 'Signing in...')
                                  : (_isCreateAccount
                                        ? 'Create account'
                                        : 'Sign in'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _isBusy
                                ? null
                                : () => setState(
                                    () => _isCreateAccount = !_isCreateAccount,
                                  ),
                            child: Text(
                              _isCreateAccount
                                  ? 'I already have an account'
                                  : 'Create a new account',
                            ),
                          ),
                          if (!_isCreateAccount) ...[
                            const SizedBox(height: 4),
                            TextButton(
                              onPressed: _isBusy ? null : _sendPasswordReset,
                              child: const Text('Forgot password?'),
                            ),
                          ],
                        ],
                      ),
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
