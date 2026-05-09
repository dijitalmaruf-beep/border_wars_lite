import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../models/player.dart';
import '../widgets/premium_background.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_panel.dart';
import 'setup_screen.dart';

class VictoryScreen extends StatelessWidget {
  const VictoryScreen({
    required this.winner,
    required this.territoryCount,
    required this.totalTerritoryCount,
    super.key,
  });

  final Player winner;
  final int territoryCount;
  final int totalTerritoryCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: PremiumPanel(
                  borderColor: Color(winner.colorValue).withValues(alpha: 0.72),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Icon(
                        Icons.emoji_events,
                        size: 72,
                        color: Color(winner.colorValue),
                        shadows: <Shadow>[
                          Shadow(
                            color: Color(
                              winner.colorValue,
                            ).withValues(alpha: 0.70),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        winner.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.premiumText,
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'KOMUTAN KAZANDI',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFFD66D),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '$territoryCount / $totalTerritoryCount bölge kontrol altında',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.premiumMutedText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Zafer dünya hakimiyetiyle güvence altına alındı.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.premiumMutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 28),
                      PremiumButton(
                        label: 'YENİ OYUN',
                        icon: Icons.refresh,
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute<void>(
                              builder: (_) => const SetupScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        tone: PremiumButtonTone.blue,
                        height: 56,
                      ),
                    ],
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
