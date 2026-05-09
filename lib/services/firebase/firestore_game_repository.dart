import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../game/engine/map_generator.dart';
import '../../game/models/bot_personality.dart';
import '../../game/models/game_state.dart';
import '../../game/models/player.dart';
import 'firebase_service.dart';

class OnlineGameSession {
  const OnlineGameSession({
    required this.gameId,
    required this.localPlayerId,
    required this.state,
    required this.status,
  });

  final String gameId;
  final String localPlayerId;
  final GameState state;
  final String status;

  bool get isActive => status == FirestoreGameRepository.statusActive;
}

class FirestoreGameRepository {
  FirestoreGameRepository({FirebaseFirestore? firestore})
    : _firestore = firestore;

  static const statusWaiting = 'waiting';
  static const statusActive = 'active';
  static const statusFinished = 'finished';
  static const hostPlayerId = GameConstants.humanPlayerId;
  static const guestPlayerId = 'atlas_bot';

  final FirebaseFirestore? _firestore;
  final MapGenerator _mapGenerator = const MapGenerator();
  final Random _random = Random();

  FirebaseFirestore get _db => _firestore ?? FirebaseService.firestore;

  CollectionReference<Map<String, dynamic>> get _games =>
      _db.collection('games');

  Future<void> saveGameState(GameState state) async {
    await _games.doc(state.id).set(<String, dynamic>{
      'gameId': state.id,
      'status': state.winnerId == null ? statusActive : statusFinished,
      'state': state.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<GameState?> loadGameState(String gameId) async {
    final snapshot = await _games.doc(_normalizeGameId(gameId)).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }
    return _stateFromDocument(data);
  }

  Stream<GameState?> watchGameState(String gameId) {
    return _games
        .doc(_normalizeGameId(gameId))
        .snapshots()
        .map((snapshot) => _stateFromDocument(snapshot.data()));
  }

  Stream<OnlineGameSession?> watchOnlineGame({
    required String gameId,
    required String localPlayerId,
  }) {
    return _games.doc(_normalizeGameId(gameId)).snapshots().map((snapshot) {
      final data = snapshot.data();
      final state = _stateFromDocument(data);
      if (data == null || state == null) {
        return null;
      }
      return OnlineGameSession(
        gameId: state.id,
        localPlayerId: localPlayerId,
        state: state,
        status: data['status'] as String? ?? statusWaiting,
      );
    });
  }

  Future<OnlineGameSession> createOnlineGame({
    required String hostPlayerName,
    required int hostColorValue,
  }) async {
    for (var attempt = 0; attempt < 10; attempt += 1) {
      final gameId = _newGameCode();
      final doc = _games.doc(gameId);
      final existing = await doc.get();
      if (existing.exists) {
        continue;
      }

      final hostName = _cleanName(hostPlayerName);
      final waitingState = _mapGenerator.createInitialStateForPlayers(
        players: <Player>[
          Player(
            id: hostPlayerId,
            name: hostName,
            colorValue: hostColorValue,
            isBot: false,
          ),
          const Player(
            id: guestPlayerId,
            name: 'Waiting...',
            colorValue: AppColors.atlasBotValue,
            isBot: true,
            botPersonality: BotPersonality.aggressive,
          ),
          const Player(
            id: 'nova_bot',
            name: 'Nova Bot',
            colorValue: AppColors.novaBotValue,
            isBot: true,
            botPersonality: BotPersonality.opportunistic,
          ),
          const Player(
            id: 'terra_bot',
            name: 'Terra Bot',
            colorValue: AppColors.terraBotValue,
            isBot: true,
            botPersonality: BotPersonality.defensive,
          ),
        ],
        gameId: gameId,
        firstPlayerId: hostPlayerId,
      );

      await doc.set(<String, dynamic>{
        'gameId': gameId,
        'status': statusWaiting,
        'hostPlayerId': hostPlayerId,
        'guestPlayerId': guestPlayerId,
        'hostName': hostName,
        'hostColorValue': hostColorValue,
        'state': waitingState.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return OnlineGameSession(
        gameId: gameId,
        localPlayerId: hostPlayerId,
        state: waitingState,
        status: statusWaiting,
      );
    }

    throw StateError('Could not create a unique online game code.');
  }

  Future<OnlineGameSession> joinOnlineGame({
    required String gameId,
    required String playerName,
    required int playerColorValue,
  }) async {
    final normalizedGameId = _normalizeGameId(gameId);
    final doc = _games.doc(normalizedGameId);
    final snapshot = await doc.get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw StateError('Game not found.');
    }
    if ((data['status'] as String? ?? statusWaiting) != statusWaiting) {
      throw StateError('This game has already started.');
    }

    final hostName = _cleanName(data['hostName'] as String?);
    final hostColorValue =
        data['hostColorValue'] as int? ?? AppColors.humanBlueValue;
    final guestColorValue = playerColorValue == hostColorValue
        ? AppColors.atlasBotValue
        : playerColorValue;
    final guestName = _cleanName(playerName);

    final activeState = _mapGenerator.createInitialStateForPlayers(
      players: <Player>[
        Player(
          id: hostPlayerId,
          name: hostName,
          colorValue: hostColorValue,
          isBot: false,
        ),
        Player(
          id: guestPlayerId,
          name: guestName,
          colorValue: guestColorValue,
          isBot: false,
        ),
        const Player(
          id: 'nova_bot',
          name: 'Nova Bot',
          colorValue: AppColors.novaBotValue,
          isBot: true,
          botPersonality: BotPersonality.opportunistic,
        ),
        const Player(
          id: 'terra_bot',
          name: 'Terra Bot',
          colorValue: AppColors.terraBotValue,
          isBot: true,
          botPersonality: BotPersonality.defensive,
        ),
      ],
      gameId: normalizedGameId,
      firstPlayerId: hostPlayerId,
    );

    await doc.set(<String, dynamic>{
      'gameId': normalizedGameId,
      'status': statusActive,
      'guestName': guestName,
      'guestColorValue': guestColorValue,
      'state': activeState.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return OnlineGameSession(
      gameId: normalizedGameId,
      localPlayerId: guestPlayerId,
      state: activeState,
      status: statusActive,
    );
  }

  GameState? _stateFromDocument(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }
    final stateMap = data['state'];
    if (stateMap is Map) {
      return GameState.fromMap(Map<String, dynamic>.from(stateMap));
    }
    if (data.containsKey('players') && data.containsKey('territories')) {
      return GameState.fromMap(data);
    }
    return null;
  }

  String _newGameCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  String _normalizeGameId(String gameId) {
    return gameId.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String _cleanName(String? name) {
    final clean = name?.trim();
    if (clean == null || clean.isEmpty) {
      return GameConstants.defaultHumanName;
    }
    return clean.length > 18 ? clean.substring(0, 18) : clean;
  }
}
