import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import 'setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Border Wars Lite',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Conquer the world map before the bots do.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 36),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SetupScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.flag),
                    label: const Text('New Game'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.history),
                    label: const Text('Continue Game'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.settings),
                    label: const Text('Settings'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
