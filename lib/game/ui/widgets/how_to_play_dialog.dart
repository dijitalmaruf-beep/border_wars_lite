import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../models/game_state.dart';

Future<void> showHowToPlayDialog(
  BuildContext context, {
  MatchMode matchMode = MatchMode.standard,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF101923),
      title: const Text(
        'Nasıl Oynanır?',
        style: TextStyle(color: AppColors.premiumText),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const _HelpStep(
              icon: Icons.shield,
              title: '1. Takviye',
              body:
                  'Sıra sende başladığında önce kendi bölgelerinden birine takviye yerleştir.',
            ),
            const _HelpStep(
              icon: Icons.sports_martial_arts,
              title: '2. Saldırı',
              body:
                  'Sadece komşu düşman bölgelere saldırabilirsin. Fetih sonrası kaç askerin ilerleyeceğini sen seçersin.',
            ),
            const _HelpStep(
              icon: Icons.swap_horiz,
              title: '3. Transfer',
              body:
                  'Tur başına bir kez, komşu dost bölgeler arasında asker taşıyabilirsin.',
            ),
            const _HelpStep(
              icon: Icons.public,
              title: '4. Bölge Bonusu',
              body:
                  'Bir kıtadaki tüm bölgeleri kontrol edersen sonraki turlarda bonus takviye alırsın.',
            ),
            _HelpStep(
              icon: Icons.emoji_events,
              title: '5. Zafer Hedefi',
              body: _goalText(matchMode),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anladım'),
        ),
      ],
    ),
  );
}

String _goalText(MatchMode mode) {
  switch (mode) {
    case MatchMode.quick:
      return 'Hızlı maçta bölgelerin %40 kontrolü zafer getirir.';
    case MatchMode.standard:
      return 'Standart maçta bölgelerin %70 kontrolü zafer getirir.';
    case MatchMode.conquest:
      return 'Tam fetihte tüm rakipleri ele veya tüm haritayı kontrol et.';
  }
}

class _HelpStep extends StatelessWidget {
  const _HelpStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppColors.premiumGold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.premiumText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.premiumMutedText,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
