import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../models/territory.dart';
import 'premium_button.dart';

class AttackDialog extends StatelessWidget {
  const AttackDialog({
    required this.source,
    required this.target,
    required this.winChance,
    super.key,
  });

  final Territory source;
  final Territory target;
  final double winChance;

  @override
  Widget build(BuildContext context) {
    final percent = (winChance * 100).round();
    final advantageColor = percent >= 70
        ? const Color(0xFF91F05B)
        : percent >= 50
        ? AppColors.premiumGold
        : AppColors.premiumRed;
    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xF20C2232), Color(0xFA030910)],
          ),
          border: Border.all(
            color: AppColors.premiumRed.withValues(alpha: 0.72),
            width: 1.4,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.premiumRed.withValues(alpha: 0.26),
              blurRadius: 30,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 24,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: <Color>[
                          AppColors.premiumRed,
                          Color(0xFF6F1519),
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.premiumRed.withValues(alpha: 0.42),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.gps_fixed,
                      color: AppColors.premiumText,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'SALDIRI EMRİ',
                          style: TextStyle(
                            color: AppColors.premiumText,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Hedefi onayla ve saldırıyı başlat.',
                          style: TextStyle(
                            color: AppColors.premiumMutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _AttackRouteCard(
                      label: 'KAYNAK',
                      name: source.name,
                      armies: source.armyCount,
                      color: AppColors.premiumBlue,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward,
                      color: AppColors.premiumText,
                      size: 27,
                    ),
                  ),
                  Expanded(
                    child: _AttackRouteCard(
                      label: 'HEDEF',
                      name: target.name,
                      armies: target.armyCount,
                      color: AppColors.premiumRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xB3081521),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: advantageColor.withValues(alpha: 0.46),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Text(
                          'KAZANMA ŞANSI',
                          style: TextStyle(
                            color: AppColors.premiumGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '%$percent',
                          style: TextStyle(
                            color: advantageColor,
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _AttackChanceBar(
                      value: winChance.clamp(0.0, 1.0).toDouble(),
                      color: advantageColor,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _AttackStat(
                          icon: Icons.shield,
                          label: 'Savunma',
                          value: '${target.armyCount} asker',
                        ),
                        _AttackStat(
                          icon: Icons.public,
                          label: 'Bölge',
                          value: target.continent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Fetih başarılı olursa kaç askerin ilerleyeceğini savaştan sonra sen seçeceksin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.premiumMutedText,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: PremiumButton(
                      label: 'VAZGEÇ',
                      icon: Icons.close,
                      onPressed: () => Navigator.of(context).pop(false),
                      tone: PremiumButtonTone.dark,
                      height: 48,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PremiumButton(
                      label: 'SALDIR',
                      icon: Icons.gps_fixed,
                      onPressed: () => Navigator.of(context).pop(true),
                      tone: PremiumButtonTone.red,
                      height: 48,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttackRouteCard extends StatelessWidget {
  const _AttackRouteCard({
    required this.label,
    required this.name,
    required this.armies,
    required this.color,
  });

  final String label;
  final String name;
  final int armies;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.58)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withValues(alpha: 0.16), blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.premiumText,
              fontSize: 13,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(Icons.shield, color: color, size: 15),
              const SizedBox(width: 5),
              Text(
                '$armies',
                style: const TextStyle(
                  color: AppColors.premiumText,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttackChanceBar extends StatelessWidget {
  const _AttackChanceBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: <Widget>[
          Container(height: 10, color: const Color(0xFF172634)),
          FractionallySizedBox(
            widthFactor: value,
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[color.withValues(alpha: 0.72), color],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttackStat extends StatelessWidget {
  const _AttackStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x88030A12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.premiumBorder.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppColors.premiumMutedText, size: 14),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppColors.premiumMutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.premiumText,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
