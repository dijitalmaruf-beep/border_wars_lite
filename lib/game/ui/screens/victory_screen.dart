import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../engine/reinforcement_calculator.dart';
import '../../localization/map_localizations.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../widgets/premium_background.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_panel.dart';
import '../widgets/territory_map.dart';
import 'setup_screen.dart';

class VictoryScreen extends StatelessWidget {
  const VictoryScreen({
    required this.state,
    required this.winner,
    required this.didLocalPlayerWin,
    super.key,
  });

  final GameState state;
  final Player winner;
  final bool didLocalPlayerWin;

  @override
  Widget build(BuildContext context) {
    final winnerColor = Color(winner.colorValue);
    final territoryCount = state.ownedTerritoryCount(winner.id);
    final controlledRegions = const ReinforcementCalculator()
        .controlledContinentBonuses(state, winner.id);
    final resultTitle = didLocalPlayerWin ? 'ZAFER' : 'YENİLGİ';
    final resultIcon = didLocalPlayerWin ? Icons.emoji_events : Icons.gpp_maybe;

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: PremiumPanel(
                  borderColor: winnerColor.withValues(alpha: 0.72),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        resultIcon,
                        size: 72,
                        color: winnerColor,
                        shadows: <Shadow>[
                          Shadow(
                            color: winnerColor.withValues(alpha: 0.70),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        resultTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.premiumText,
                          fontSize: 34,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Kazanan: ${winner.name}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFFFD66D),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _StatChip(
                            icon: Icons.flag,
                            label: 'Mod',
                            value: _matchModeLabel(state.matchMode),
                          ),
                          _StatChip(
                            icon: Icons.hourglass_bottom,
                            label: 'Tur',
                            value: '${state.turnNumber}',
                          ),
                          _StatChip(
                            icon: Icons.public,
                            label: 'Bölge',
                            value:
                                '$territoryCount / ${state.territories.length}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _RegionSummary(
                        controlledRegions: controlledRegions,
                        winnerColor: winnerColor,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _goalSummary(state.matchMode, state.territories.length),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.premiumMutedText,
                          fontSize: 12,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      PremiumButton(
                        label: 'SON HARİTA',
                        icon: Icons.public,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => _FinalMapScreen(
                                state: state,
                                winner: winner,
                                controlledContinents: controlledRegions
                                    .map((region) => region.continent)
                                    .toSet(),
                              ),
                            ),
                          );
                        },
                        tone: PremiumButtonTone.gold,
                        height: 54,
                      ),
                      const SizedBox(height: 10),
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
                        height: 54,
                      ),
                      const SizedBox(height: 10),
                      PremiumButton(
                        label: 'ANA EKRAN',
                        icon: Icons.home,
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst);
                        },
                        tone: PremiumButtonTone.dark,
                        height: 54,
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

  String _matchModeLabel(MatchMode mode) {
    switch (mode) {
      case MatchMode.quick:
        return 'Hızlı';
      case MatchMode.standard:
        return 'Standart';
      case MatchMode.conquest:
        return 'Tam Fetih';
    }
  }

  String _goalSummary(MatchMode mode, int totalTerritories) {
    switch (mode) {
      case MatchMode.quick:
        return 'Hızlı hedef: ${mode.requiredTerritories(totalTerritories)} bölge kontrolü.';
      case MatchMode.standard:
        return 'Standart hedef: ${mode.requiredTerritories(totalTerritories)} bölge kontrolü.';
      case MatchMode.conquest:
        return 'Tam fetih hedefi: rakipleri ele veya tüm haritayı kontrol et.';
    }
  }
}

class _FinalMapScreen extends StatelessWidget {
  const _FinalMapScreen({
    required this.state,
    required this.winner,
    required this.controlledContinents,
  });

  final GameState state;
  final Player winner;
  final Set<String> controlledContinents;

  @override
  Widget build(BuildContext context) {
    final winnerColor = Color(winner.colorValue);
    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    SizedBox(
                      width: 46,
                      height: 46,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        color: AppColors.premiumText,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text(
                            'SON HARİTA',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.premiumText,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                          Text(
                            winner.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: winnerColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 46),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: winnerColor.withValues(alpha: 0.70),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: winnerColor.withValues(alpha: 0.22),
                              blurRadius: 24,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.44),
                              blurRadius: 22,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: TerritoryMap(
                            state: state,
                            validSourceIds: const <String>{},
                            validTargetIds: const <String>{},
                            controlledContinents: controlledContinents,
                            isTransferMode: false,
                            victoryOwnerId: winner.id,
                            victoryPulse: 1,
                            onTerritoryTap: (_) {},
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PremiumButton(
                  label: 'GERİ DÖN',
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.of(context).pop(),
                  tone: PremiumButtonTone.dark,
                  height: 50,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegionSummary extends StatelessWidget {
  const _RegionSummary({
    required this.controlledRegions,
    required this.winnerColor,
  });

  final List<ContinentBonus> controlledRegions;
  final Color winnerColor;

  @override
  Widget build(BuildContext context) {
    if (controlledRegions.isEmpty) {
      return _SummaryPanel(
        icon: Icons.map,
        text: 'Kontrol edilen tam kıta yok.',
        color: winnerColor,
      );
    }

    final labels = controlledRegions
        .map(
          (bonus) =>
              '${MapLocalizations.continentName(context, bonus.continent)} +${bonus.value}',
        )
        .join('  •  ');
    return _SummaryPanel(
      icon: Icons.workspace_premium,
      text: labels,
      color: winnerColor,
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xAA06121D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.premiumText,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
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
      width: 118,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xAA081521),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.premiumBorder.withValues(alpha: 0.65),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppColors.premiumGold, size: 17),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.premiumMutedText,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.premiumText,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
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
