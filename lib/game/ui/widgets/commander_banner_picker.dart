import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class CommanderBannerPicker extends StatelessWidget {
  const CommanderBannerPicker({
    required this.colorValues,
    required this.selectedColorValue,
    required this.onSelected,
    this.enabled = true,
    super.key,
  });

  final List<int> colorValues;
  final int selectedColorValue;
  final ValueChanged<int> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colorValues
          .map((colorValue) {
            return _CommanderBannerOption(
              colorValue: colorValue,
              isSelected: colorValue == selectedColorValue,
              enabled: enabled,
              onTap: () => onSelected(colorValue),
            );
          })
          .toList(growable: false),
    );
  }
}

class CommanderBannerBadge extends StatelessWidget {
  const CommanderBannerBadge({
    required this.colorValue,
    this.width = 28,
    this.height = 24,
    super.key,
  });

  final int colorValue;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _CommanderBannerPainter(
          color: Color(colorValue),
          isSelected: false,
          enabled: true,
          compact: true,
        ),
      ),
    );
  }
}

class _CommanderBannerOption extends StatelessWidget {
  const _CommanderBannerOption({
    required this.colorValue,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final int colorValue;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(colorValue);
    return Tooltip(
      message: isSelected ? 'Seçili sancak' : 'Sancak seç',
      child: Semantics(
        button: true,
        selected: isSelected,
        label: isSelected ? 'Seçili sancak' : 'Sancak seç',
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: enabled ? 1 : 0.48,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 58,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF172736), Color(0xFF06111B)],
              ),
              border: Border.all(
                color: isSelected
                    ? AppColors.premiumGold
                    : AppColors.premiumBorder.withValues(alpha: 0.72),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: <BoxShadow>[
                if (isSelected)
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                if (isSelected)
                  BoxShadow(
                    color: AppColors.premiumGold.withValues(alpha: 0.24),
                    blurRadius: 16,
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: enabled ? onTap : null,
                splashColor: color.withValues(alpha: 0.18),
                highlightColor: color.withValues(alpha: 0.10),
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CommanderBannerPainter(
                          color: color,
                          isSelected: isSelected,
                          enabled: enabled,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Positioned(
                        right: 6,
                        bottom: 5,
                        child: Icon(
                          Icons.check_circle,
                          color: AppColors.premiumText,
                          size: 15,
                        ),
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

class _CommanderBannerPainter extends CustomPainter {
  const _CommanderBannerPainter({
    required this.color,
    required this.isSelected,
    required this.enabled,
    this.compact = false,
  });

  final Color color;
  final bool isSelected;
  final bool enabled;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = enabled ? 1.0 : 0.58;
    final poleX = size.width * (compact ? 0.22 : 0.25);
    final top = size.height * 0.14;
    final bottom = size.height * (compact ? 0.86 : 0.82);
    final poleWidth = compact ? 2.0 : 3.0;
    final flagTop = size.height * (compact ? 0.16 : 0.18);
    final flagHeight = size.height * (compact ? 0.50 : 0.48);
    final flagBottom = flagTop + flagHeight;
    final flagEnd = size.width * (compact ? 0.90 : 0.82);
    final flagDip = size.width * (compact ? 0.78 : 0.70);
    final flagStart = poleX + poleWidth * 0.7;

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.30 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(
      _flagPath(
        flagStart + 1.5,
        flagTop + 2,
        flagEnd + 1,
        flagDip + 1,
        flagBottom + 2,
      ),
      shadow,
    );

    if (isSelected && !compact) {
      final glow = Paint()
        ..color = color.withValues(alpha: 0.34)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(
        _flagPath(flagStart, flagTop, flagEnd, flagDip, flagBottom),
        glow,
      );
    }

    final poleRect = Rect.fromLTWH(
      poleX - poleWidth / 2,
      top,
      poleWidth,
      bottom - top,
    );
    final polePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          Color(0xFF604622),
          Color(0xFFFFD77C),
          Color(0xFF6F4D1F),
        ],
      ).createShader(poleRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(poleRect, Radius.circular(poleWidth)),
      polePaint,
    );

    final finialPaint = Paint()
      ..color = AppColors.premiumGold.withValues(alpha: 0.95 * opacity);
    canvas.drawCircle(Offset(poleX, top), compact ? 2.3 : 3.3, finialPaint);

    final flagPath = _flagPath(
      flagStart,
      flagTop,
      flagEnd,
      flagDip,
      flagBottom,
    );
    final flagBounds = flagPath.getBounds();
    final highlight = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.22),
      color,
    );
    final lowlight = Color.alphaBlend(
      Colors.black.withValues(alpha: 0.34),
      color,
    );
    final flagPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          highlight.withValues(alpha: 0.98 * opacity),
          color.withValues(alpha: 0.96 * opacity),
          lowlight.withValues(alpha: 0.98 * opacity),
        ],
        stops: const <double>[0, 0.52, 1],
      ).createShader(flagBounds);
    canvas.drawPath(flagPath, flagPaint);

    final satinPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.22 * opacity),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.16 * opacity),
        ],
      ).createShader(flagBounds);
    canvas.drawPath(flagPath, satinPaint);

    final borderPaint = Paint()
      ..color = (isSelected ? AppColors.premiumGold : Colors.white).withValues(
        alpha: (isSelected ? 0.86 : 0.42) * opacity,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 0.9 : 1.2;
    canvas.drawPath(flagPath, borderPaint);

    if (!compact) {
      final emblemPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.32 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      final center = Offset(
        flagStart + (flagEnd - flagStart) * 0.42,
        flagTop + flagHeight * 0.48,
      );
      canvas.drawLine(
        Offset(center.dx - 7, center.dy),
        Offset(center.dx + 7, center.dy),
        emblemPaint,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - 6),
        Offset(center.dx, center.dy + 6),
        emblemPaint,
      );
    }
  }

  Path _flagPath(
    double start,
    double top,
    double end,
    double dip,
    double bottom,
  ) {
    final mid = (top + bottom) / 2;
    return Path()
      ..moveTo(start, top)
      ..cubicTo(start + 9, top - 4, end - 11, top + 3, end, top - 1)
      ..lineTo(dip, mid)
      ..lineTo(end, bottom + 1)
      ..cubicTo(end - 12, bottom - 2, start + 8, bottom + 4, start, bottom)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _CommanderBannerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.enabled != enabled ||
        oldDelegate.compact != compact;
  }
}
