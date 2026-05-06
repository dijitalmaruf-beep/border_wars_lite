import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../models/player.dart';
import 'setup_screen.dart';

class VictoryScreen extends StatelessWidget {
  const VictoryScreen({
    required this.winner,
    required this.territoryCount,
    super.key,
  });

  final Player winner;
  final int territoryCount;

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
                  Icon(
                    Icons.emoji_events,
                    size: 72,
                    color: Color(winner.colorValue),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${winner.name} wins',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$territoryCount territories controlled',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<void>(
                          builder: (_) => const SetupScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('New Game'),
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
