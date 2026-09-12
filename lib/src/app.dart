import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/coffee_pos_repository.dart';
import 'state/coffee_pos_controller.dart';
import 'ui/screens/firebase_sign_in_screen.dart';
import 'ui/screens/coffee_pos_home.dart';

class CoffeePosApp extends StatelessWidget {
  const CoffeePosApp({super.key, this.firebaseInitializationError});

  final String? firebaseInitializationError;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF7A4E2D),
          brightness: Brightness.light,
          surface: const Color(0xFFF7F1E8),
        ).copyWith(
          primary: const Color(0xFF6B4423),
          secondary: const Color(0xFFC8833A),
          tertiary: const Color(0xFF4E7A5A),
          surface: const Color(0xFFFFFBF6),
          onSurface: const Color(0xFF2D241D),
        );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Haven & Co.',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF4EDE3),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
          headlineMedium: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleMedium: TextStyle(fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontWeight: FontWeight.w500),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFFFFCF8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0x1A6B4423)),
          ),
        ),
      ),
      home: _FirebaseGate(error: firebaseInitializationError),
    );
  }
}

class _FirebaseGate extends StatelessWidget {
  const _FirebaseGate({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return _FirebaseUnavailableScreen(error: error);
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _FirebaseLoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          return const FirebaseSignInScreen();
        }

        return _CoffeePosSession(key: ValueKey(user.uid));
      },
    );
  }
}

class _CoffeePosSession extends StatefulWidget {
  const _CoffeePosSession({super.key});

  @override
  State<_CoffeePosSession> createState() => _CoffeePosSessionState();
}

class _CoffeePosSessionState extends State<_CoffeePosSession> {
  late final CoffeePosController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CoffeePosController(
      repository: InMemoryCoffeePosRepository(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CoffeePosScope(
      controller: _controller,
      child: const CoffeePosHome(),
    );
  }
}

class _FirebaseLoadingScreen extends StatelessWidget {
  const _FirebaseLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 240,
          child: LinearProgressIndicator(minHeight: 5),
        ),
      ),
    );
  }
}

class _FirebaseUnavailableScreen extends StatelessWidget {
  const _FirebaseUnavailableScreen({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8E9DA), Color(0xFFFFF8F1)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/bites_and_brew_logo.png',
                      width: 88,
                      height: 88,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Firebase is not initialized',
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Firebase could not be initialized. Check that the project configuration matches your Firebase project and that Email/Password sign-in is enabled.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      SelectableText(
                        error!,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
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
