import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/game_constants.dart';
import '../../game/engine/map_generator.dart';
import '../../game/models/game_state.dart';
import '../../game/models/player.dart';
import 'firestore_chat_repository.dart';
import 'firebase_service.dart';

class OnlineGameSession {
  const OnlineGameSession({
    required this.gameId,
    required this.localPlayerId,
    required this.state,
    required this.status,
    required this.isHost,
    required this.maxHumanPlayers,
  });

  final String gameId;
  final String localPlayerId;
  final GameState state;
  final String status;
  final bool isHost;
  final int maxHumanPlayers;

  bool get isActive => status == FirestoreGameRepository.statusActive;
  bool get isWaiting => status == FirestoreGameRepository.statusWaiting;
  List<Player> get humanPlayers =>
      state.players.where((player) => !player.isBot).toList(growable: false);
}

class FirestoreGameRepository {
  FirestoreGameRepository({FirebaseFirestore? firestore})
    : _firestore = firestore;

  static const statusWaiting = 'waiting';
  static const statusActive = 'active';
  static const statusFinished = 'finished';
  static const hostPlayerId = GameConstants.humanPlayerId;

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
        isHost: data['hostUid'] == FirebaseService.auth.currentUser?.uid,
        maxHumanPlayers: _maxHumanPlayersFromData(data),
      );
    });
  }

  Future<OnlineGameSession> createOnlineGame({
    required String hostPlayerName,
    required int hostColorValue,
    int botCount = 2,
    int maxHumanPlayers = GameConstants.maxOnlineHumanPlayers,
  }) async {
    final uid = await FirebaseService.ensureSignedInAnonymously();
    final gameId = _newGameCode();
    final doc = _games.doc(gameId);
    final boundedMaxHumanPlayers = _boundedMaxHumanPlayers(maxHumanPlayers);

    final host = _OnlineRoomParticipant(
      uid: uid,
      playerId: hostPlayerId,
      name: _cleanName(hostPlayerName),
      colorValue: hostColorValue,
    );
    final participants = <_OnlineRoomParticipant>[host];
    final boundedBotCount = _boundedOnlineBotCount(botCount, participants);
    final waitingState = _stateForRoom(
      gameId: gameId,
      participants: participants,
      botCount: boundedBotCount,
    );

    await doc.set(<String, dynamic>{
      'gameId': gameId,
      'status': statusWaiting,
      'hostPlayerId': hostPlayerId,
      'hostUid': uid,
      'participantUids': <String>[uid],
      'participants': participants
          .map((participant) => participant.toMap())
          .toList(growable: false),
      'maxHumanPlayers': boundedMaxHumanPlayers,
      'hostName': host.name,
      'hostColorValue': host.colorValue,
      'botCount': boundedBotCount,
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
      isHost: true,
      maxHumanPlayers: boundedMaxHumanPlayers,
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
    late final OnlineGameSession session;

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('Game not found.');
      }
      if ((data['status'] as String? ?? statusWaiting) != statusWaiting) {
        throw StateError('This game has already started.');
      }

      final hostUid = data['hostUid'] as String?;
      if (hostUid == null || hostUid.isEmpty) {
        throw StateError('This online game was created by an older build.');
      }
      if (hostUid == uid) {
        throw StateError('Use another device to join your own room.');
      }

      final participants = _participantsFromData(data);
      if (participants.any((participant) => participant.uid == uid)) {
        throw StateError('You are already in this room.');
      }
      final maxHumanPlayers = _maxHumanPlayersFromData(data);
      if (participants.length >= maxHumanPlayers) {
        throw StateError('This room is full.');
      }

      final botCount = data['botCount'] as int? ?? 2;
      final colorValue = _distinctHumanColor(
        playerColorValue,
        participants.map((participant) => participant.colorValue).toSet(),
      );
      final participant = _OnlineRoomParticipant(
        uid: uid,
        playerId: _playerIdForUid(uid),
        name: _cleanName(playerName),
        colorValue: colorValue,
      );
      final updatedParticipants = <_OnlineRoomParticipant>[
        ...participants,
        participant,
      ];
      final boundedBotCount = _boundedOnlineBotCount(
        botCount,
        updatedParticipants,
      );
      final waitingState = _stateForRoom(
        gameId: normalizedGameId,
        participants: updatedParticipants,
        botCount: boundedBotCount,
      );

      transaction.set(doc, <String, dynamic>{
        'gameId': normalizedGameId,
        'status': statusWaiting,
        'participantUids': updatedParticipants
            .map((participant) => participant.uid)
            .toList(growable: false),
        'participants': updatedParticipants
            .map((participant) => participant.toMap())
            .toList(growable: false),
        'botCount': boundedBotCount,
        'state': _stateToFirestoreMap(waitingState),
        'updatedByUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      session = OnlineGameSession(
        gameId: normalizedGameId,
        localPlayerId: participant.playerId,
        state: waitingState,
        status: statusWaiting,
        isHost: false,
        maxHumanPlayers: maxHumanPlayers,
      );
    });

    return session;
  }

  Future<OnlineGameSession> startOnlineGame(String gameId) async {
    final uid = await FirebaseService.ensureSignedInAnonymously();
    final normalizedGameId = _normalizeGameId(gameId);
    final doc = _games.doc(normalizedGameId);
    late final OnlineGameSession session;

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('Game not found.');
      }
      if (data['hostUid'] != uid) {
        throw StateError('Only the host can start this room.');
      }
      if ((data['status'] as String? ?? statusWaiting) != statusWaiting) {
        throw StateError('This game has already started.');
      }

      final participants = _participantsFromData(data);
      if (participants.length < 2) {
        throw StateError('At least 2 human players are required.');
      }

      final botCount = data['botCount'] as int? ?? 2;
      final activeState = _stateForRoom(
        gameId: normalizedGameId,
        participants: participants,
        botCount: _boundedOnlineBotCount(botCount, participants),
      );

      transaction.set(doc, <String, dynamic>{
        'gameId': normalizedGameId,
        'status': statusActive,
        'state': _stateToFirestoreMap(activeState),
        'updatedByUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      session = OnlineGameSession(
        gameId: normalizedGameId,
        localPlayerId: hostPlayerId,
        state: activeState,
        status: statusActive,
        isHost: true,
        maxHumanPlayers: _maxHumanPlayersFromData(data),
      );
    });

    unawaited(
      FirestoreChatRepository(
        firestore: _firestore,
      )
          .sendSystemMessage(gameId: normalizedGameId, text: 'Oyun başladı.')
          .catchError((Object _) {}),
    );

    return session;
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

  GameState _stateForRoom({
    required String gameId,
    required List<_OnlineRoomParticipant> participants,
    required int botCount,
  }) {
    final reservedColors = participants
        .map((participant) => participant.colorValue)
        .toSet();
    final players = <Player>[
      ...participants.map(
        (participant) => Player(
          id: participant.playerId,
          name: participant.name,
          colorValue: participant.colorValue,
          isBot: false,
        ),
      ),
      ..._mapGenerator.createBotPlayers(
        count: botCount,
        startIndex: 0,
        reservedColorValues: reservedColors,
      ),
    ];

    return _mapGenerator.createInitialStateForPlayers(
      players: players,
      gameId: gameId,
      firstPlayerId: hostPlayerId,
    );
  }

  int _boundedOnlineBotCount(
    int botCount,
    List<_OnlineRoomParticipant> participants,
  ) {
    final maxPlayersSupported =
        GameConstants.totalTerritories ~/
        GameConstants.startingTerritoriesPerPlayer;
    final maxBotsForMap = max(0, maxPlayersSupported - participants.length);
    return botCount.clamp(0, min(GameConstants.maxBotPlayers, maxBotsForMap));
  }

  int _boundedMaxHumanPlayers(int maxHumanPlayers) {
    return maxHumanPlayers
        .clamp(2, GameConstants.maxOnlineHumanPlayers)
        .toInt();
  }

  int _maxHumanPlayersFromData(Map<String, dynamic> data) {
    return _boundedMaxHumanPlayers(
      data['maxHumanPlayers'] as int? ?? GameConstants.maxOnlineHumanPlayers,
    );
  }

  List<_OnlineRoomParticipant> _participantsFromData(
    Map<String, dynamic> data,
  ) {
    final rawParticipants = data['participants'];
    if (rawParticipants is List && rawParticipants.isNotEmpty) {
      return rawParticipants
          .whereType<Map>()
          .map(
            (participant) => _OnlineRoomParticipant.fromMap(
              Map<String, dynamic>.from(participant),
            ),
          )
          .toList(growable: false);
    }

    final hostUid = data['hostUid'] as String?;
    if (hostUid == null || hostUid.isEmpty) {
      return const <_OnlineRoomParticipant>[];
    }
    return <_OnlineRoomParticipant>[
      _OnlineRoomParticipant(
        uid: hostUid,
        playerId: hostPlayerId,
        name: _cleanName(data['hostName'] as String?),
        colorValue: data['hostColorValue'] as int? ?? AppColors.humanBlueValue,
      ),
    ];
  }

  int _distinctHumanColor(int preferredColor, Set<int> usedColors) {
    if (!usedColors.contains(preferredColor)) {
      return preferredColor;
    }
    for (final colorValue in AppColors.humanColorValues) {
      if (!usedColors.contains(colorValue)) {
        return colorValue;
      }
    }
    return preferredColor;
  }

  String _playerIdForUid(String uid) {
    final cleanUid = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final suffix = cleanUid.length > 10 ? cleanUid.substring(0, 10) : cleanUid;
    return 'player_$suffix';
  }
}

class _OnlineRoomParticipant {
  const _OnlineRoomParticipant({
    required this.uid,
    required this.playerId,
    required this.name,
    required this.colorValue,
  });

  final String uid;
  final String playerId;
  final String name;
  final int colorValue;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'playerId': playerId,
      'name': name,
      'colorValue': colorValue,
    };
  }

  factory _OnlineRoomParticipant.fromMap(Map<String, dynamic> map) {
    return _OnlineRoomParticipant(
      uid: map['uid'] as String? ?? '',
      playerId: map['playerId'] as String? ?? '',
      name: map['name'] as String? ?? GameConstants.defaultHumanName,
      colorValue: map['colorValue'] as int? ?? AppColors.humanBlueValue,
    );
  }
}
