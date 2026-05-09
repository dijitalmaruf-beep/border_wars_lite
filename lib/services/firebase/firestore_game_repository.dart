import 'dart:convert';
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
    final uid = await FirebaseService.ensureSignedInAnonymously();
    await _games.doc(state.id).set(<String, dynamic>{
      'gameId': state.id,
      'status': state.winnerId == null ? statusActive : statusFinished,
      'state': _stateToFirestoreMap(state),
      'updatedByUid': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<GameState?> loadGameState(String gameId) async {
    await FirebaseService.ensureSignedInAnonymously();
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
    int botCount = 2,
  }) async {
    final uid = await FirebaseService.ensureSignedInAnonymously();
    final gameId = _newGameCode();
    final doc = _games.doc(gameId);

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
        ..._mapGenerator.createBotPlayers(
          count: botCount,
          startIndex: 1,
          reservedColorValues: <int>{hostColorValue, AppColors.atlasBotValue},
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
      'hostUid': uid,
      'guestUid': null,
      'participantUids': <String>[uid],
      'hostName': hostName,
      'hostColorValue': hostColorValue,
      'botCount': botCount,
      'state': _stateToFirestoreMap(waitingState),
      'updatedByUid': uid,
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

  Future<OnlineGameSession> joinOnlineGame({
    required String gameId,
    required String playerName,
    required int playerColorValue,
  }) async {
    final uid = await FirebaseService.ensureSignedInAnonymously();
    final normalizedGameId = _normalizeGameId(gameId);
    final doc = _games.doc(normalizedGameId);
    late final GameState activeState;

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('Game not found.');
      }
      if ((data['status'] as String? ?? statusWaiting) != statusWaiting ||
          data['guestUid'] != null) {
        throw StateError('This game has already started.');
      }

      final hostUid = data['hostUid'] as String?;
      if (hostUid == null || hostUid.isEmpty) {
        throw StateError('This online game was created by an older build.');
      }
      if (hostUid == uid) {
        throw StateError('Use another device to join your own room.');
      }

      final hostName = _cleanName(data['hostName'] as String?);
      final hostColorValue =
          data['hostColorValue'] as int? ?? AppColors.humanBlueValue;
      final guestColorValue = playerColorValue == hostColorValue
          ? AppColors.atlasBotValue
          : playerColorValue;
      final guestName = _cleanName(playerName);
      final botCount = data['botCount'] as int? ?? 2;

      activeState = _mapGenerator.createInitialStateForPlayers(
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
          ..._mapGenerator.createBotPlayers(
            count: botCount,
            startIndex: 1,
            reservedColorValues: <int>{hostColorValue, guestColorValue},
          ),
        ],
        gameId: normalizedGameId,
        firstPlayerId: hostPlayerId,
      );

      transaction.set(doc, <String, dynamic>{
        'gameId': normalizedGameId,
        'status': statusActive,
        'guestUid': uid,
        'participantUids': <String>[hostUid, uid],
        'guestName': guestName,
        'guestColorValue': guestColorValue,
        'state': _stateToFirestoreMap(activeState),
        'updatedByUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

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
      return GameState.fromMap(
        _stateFromFirestoreMap(Map<String, dynamic>.from(stateMap)),
      );
    }
    if (data.containsKey('players') && data.containsKey('territories')) {
      return GameState.fromMap(_stateFromFirestoreMap(data));
    }
    return null;
  }

  Map<String, dynamic> _stateToFirestoreMap(GameState state) {
    final map = state.toMap();
    map['territories'] = state.territories.map((territory) {
      final territoryMap = territory.toMap();
      territoryMap['boundaryGroups'] = jsonEncode(
        territoryMap['boundaryGroups'],
      );
      return territoryMap;
    }).toList();
    return map;
  }

  Map<String, dynamic> _stateFromFirestoreMap(Map<String, dynamic> map) {
    final territories = map['territories'];
    if (territories is! List) {
      return map;
    }

    return <String, dynamic>{
      ...map,
      'territories': territories.map((territory) {
        final territoryMap = Map<String, dynamic>.from(territory as Map);
        final boundaryGroups = territoryMap['boundaryGroups'];
        if (boundaryGroups is String) {
          territoryMap['boundaryGroups'] = jsonDecode(boundaryGroups);
        }
        return territoryMap;
      }).toList(),
    };
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
