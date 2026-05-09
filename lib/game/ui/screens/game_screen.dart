import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/game_constants.dart';
import '../../../services/firebase/firestore_game_repository.dart';
import '../../../services/local/game_settings.dart';
import '../../../services/local/local_save_repository.dart';
import '../../../services/local/settings_repository.dart';
import '../../engine/game_engine.dart';
import '../../engine/reinforcement_calculator.dart';
import '../../models/attack_result.dart';
import '../../models/game_state.dart';
import '../../models/player.dart';
import '../../models/territory.dart';
import '../widgets/attack_dialog.dart';
import '../widgets/premium_background.dart';
import '../widgets/premium_button.dart';
import '../widgets/premium_panel.dart';
import '../widgets/territory_map.dart';
import 'victory_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    required this.initialState,
    this.onlineRepository,
    this.localPlayerId,
    super.key,
  });

  final GameState initialState;
  final FirestoreGameRepository? onlineRepository;
  final String? localPlayerId;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum _MapCommandMode { attack, transfer }

enum _GameMenuAction { continueGame, exitToHome }

class _GameScreenState extends State<GameScreen> {
  final GameEngine _engine = const GameEngine();
  final Random _random = Random();
  final LocalSaveRepository _localSaveRepository = const LocalSaveRepository();
  final SettingsRepository _settingsRepository = const SettingsRepository();

  late GameState _state;
  GameSettings _settings = const GameSettings();
  _MapCommandMode _commandMode = _MapCommandMode.attack;
  Timer? _botTimer;
  Timer? _turnTimer;
  StreamSubscription<GameState?>? _onlineSubscription;
  bool _isBotThinking = false;
  bool _navigatedToVictory = false;
  bool _isSavingOnline = false;
  int _remainingTurnSeconds = GameConstants.turnDurationSeconds;
  Set<String> _announcedControlledContinents = const <String>{};

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
    _remainingTurnSeconds = _secondsLeftFor(_state);
    _announcedControlledContinents = _controlledContinentsFor(_state);
    unawaited(_loadSettings());
    _subscribeToOnlineGame();
    _startTurnTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterStateChanged());
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _turnTimer?.cancel();
    _onlineSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAttack =
        _state.selectedSourceId != null &&
        _state.selectedTargetId != null &&
        _engine.canAttack(
          _state,
          sourceId: _state.selectedSourceId!,
          targetId: _state.selectedTargetId!,
        );
    final canTransfer = _canTransferSelection(_state);
    final winChance = canAttack ? _engine.winChanceForSelection(_state) : 0.0;
    final reinforcementBreakdown = _engine.reinforcementCalculator
        .breakdownForPlayer(_state, _state.currentPlayer.id);
    final controlledContinents = _controlledContinentsFor(_state);
    final validSourceIds = _validSourceIdsFor(_state);
    final validTargetIds = _validTargetIdsFor(_state);
    final canAct = _canLocalPlayerAct;

    return Scaffold(
      body: PremiumBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth >= 720
                  ? 720.0
                  : double.infinity;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _WorldHeader(
                          state: _state,
                          isOnline: _isOnline,
                          isLocalTurn: canAct,
                          gameId: _state.id,
                          remainingTurnSeconds: _remainingTurnSeconds,
                          onMenuPressed: _showGameMenu,
                          onHelpPressed: _showHowToPlay,
                        ),
                        const SizedBox(height: 8),
                        _PlayerStrip(state: _state),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _MapStage(
                            state: _state,
                            validSourceIds: validSourceIds,
                            validTargetIds: validTargetIds,
                            controlledContinents: controlledContinents,
                            onTerritoryTap: _handleTerritoryTap,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _BattleCommandPanel(
                          state: _state,
                          commandMode: _commandMode,
                          canAttack: canAttack,
                          canTransfer: canTransfer,
                          winChance: winChance,
                          reinforcementBreakdown: reinforcementBreakdown,
                          isBotThinking: _isBotThinking,
                          isOnline: _isOnline,
                          isSavingOnline: _isSavingOnline,
                          canAct: canAct,
                          onAttack: _handleAttack,
                          onSelectAttackMode: _enterAttackMode,
                          onSelectTransferMode: _enterTransferMode,
                          onTransfer: _handleTransferAction,
                          onEndTurn: _handleEndTurn,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleTerritoryTap(String territoryId) {
    if (!_canLocalPlayerAct || _state.winnerId != null) {
      return;
    }
    if (_state.phase == GamePhase.attack &&
        _commandMode == _MapCommandMode.transfer) {
      _setGameState(_selectTransferTerritory(_state, territoryId));
      return;
    }

    _setGameState(_engine.selectTerritory(_state, territoryId));
  }

  Future<void> _handleAttack() async {
    if (!_canLocalPlayerAct) {
      return;
    }
    final source = _state.territoryByIdOrNull(_state.selectedSourceId);
    final target = _state.territoryByIdOrNull(_state.selectedTargetId);
    if (source == null || target == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AttackDialog(
        source: source,
        target: target,
        winChance: _engine.winChanceForSelection(_state),
      ),
    );

    if (confirmed == true && mounted) {
      final battleState = _state;
      final result = _engine.resolveSelectedAttack(
        battleState,
        random: _random,
      );
      if (result == null) {
        _setGameState(battleState.copyWith(statusMessage: 'Geçersiz saldırı.'));
        return;
      }
      if (!result.didWin) {
        _setGameState(_engine.applyAttackResult(battleState, result));
        return;
      }

      final amount = await _showConquestMoveSheet(battleState, result);
      if (!mounted) {
        return;
      }
      final selectedAmount =
          amount ?? _engine.movedArmiesOnWinForSelection(battleState);
      _setGameState(
        _engine.applyAttackResult(
          battleState,
          result.copyWith(movedArmies: selectedAmount),
        ),
      );
    }
  }

  void _handleEndTurn() {
    if (!_canLocalPlayerAct || _state.winnerId != null) {
      return;
    }
    if (_settings.confirmEndTurn) {
      unawaited(_confirmEndTurn());
      return;
    }
    _endTurnNow();
  }

  Future<void> _confirmEndTurn() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101923),
        title: const Text(
          'Turu bitir?',
          style: TextStyle(color: AppColors.premiumText),
        ),
        content: Text(
          _state.phase == GamePhase.reinforce
              ? 'Saldırıya geçmeden önce takviye yapman gerekiyor.'
              : 'Mevcut komut aşaman sona erecek.',
          style: const TextStyle(color: AppColors.premiumMutedText),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Turu Bitir'),
          ),
        ],
      ),
    );

    if (shouldEnd == true && mounted) {
      _endTurnNow();
    }
  }

  void _endTurnNow() {
    _commandMode = _MapCommandMode.attack;
    _setGameState(_engine.endTurn(_state));
  }

  void _setGameState(
    GameState nextState, {
    bool? isBotThinking,
    bool syncOnline = true,
  }) {
    setState(() {
      _state = nextState;
      if (isBotThinking != null) {
        _isBotThinking = isBotThinking;
      }
      if (_state.phase != GamePhase.attack || _state.currentPlayer.isBot) {
        _commandMode = _MapCommandMode.attack;
      }
    });
    _startTurnTimer();
    _maybeAnnounceControlledContinents(nextState);
    if (syncOnline) {
      unawaited(_saveOnlineState(nextState));
    }
    unawaited(_saveLocalState(nextState));
    _afterStateChanged();
  }

  void _enterAttackMode() {
    if (!_canLocalPlayerAct || _state.phase != GamePhase.attack) {
      return;
    }
    setState(() {
      _commandMode = _MapCommandMode.attack;
      _state = _state.copyWith(
        selectedTargetId: null,
        statusMessage: 'Saldırmak için komşu bir düşman bölgesi seç.',
      );
    });
  }

  Future<void> _showGameMenu() async {
    final action = await showDialog<_GameMenuAction>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101923),
        title: const Text(
          'Oyun Menüsü',
          style: TextStyle(color: AppColors.premiumText),
        ),
        content: const Text(
          'Fethe devam et veya ana ekrana dön.',
          style: TextStyle(color: AppColors.premiumMutedText),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_GameMenuAction.continueGame),
            child: const Text('Devam Et'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_GameMenuAction.exitToHome),
            child: const Text('Ana Ekrana Çık'),
          ),
        ],
      ),
    );

    if (action != _GameMenuAction.exitToHome || !mounted) {
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101923),
        title: const Text(
          'Oyundan çıkılsın mı?',
          style: TextStyle(color: AppColors.premiumText),
        ),
        content: const Text(
          'Otomatik kayıt açıksa yerel ilerleme kaydedilir.',
          style: TextStyle(color: AppColors.premiumMutedText),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );

    if (shouldExit != true || !mounted) {
      return;
    }

    _botTimer?.cancel();
    unawaited(_saveLocalState(_state));
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _showHowToPlay() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF101923),
        title: const Text(
          'Nasıl Oynanır?',
          style: TextStyle(color: AppColors.premiumText),
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _HelpStep(
                icon: Icons.shield,
                title: '1. Takviye',
                body:
                    'Sıran burada başlar. Tüm takviyeyi yerleştirmek için kendi bölgelerinden birine dokun.',
              ),
              _HelpStep(
                icon: Icons.sports_martial_arts,
                title: '2. Saldırı',
                body:
                    'Önce kendi bölgeni, sonra komşu düşman bölgesini seç. Kazanırsan kaç askerin ilerleyeceğini savaştan sonra sen belirlersin.',
              ),
              _HelpStep(
                icon: Icons.swap_horiz,
                title: '3. Transfer',
                body:
                    'Tur başına bir kez, komşu dost bölgeler arasında asker taşıyabilirsin. Kaynak bölgede en az 1 asker kalmalı.',
              ),
              _HelpStep(
                icon: Icons.public,
                title: '4. Kıta Kontrolü',
                body:
                    'Bir kıtadaki tüm bölgeleri alırsan bonus takviye kazanırsın ve kıta haritada vurgulanır.',
              ),
              _HelpStep(
                icon: Icons.timer,
                title: '5. Süreyi İzle',
                body:
                    'Her oyuncunun 90 saniyesi var. Süre biterse oyun turu otomatik çözer.',
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

  void _enterTransferMode() {
    if (!_canLocalPlayerAct || _state.phase != GamePhase.attack) {
      return;
    }
    if (_state.transferUsedThisTurn) {
      setState(() {
        _state = _state.copyWith(
          statusMessage: 'Bu tur transfer hakkı kullanıldı.',
        );
      });
      return;
    }

    setState(() {
      _commandMode = _MapCommandMode.transfer;
      _state = _state.copyWith(
        selectedTargetId: null,
        statusMessage: 'Önce kaynak dost bölgeyi, sonra komşu dost hedefi seç.',
      );
    });
  }

  Future<void> _handleTransferAction() async {
    if (!_canLocalPlayerAct || _state.phase != GamePhase.attack) {
      return;
    }

    if (!_canTransferSelection(_state)) {
      _setGameState(
        _state.copyWith(
          statusMessage: 'Transfer için komşu dost bölgeleri seç.',
        ),
      );
      return;
    }

    final source = _state.territoryByIdOrNull(_state.selectedSourceId);
    final target = _state.territoryByIdOrNull(_state.selectedTargetId);
    if (source == null || target == null) {
      return;
    }

    final amount = await _showTransferAmountSheet(source, target);
    if (amount == null || !mounted) {
      return;
    }

    _setGameState(_engine.transferArmies(_state, source.id, target.id, amount));
  }

  Future<int?> _showTransferAmountSheet(Territory source, Territory target) {
    final maxTransfer = source.armyCount - 1;
    var selectedAmount = max(1, ((source.armyCount - 1) / 2).floor());

    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                void updateAmount(int value) {
                  setSheetState(() {
                    selectedAmount = value.clamp(1, maxTransfer).toInt();
                  });
                }

                return PremiumPanel(
                  borderColor: AppColors.premiumCyan.withValues(alpha: 0.70),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'ASKER TRANSFERİ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.premiumText,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${source.name} -> ${target.name}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.premiumMutedText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _AmountButton(
                            icon: Icons.remove,
                            onPressed: selectedAmount > 1
                                ? () => updateAmount(selectedAmount - 1)
                                : null,
                          ),
                          SizedBox(
                            width: 96,
                            child: Text(
                              '$selectedAmount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.premiumText,
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                          ),
                          _AmountButton(
                            icon: Icons.add,
                            onPressed: selectedAmount < maxTransfer
                                ? () => updateAmount(selectedAmount + 1)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (maxTransfer > 1)
                        Slider(
                          value: selectedAmount.toDouble(),
                          min: 1,
                          max: maxTransfer.toDouble(),
                          divisions: maxTransfer - 1,
                          activeColor: AppColors.premiumCyan,
                          inactiveColor: AppColors.premiumBorder,
                          onChanged: (value) => updateAmount(value.round()),
                        )
                      else
                        const SizedBox(height: 28),
                      Text(
                        'Kaynak bölgede ${source.armyCount - selectedAmount} asker kalır.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.premiumMutedText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: PremiumButton(
                              label: 'VAZGEÇ',
                              icon: Icons.close,
                              onPressed: () => Navigator.of(context).pop(),
                              tone: PremiumButtonTone.dark,
                              height: 48,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: PremiumButton(
                              label: '$selectedAmount TAŞI',
                              icon: Icons.swap_horiz,
                              onPressed: () =>
                                  Navigator.of(context).pop(selectedAmount),
                              tone: PremiumButtonTone.teal,
                              height: 48,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<int?> _showConquestMoveSheet(
    GameState battleState,
    AttackResult result,
  ) {
    final source = battleState.territoryById(result.sourceId);
    final target = battleState.territoryById(result.targetId);
    final maxMove = max(
      1,
      _engine.maxMovedArmiesOnWinForSelection(battleState),
    );
    var selectedAmount = result.movedArmies.clamp(1, maxMove).toInt();

    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                12 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  void updateAmount(int value) {
                    setSheetState(() {
                      selectedAmount = value.clamp(1, maxMove).toInt();
                    });
                  }

                  return PremiumPanel(
                    borderColor: AppColors.premiumGold.withValues(alpha: 0.78),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Icon(
                          Icons.flag,
                          color: AppColors.premiumGold,
                          size: 34,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${target.name} FETHEDİLDİ',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.premiumText,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${source.name} bölgesinden kaç asker ilerlesin?',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.premiumMutedText,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            _AmountButton(
                              icon: Icons.remove,
                              onPressed: selectedAmount > 1
                                  ? () => updateAmount(selectedAmount - 1)
                                  : null,
                            ),
                            SizedBox(
                              width: 104,
                              child: Text(
                                '$selectedAmount',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.premiumText,
                                  fontSize: 40,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            _AmountButton(
                              icon: Icons.add,
                              onPressed: selectedAmount < maxMove
                                  ? () => updateAmount(selectedAmount + 1)
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (maxMove > 1)
                          Slider(
                            value: selectedAmount.toDouble(),
                            min: 1,
                            max: maxMove.toDouble(),
                            divisions: maxMove - 1,
                            activeColor: AppColors.premiumGold,
                            inactiveColor: AppColors.premiumBorder,
                            onChanged: (value) => updateAmount(value.round()),
                          )
                        else
                          const SizedBox(height: 28),
                        Text(
                          '${target.name}: $selectedAmount asker | ${source.name}: ${source.armyCount - selectedAmount} asker kalır',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.premiumMutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        PremiumButton(
                          label: '$selectedAmount ASKERİ İLERLET',
                          icon: Icons.flag,
                          onPressed: () =>
                              Navigator.of(context).pop(selectedAmount),
                          tone: PremiumButtonTone.gold,
                          height: 50,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  GameState _selectTransferTerritory(GameState state, String territoryId) {
    if (state.transferUsedThisTurn) {
      return state.copyWith(statusMessage: 'Bu tur transfer hakkı kullanıldı.');
    }

    final territory = state.territoryById(territoryId);
    final currentPlayerId = state.currentPlayer.id;

    if (territory.ownerId != currentPlayerId) {
      return state.copyWith(
        selectedTargetId: null,
        statusMessage: 'Transfer için komşu dost bölgeler gerekir.',
      );
    }

    final sourceId = state.selectedSourceId;
    if (sourceId == null || sourceId == territoryId) {
      if (territory.armyCount <= 1) {
        return state.copyWith(
          selectedTargetId: null,
          statusMessage:
              'Transfer için kaynak bölgede 1 askerden fazla olmalı.',
        );
      }
      return state.copyWith(
        selectedSourceId: territoryId,
        selectedTargetId: null,
        statusMessage: '${territory.name} transfer kaynağı seçildi.',
      );
    }

    final source = state.territoryById(sourceId);
    if (source.ownerId != currentPlayerId) {
      return state.copyWith(
        selectedSourceId: territoryId,
        selectedTargetId: null,
        statusMessage: '${territory.name} transfer kaynağı seçildi.',
      );
    }

    if (!source.isNeighbor(territoryId)) {
      return state.copyWith(
        selectedTargetId: null,
        statusMessage: 'Sadece komşu dost bölgelere transfer yapılabilir.',
      );
    }

    if (!_engine.canTransfer(state, source.id, territory.id)) {
      return state.copyWith(
        selectedTargetId: null,
        statusMessage: 'Transfer için kaynak bölgede 1 askerden fazla olmalı.',
      );
    }

    return state.copyWith(
      selectedTargetId: territoryId,
      statusMessage: 'Transfer hazır.',
    );
  }

  bool _canTransferSelection(GameState state) {
    if (_commandMode != _MapCommandMode.transfer ||
        state.phase != GamePhase.attack ||
        state.selectedSourceId == null ||
        state.selectedTargetId == null) {
      return false;
    }

    final source = state.territoryByIdOrNull(state.selectedSourceId);
    final target = state.territoryByIdOrNull(state.selectedTargetId);
    if (source == null || target == null) {
      return false;
    }

    return _engine.canTransfer(state, source.id, target.id);
  }

  Set<String> _validSourceIdsFor(GameState state) {
    if (!_canLocalPlayerAct) {
      return const <String>{};
    }
    if (_commandMode != _MapCommandMode.transfer ||
        state.phase != GamePhase.attack ||
        state.transferUsedThisTurn) {
      return const <String>{};
    }

    return state
        .territoriesOwnedBy(state.currentPlayer.id)
        .where((territory) => territory.armyCount > 1)
        .map((territory) => territory.id)
        .toSet();
  }

  Set<String> _validTargetIdsFor(GameState state) {
    if (!_canLocalPlayerAct) {
      return const <String>{};
    }
    if (state.phase != GamePhase.attack ||
        (state.transferUsedThisTurn &&
            _commandMode == _MapCommandMode.transfer) ||
        state.selectedSourceId == null) {
      return const <String>{};
    }

    final source = state.territoryByIdOrNull(state.selectedSourceId);
    if (source == null || source.ownerId != state.currentPlayer.id) {
      return const <String>{};
    }

    final targets = <String>{};
    for (final neighborId in source.neighbors) {
      final territory = state.territoryByIdOrNull(neighborId);
      if (territory == null) {
        continue;
      }
      if (_commandMode == _MapCommandMode.transfer) {
        if (source.armyCount > 1 &&
            territory.ownerId == state.currentPlayer.id) {
          targets.add(territory.id);
        }
      } else if (source.armyCount > 1 &&
          territory.ownerId != state.currentPlayer.id) {
        targets.add(territory.id);
      }
    }
    return targets;
  }

  void _afterStateChanged() {
    if (!mounted) {
      return;
    }

    if (_state.winnerId != null) {
      _goToVictory();
      return;
    }

    if (_state.currentPlayer.isBot && !_isBotThinking && _canRunBotTurn) {
      _scheduleBotTurn();
    }
  }

  void _scheduleBotTurn() {
    _botTimer?.cancel();
    setState(() {
      _isBotThinking = true;
      _state = _state.copyWith(
        statusMessage: '${_state.currentPlayer.name} hamlesini planlıyor...',
      );
    });

    _botTimer = Timer(const Duration(milliseconds: 750), () {
      if (!mounted) {
        return;
      }
      final nextState = _engine.runBotTurn(_state, random: _random);
      _setGameState(nextState, isBotThinking: false);
    });
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();
    final secondsLeft = _secondsLeftFor(_state);
    if (mounted) {
      setState(() {
        _remainingTurnSeconds = secondsLeft;
      });
    } else {
      _remainingTurnSeconds = secondsLeft;
    }
    if (_state.winnerId != null || _state.currentPlayer.isBot) {
      return;
    }
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final secondsLeft = _secondsLeftFor(_state);
      if (secondsLeft <= 0) {
        _handleTurnTimeout();
        return;
      }
      setState(() {
        _remainingTurnSeconds = secondsLeft;
      });
    });
  }

  int _secondsLeftFor(GameState state) {
    final elapsedMillis =
        DateTime.now().millisecondsSinceEpoch - state.turnStartedAtMillis;
    final elapsedSeconds = elapsedMillis ~/ 1000;
    return (GameConstants.turnDurationSeconds - elapsedSeconds).clamp(
      0,
      GameConstants.turnDurationSeconds,
    );
  }

  void _handleTurnTimeout() {
    _turnTimer?.cancel();
    if (_state.currentPlayer.isBot) {
      return;
    }
    setState(() {
      _remainingTurnSeconds = 0;
    });
    if (!_canLocalPlayerAct) {
      return;
    }

    var nextState = _state;
    if (nextState.phase == GamePhase.reinforce &&
        nextState.remainingReinforcements > 0) {
      final target = nextState
          .territoriesOwnedBy(nextState.currentPlayer.id)
          .fold<Territory?>(null, (best, territory) {
            if (best == null || territory.armyCount > best.armyCount) {
              return territory;
            }
            return best;
          });
      if (target != null) {
        nextState = _engine.addReinforcementsToTerritory(nextState, target.id);
      }
    }

    _setGameState(
      _engine.endTurn(
        nextState.copyWith(
          phase: GamePhase.end,
          statusMessage: 'Tur süresi doldu.',
        ),
      ),
    );
  }

  Set<String> _controlledContinentsFor(GameState state) {
    return state.players
        .expand(
          (player) => _engine.reinforcementCalculator
              .controlledContinentBonuses(state, player.id)
              .map((bonus) => bonus.continent),
        )
        .toSet();
  }

  void _maybeAnnounceControlledContinents(GameState state) {
    final currentControlled = _controlledContinentsFor(state);
    final newlyControlled = currentControlled
        .difference(_announcedControlledContinents)
        .toList(growable: false);
    _announcedControlledContinents = currentControlled;
    if (newlyControlled.isEmpty || !mounted) {
      return;
    }

    final continent = newlyControlled.first;
    final owner = state.players.firstWhere(
      (player) => _engine.reinforcementCalculator
          .controlledContinentBonuses(state, player.id)
          .any((bonus) => bonus.continent == continent),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(owner.colorValue).withValues(alpha: 0.92),
        content: Text(
          '${owner.name} $continent kıtasını kontrol ediyor!',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  bool get _isOnline =>
      widget.onlineRepository != null && widget.localPlayerId != null;

  bool get _canLocalPlayerAct {
    if (_state.currentPlayer.isBot || _state.winnerId != null) {
      return false;
    }
    if (!_isOnline) {
      return true;
    }
    return _state.currentPlayer.id == widget.localPlayerId;
  }

  bool get _canRunBotTurn {
    if (!_isOnline) {
      return true;
    }
    return widget.localPlayerId == FirestoreGameRepository.hostPlayerId;
  }

  void _subscribeToOnlineGame() {
    if (!_isOnline) {
      return;
    }

    _onlineSubscription = widget.onlineRepository!
        .watchGameState(_state.id)
        .listen((remoteState) {
          if (!mounted || remoteState == null) {
            return;
          }
          setState(() {
            _state = remoteState;
            _isSavingOnline = false;
            _remainingTurnSeconds = _secondsLeftFor(_state);
            if (_state.phase != GamePhase.attack ||
                _state.currentPlayer.isBot) {
              _commandMode = _MapCommandMode.attack;
            }
          });
          _startTurnTimer();
          _maybeAnnounceControlledContinents(remoteState);
          _afterStateChanged();
        }, onError: _handleOnlineStreamError);
  }

  void _handleOnlineStreamError(Object error, StackTrace stackTrace) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isSavingOnline = false;
      _state = _state.copyWith(
        statusMessage:
            'Online oda senkronu koptu. Bağlantıyı kontrol et veya odaya tekrar katıl.',
      );
    });
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
    });
    await _saveLocalState(_state);
  }

  Future<void> _saveOnlineState(GameState nextState) async {
    if (!_isOnline) {
      return;
    }
    setState(() {
      _isSavingOnline = true;
    });
    try {
      await widget.onlineRepository!.saveGameState(nextState);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSavingOnline = false;
        _state = _state.copyWith(
          statusMessage: 'Online senkron başarısız. Bağlantıyı kontrol et.',
        );
      });
    }
  }

  Future<void> _saveLocalState(GameState nextState) async {
    if (_isOnline || !_settings.autoSaveLocalGame) {
      return;
    }
    if (nextState.winnerId != null) {
      await _localSaveRepository.clearSavedGame();
      return;
    }
    await _localSaveRepository.saveGameState(nextState);
  }

  void _goToVictory() {
    if (_navigatedToVictory) {
      return;
    }
    _navigatedToVictory = true;
    final winner = _state.playerById(_state.winnerId);
    if (winner == null) {
      return;
    }
    if (!_isOnline) {
      unawaited(_localSaveRepository.clearSavedGame());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => VictoryScreen(
            winner: winner,
            territoryCount: _state.ownedTerritoryCount(winner.id),
            totalTerritoryCount: _state.territories.length,
          ),
        ),
      );
    });
  }
}

class _AmountButton extends StatelessWidget {
  const _AmountButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC07131F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onPressed == null
                ? AppColors.premiumBorder.withValues(alpha: 0.35)
                : AppColors.premiumCyan.withValues(alpha: 0.70),
          ),
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon),
          color: onPressed == null
              ? AppColors.premiumMutedText.withValues(alpha: 0.55)
              : AppColors.premiumText,
          tooltip: icon == Icons.add ? 'Artır' : 'Azalt',
        ),
      ),
    );
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

class _WorldHeader extends StatelessWidget {
  const _WorldHeader({
    required this.state,
    required this.isOnline,
    required this.isLocalTurn,
    required this.gameId,
    required this.remainingTurnSeconds,
    required this.onMenuPressed,
    required this.onHelpPressed,
  });

  final GameState state;
  final bool isOnline;
  final bool isLocalTurn;
  final String gameId;
  final int remainingTurnSeconds;
  final VoidCallback onMenuPressed;
  final VoidCallback onHelpPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onMenuPressed,
            icon: const Icon(Icons.menu),
            color: AppColors.premiumText,
            tooltip: 'Menü',
            constraints: const BoxConstraints.tightFor(width: 38, height: 38),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            onPressed: onHelpPressed,
            icon: const Icon(Icons.help_outline),
            color: AppColors.premiumText,
            tooltip: 'Nasıl oynanır',
            constraints: const BoxConstraints.tightFor(width: 34, height: 38),
            padding: EdgeInsets.zero,
          ),
          const Expanded(
            child: Text(
              'BORDER WARS LITE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.premiumText,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'TUR ${state.turnNumber}',
                style: const TextStyle(
                  color: AppColors.premiumMutedText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _timerLabel,
                style: TextStyle(
                  color: remainingTurnSeconds <= 10
                      ? AppColors.premiumRed
                      : isLocalTurn
                      ? const Color(0xFF91F05B)
                      : AppColors.premiumCyan,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          Icon(
            isOnline ? Icons.cloud_done : Icons.hourglass_empty,
            color: AppColors.premiumText,
            size: 18,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  String get _timerLabel {
    final minutes = remainingTurnSeconds ~/ 60;
    final seconds = remainingTurnSeconds % 60;
    final time =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    if (isOnline && !isLocalTurn) {
      return '$time | $gameId';
    }
    return time;
  }
}

class _PlayerStrip extends StatelessWidget {
  const _PlayerStrip({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return PremiumPanel(
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 52,
        child: LayoutBuilder(
          builder: (context, constraints) {
            const horizontalPadding = 6.0;
            const gap = 5.0;
            final count = state.players.length;
            final cardWidth =
                (constraints.maxWidth -
                    horizontalPadding * 2 -
                    gap * (count - 1)) /
                count;
            final playableCardWidth = cardWidth.clamp(76.0, 118.0);
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 5,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    for (var index = 0; index < count; index++) ...<Widget>[
                      SizedBox(
                        width: playableCardWidth,
                        child: _PlayerCard(
                          player: state.players[index],
                          isCurrent:
                              state.players[index].id == state.currentPlayer.id,
                          territoryCount: state.ownedTerritoryCount(
                            state.players[index].id,
                          ),
                          compact: playableCardWidth < 92,
                        ),
                      ),
                      if (index != count - 1) const SizedBox(width: gap),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.player,
    required this.isCurrent,
    required this.territoryCount,
    required this.compact,
  });

  final Player player;
  final bool isCurrent;
  final int territoryCount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Color(player.colorValue);
    final isEliminated = territoryCount == 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 7, vertical: 4),
      decoration: BoxDecoration(
        color: isEliminated
            ? const Color(0x55111B25)
            : isCurrent
            ? color.withValues(alpha: 0.20)
            : const Color(0x66111B25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEliminated
              ? AppColors.premiumBorder.withValues(alpha: 0.25)
              : isCurrent
              ? color.withValues(alpha: 0.95)
              : AppColors.premiumBorder.withValues(alpha: 0.46),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: compact ? 10 : 12,
                height: compact ? 10 : 12,
                decoration: BoxDecoration(
                  color: isEliminated ? color.withValues(alpha: 0.35) : color,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    if (!isEliminated)
                      BoxShadow(
                        color: color.withValues(alpha: 0.55),
                        blurRadius: 8,
                      ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 4 : 5),
              Expanded(
                child: Text(
                  compact ? _compactName(player.name) : player.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.premiumText,
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  isEliminated ? 'OUT' : '$territoryCount',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFD27A),
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (!isEliminated) ...const <Widget>[
                SizedBox(width: 3),
                Icon(Icons.star, color: Color(0xFFFFD27A), size: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _compactName(String name) {
    if (name == 'Commander') {
      return 'Sen';
    }
    return name.replaceAll(' Bot', '');
  }
}

class _MapStage extends StatelessWidget {
  const _MapStage({
    required this.state,
    required this.validSourceIds,
    required this.validTargetIds,
    required this.controlledContinents,
    required this.onTerritoryTap,
  });

  final GameState state;
  final Set<String> validSourceIds;
  final Set<String> validTargetIds;
  final Set<String> controlledContinents;
  final ValueChanged<String> onTerritoryTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.premiumBorder),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.premiumCyan.withValues(alpha: 0.16),
                  blurRadius: 18,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TerritoryMap(
                state: state,
                validSourceIds: validSourceIds,
                validTargetIds: validTargetIds,
                controlledContinents: controlledContinents,
                onTerritoryTap: onTerritoryTap,
              ),
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 14,
          child: Column(
            children: const <Widget>[
              _MapToolButton(icon: Icons.my_location, tooltip: 'Odakla'),
              SizedBox(height: 8),
              _MapToolButton(icon: Icons.search, tooltip: 'Ara'),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapToolButton extends StatelessWidget {
  const _MapToolButton({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xB807131F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.premiumBorder.withValues(alpha: 0.70),
          ),
        ),
        child: Icon(icon, color: AppColors.premiumText, size: 23),
      ),
    );
  }
}

class _ReinforcePhasePanel extends StatelessWidget {
  const _ReinforcePhasePanel({
    required this.state,
    required this.reinforcementBreakdown,
    required this.isBotThinking,
    required this.isOnline,
    required this.isSavingOnline,
    required this.canAct,
  });

  final GameState state;
  final ReinforcementBreakdown reinforcementBreakdown;
  final bool isBotThinking;
  final bool isOnline;
  final bool isSavingOnline;
  final bool canAct;

  @override
  Widget build(BuildContext context) {
    final controlled = reinforcementBreakdown.controlledContinents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.premiumBlue.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.premiumBlue.withValues(alpha: 0.80),
                ),
              ),
              child: const Icon(
                Icons.shield,
                color: AppColors.premiumText,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'TAKVİYE AŞAMASI',
                    style: TextStyle(
                      color: Color(0xFF55B9FF),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Asker eklemek için kendi bölgelerinden birini seç.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.premiumMutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                const Text(
                  'TOPLAM',
                  style: TextStyle(
                    color: Color(0xFFFFD66D),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${reinforcementBreakdown.total}',
                  style: const TextStyle(
                    color: Color(0xFF91F05B),
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            _InfoPill(label: 'Temel ${reinforcementBreakdown.base}'),
            _InfoPill(label: 'Bonus ${reinforcementBreakdown.continentBonus}'),
            if (controlled.isEmpty)
              const _InfoPill(label: 'Kontrollü kıta yok')
            else
              for (final bonus in controlled)
                _InfoPill(label: '${bonus.continent} +${bonus.value}'),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          isBotThinking
              ? 'Bot sırası oynanıyor...'
              : isSavingOnline
              ? 'Online oyun eşitleniyor...'
              : isOnline && !canAct
              ? '${state.currentPlayer.name} bekleniyor...'
              : state.statusMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.premiumMutedText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xAA081521),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: AppColors.premiumBorder.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFFFD66D),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BattleCommandPanel extends StatelessWidget {
  const _BattleCommandPanel({
    required this.state,
    required this.commandMode,
    required this.canAttack,
    required this.canTransfer,
    required this.winChance,
    required this.reinforcementBreakdown,
    required this.isBotThinking,
    required this.isOnline,
    required this.isSavingOnline,
    required this.canAct,
    required this.onAttack,
    required this.onSelectAttackMode,
    required this.onSelectTransferMode,
    required this.onTransfer,
    required this.onEndTurn,
  });

  final GameState state;
  final _MapCommandMode commandMode;
  final bool canAttack;
  final bool canTransfer;
  final double winChance;
  final ReinforcementBreakdown reinforcementBreakdown;
  final bool isBotThinking;
  final bool isOnline;
  final bool isSavingOnline;
  final bool canAct;
  final VoidCallback onAttack;
  final VoidCallback onSelectAttackMode;
  final VoidCallback onSelectTransferMode;
  final VoidCallback onTransfer;
  final VoidCallback onEndTurn;

  @override
  Widget build(BuildContext context) {
    final source = state.territoryByIdOrNull(state.selectedSourceId);
    final target = state.territoryByIdOrNull(state.selectedTargetId);
    final percent = (winChance * 100).round();
    final canEndTurn = canAct && state.winnerId == null;
    final isTransferMode = commandMode == _MapCommandMode.transfer;
    final canUseCommands = state.phase == GamePhase.attack && canAct;
    final canUseTransfer = canUseCommands && !state.transferUsedThisTurn;
    final isReinforcePhase = state.phase == GamePhase.reinforce;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PremiumPanel(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: isReinforcePhase
              ? _ReinforcePhasePanel(
                  state: state,
                  reinforcementBreakdown: reinforcementBreakdown,
                  isBotThinking: isBotThinking,
                  isOnline: isOnline,
                  isSavingOnline: isSavingOnline,
                  canAct: canAct,
                )
              : Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _TerritoryReadout(
                            label: 'KAYNAK',
                            labelColor: const Color(0xFF55B9FF),
                            territory: source,
                            state: state,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward,
                          color: AppColors.premiumText,
                          size: 32,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _TerritoryReadout(
                            label: 'HEDEF',
                            labelColor: AppColors.premiumRed,
                            territory: target,
                            state: state,
                          ),
                        ),
                        const SizedBox(width: 10),
                        _WinChance(
                          percent: percent,
                          enabled: canAttack,
                          isReinforcePhase: false,
                          isTransferMode: isTransferMode,
                          canTransfer: canTransfer,
                          transferUsed: state.transferUsedThisTurn,
                          reinforcementTotal: reinforcementBreakdown.total,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isBotThinking
                          ? 'Bot sırası oynanıyor...'
                          : isSavingOnline
                          ? 'Online oyun eşitleniyor...'
                          : isOnline && !canAct
                          ? '${state.currentPlayer.name} bekleniyor...'
                          : state.statusMessage,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.premiumMutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: PremiumButton(
                label: 'TAKVİYE',
                icon: Icons.shield,
                onPressed: null,
                tone: isReinforcePhase
                    ? PremiumButtonTone.blue
                    : PremiumButtonTone.dark,
                height: 46,
                isSelected: isReinforcePhase,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: PremiumButton(
                label: 'SALDIR',
                icon: Icons.sports_martial_arts,
                onPressed: !canUseCommands
                    ? null
                    : isTransferMode
                    ? onSelectAttackMode
                    : (canAttack ? onAttack : null),
                tone: !isReinforcePhase && !isTransferMode
                    ? PremiumButtonTone.red
                    : PremiumButtonTone.dark,
                height: 46,
                isSelected: !isReinforcePhase && !isTransferMode,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: PremiumButton(
                label: state.transferUsedThisTurn
                    ? 'TRANSFER YAPILDI'
                    : 'TRANSFER',
                icon: Icons.swap_horiz,
                onPressed: !canUseTransfer
                    ? null
                    : isTransferMode
                    ? (canTransfer ? onTransfer : null)
                    : onSelectTransferMode,
                tone: isTransferMode
                    ? PremiumButtonTone.teal
                    : PremiumButtonTone.dark,
                height: 46,
                isSelected: isTransferMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PremiumButton(
          label: 'TURU BİTİR',
          icon: Icons.hourglass_bottom,
          onPressed: canEndTurn ? onEndTurn : null,
          tone: PremiumButtonTone.gold,
          height: 58,
        ),
      ],
    );
  }
}

class _TerritoryReadout extends StatelessWidget {
  const _TerritoryReadout({
    required this.label,
    required this.labelColor,
    required this.territory,
    required this.state,
  });

  final String label;
  final Color labelColor;
  final Territory? territory;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final owner = state.playerById(territory?.ownerId);
    final ownerColor = owner == null
        ? AppColors.neutral
        : Color(owner.colorValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          territory?.name ?? 'Yok',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.premiumText,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: <Widget>[
            Icon(Icons.shield, color: ownerColor, size: 16),
            const SizedBox(width: 5),
            Text(
              territory?.armyCount.toString() ?? '-',
              style: const TextStyle(
                color: AppColors.premiumText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WinChance extends StatelessWidget {
  const _WinChance({
    required this.percent,
    required this.enabled,
    required this.isReinforcePhase,
    required this.isTransferMode,
    required this.canTransfer,
    required this.transferUsed,
    required this.reinforcementTotal,
  });

  final int percent;
  final bool enabled;
  final bool isReinforcePhase;
  final bool isTransferMode;
  final bool canTransfer;
  final bool transferUsed;
  final int reinforcementTotal;

  @override
  Widget build(BuildContext context) {
    final isReady =
        isReinforcePhase ||
        (isTransferMode ? canTransfer || transferUsed : enabled);
    final color = isReady
        ? const Color(0xFF91F05B)
        : AppColors.premiumMutedText;
    final label = isReinforcePhase
        ? 'TAKVİYE'
        : isTransferMode
        ? 'TRANSFER'
        : 'ŞANS';
    final value = isReinforcePhase
        ? '$reinforcementTotal'
        : isTransferMode
        ? transferUsed
              ? 'BİTTİ'
              : (canTransfer ? 'OK' : '--')
        : enabled
        ? '$percent%'
        : '--';
    final subtitle = isReinforcePhase
        ? 'Total'
        : isTransferMode
        ? transferUsed
              ? 'Kullanıldı'
              : (canTransfer ? 'Hazır' : 'Dost seç')
        : (enabled ? 'Hedef hazır' : 'Hedef seç');
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFD66D),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isTransferMode ? 24 : 28,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          Text(
            subtitle,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
