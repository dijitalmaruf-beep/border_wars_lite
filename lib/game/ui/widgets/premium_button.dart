import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

enum PremiumButtonTone {
  blue,
  dark,
  red,
  teal,
  gold,
}

class PremiumButton extends StatelessWidget {
  const PremiumButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = PremiumButtonTone.blue,
    this.height = 64,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final PremiumButtonTone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForTone(tone, isDisabled: onPressed == null);
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colors.first.withValues(alpha: 0.92),
          ),
          boxShadow: <BoxShadow>[
            if (onPressed != null)
              BoxShadow(
                color: colors.last.withValues(alpha: 0.34),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, color: AppColors.premiumText, size: 22),
                      const SizedBox(width: 9),
                      Text(
                        label,
                        maxLines: 1,
                        style: const TextStyle(
                          color: AppColors.premiumText,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
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

  List<Color> _colorsForTone(PremiumButtonTone tone, {required bool isDisabled}) {
    if (isDisabled) {
      return <Color>[
        const Color(0xFF162634),
        const Color(0xFF07111A),
      ];
    }

    switch (tone) {
      case PremiumButtonTone.blue:
        return const <Color>[Color(0xFF087BFF), Color(0xFF003B99)];
      case PremiumButtonTone.dark:
        return const <Color>[Color(0xFF172330), Color(0xFF081018)];
      case PremiumButtonTone.red:
        return const <Color>[Color(0xFFB92D34), Color(0xFF5E171D)];
      case PremiumButtonTone.teal:
        return const <Color>[Color(0xFF0B7B91), Color(0xFF064250)];
      case PremiumButtonTone.gold:
        return const <Color>[AppColors.premiumGold, AppColors.premiumGoldDark];
    }
  }
}
