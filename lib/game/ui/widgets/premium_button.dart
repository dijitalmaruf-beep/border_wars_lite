import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

enum PremiumButtonTone { blue, dark, red, teal, gold }

class PremiumButton extends StatefulWidget {
  const PremiumButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = PremiumButtonTone.blue,
    this.height = 64,
    this.isSelected = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final PremiumButtonTone tone;
  final double height;
  final bool isSelected;

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForTone(
      widget.tone,
      isDisabled: widget.onPressed == null && !widget.isSelected,
    );
    final accent = colors.first;
    final isInteractive = widget.onPressed != null;
    return AnimatedScale(
      duration: const Duration(milliseconds: 80),
      scale: _isPressed && isInteractive ? 0.975 : 1,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: isInteractive || widget.isSelected ? 1 : 0.54,
        child: SizedBox(
          height: widget.height,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _isPressed && isInteractive
                    ? colors
                          .map(
                            (color) => Color.alphaBlend(
                              Colors.white.withValues(alpha: 0.10),
                              color,
                            ),
                          )
                          .toList()
                    : colors,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isSelected
                    ? accent.withValues(alpha: 1)
                    : accent.withValues(alpha: isInteractive ? 0.78 : 0.38),
                width: widget.isSelected ? 1.7 : 1,
              ),
              boxShadow: <BoxShadow>[
                if (isInteractive || widget.isSelected)
                  BoxShadow(
                    color: accent.withValues(
                      alpha: widget.isSelected ? 0.50 : 0.28,
                    ),
                    blurRadius: widget.isSelected ? 22 : 13,
                    offset: const Offset(0, 5),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                splashColor: accent.withValues(alpha: 0.22),
                highlightColor: accent.withValues(alpha: 0.10),
                onTap: widget.onPressed,
                onTapDown: isInteractive
                    ? (_) => setState(() => _isPressed = true)
                    : null,
                onTapCancel: () => setState(() => _isPressed = false),
                onTapUp: (_) => setState(() => _isPressed = false),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            widget.icon,
                            color:
                                widget.onPressed == null && !widget.isSelected
                                ? AppColors.premiumMutedText
                                : AppColors.premiumText,
                            size: 22,
                          ),
                          const SizedBox(width: 9),
                          Text(
                            widget.label,
                            maxLines: 1,
                            style: TextStyle(
                              color:
                                  widget.onPressed == null && !widget.isSelected
                                  ? AppColors.premiumMutedText
                                  : AppColors.premiumText,
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
        ),
      ),
    );
  }

  List<Color> _colorsForTone(
    PremiumButtonTone tone, {
    required bool isDisabled,
  }) {
    if (isDisabled) {
      return <Color>[const Color(0xFF0E1720), const Color(0xFF050B11)];
    }

    switch (tone) {
      case PremiumButtonTone.blue:
        return const <Color>[Color(0xFF087BFF), Color(0xFF003B99)];
      case PremiumButtonTone.dark:
        return const <Color>[Color(0xFF172330), Color(0xFF081018)];
      case PremiumButtonTone.red:
        return const <Color>[Color(0xFFE0443A), Color(0xFF65171A)];
      case PremiumButtonTone.teal:
        return const <Color>[Color(0xFF0BA6B8), Color(0xFF064250)];
      case PremiumButtonTone.gold:
        return const <Color>[AppColors.premiumGold, AppColors.premiumGoldDark];
    }
  }
}
