import 'package:flutter/material.dart';

import '../../state/coffee_pos_controller.dart';
import '../widgets/coffee_pos_shell.dart';

class CoffeePosHome extends StatefulWidget {
  const CoffeePosHome({super.key});

  @override
  State<CoffeePosHome> createState() => _CoffeePosHomeState();
}

class _CoffeePosHomeState extends State<CoffeePosHome> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = CoffeePosScope.of(context);
    if (controller.isLoading) {
      controller.initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = CoffeePosScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const _LoadingScreen();
        }
        return CoffeePosShell(controller: controller);
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 18,
                    color: Color(0x1F000000),
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/haven_logo.png',
                width: 64,
                height: 64,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Loading Haven & Co.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 240,
              child: LinearProgressIndicator(minHeight: 5),
            ),
          ],
        ),
      ),
    );
  }
}
