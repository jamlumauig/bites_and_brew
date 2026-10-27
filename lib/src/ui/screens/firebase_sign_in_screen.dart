import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../state/demo_session_manager.dart';

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
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      // Direct demo account sign-in (supports demo, demo2, demo@..., etc.)
      if (!createAccount && email.startsWith('demo')) {
        await DemoSessionManager.instance.enterDemoMode();
        return;
      }

      final auth = FirebaseAuth.instance;

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
        const SnackBar(content: Text('Unable to sign in right now. Please try again.')),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Card(
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
                              'assets/lunan_logo.png',
                              width: 84,
                              height: 84,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _isCreateAccount
                                ? 'Create your LUNAN account'
                                : 'Sign in to LUNAN',
                            style: theme.textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'May lugar ka rito.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: const Color(0xFF6B4423),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isCreateAccount
                                ? 'Create a secure account to access your store register.'
                                : 'Sign in to access your register, menu, and store records.',
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
                              final text = value?.trim().toLowerCase() ?? '';
                              if (text.isEmpty) {
                                return 'Enter an email address.';
                              }
                              if (text.startsWith('demo')) {
                                return null;
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
                              final email = _emailController.text.trim().toLowerCase();
                              if (email.startsWith('demo')) {
                                return null;
                              }
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
                          // const SizedBox(height: 16),
                          // const Row(
                          //   children: [
                          //     Expanded(child: Divider()),
                          //     Padding(
                          //       padding: EdgeInsets.symmetric(horizontal: 12),
                          //       child: Text(
                          //         'OR',
                          //         style: TextStyle(
                          //           fontSize: 12,
                          //           fontWeight: FontWeight.w600,
                          //           color: Colors.black45,
                          //         ),
                          //       ),
                          //     ),
                          //     Expanded(child: Divider()),
                          //   ],
                          // ),
                          // const SizedBox(height: 16),
                          // FilledButton.tonalIcon(
                          //   key: const ValueKey('explore_demo_admin_button'),
                          //   onPressed: _isBusy
                          //       ? null
                          //       : () async {
                          //           setState(() => _isBusy = true);
                          //           await DemoSessionManager.instance.enterDemoMode();
                          //           if (mounted) {
                          //             setState(() => _isBusy = false);
                          //           }
                          //         },
                          //   icon: const Icon(Icons.science_outlined),
                          //   label: const Text('Explore Demo Admin Mode'),
                          //   style: FilledButton.styleFrom(
                          //     padding: const EdgeInsets.symmetric(vertical: 14),
                          //     backgroundColor: const Color(0xFFF3E5D8),
                          //     foregroundColor: const Color(0xFF6B4423),
                          //   ),
                          // ),
                          // const SizedBox(height: 6),
                          // const Text(
                          //   'Isolated sandbox with realistic sample data. Changes do not affect production.',
                          //   style: TextStyle(fontSize: 11, color: Colors.black54),
                          //   textAlign: TextAlign.center,
                          // ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Developed by Jam Lumauig, 2026',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B4423).withValues(alpha: 0.8),
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
  }
}
