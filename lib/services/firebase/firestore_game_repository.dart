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

class OnlinePlayerPresence {
  const OnlinePlayerPresence({
    required this.playerId,
    required this.uid,
    required this.isOnline,
    this.lastSeenAt,
  });

  static const staleAfter = Duration(seconds: 75);

  final String playerId;
  final String uid;
  final bool isOnline;
  final DateTime? lastSeenAt;

  bool get hasKnownStatus => lastSeenAt != null;

  bool isConnected({DateTime? now}) {
    if (!isOnline) {
      return false;
    }
    final seenAt = lastSeenAt;
    if (seenAt == null) {
      return true;
    }
    return (now ?? DateTime.now()).difference(seenAt) <= staleAfter;
  }
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

  CollectionReference<Map<String, dynamic>> _presence(String gameId) {
    return _games.doc(_normalizeGameId(gameId)).collection('presence');
  }

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

  Stream<Map<String, OnlinePlayerPresence>> watchPlayerPresence(String gameId) {
    return _presence(gameId).snapshots().map((snapshot) {
      return <String, OnlinePlayerPresence>{
        for (final doc in snapshot.docs)
          doc.id: _presenceFromDoc(doc.id, doc.data()),
      };
    });
  }

  Future<void> markPlayerPresence({
    required String gameId,
    required String playerId,
    required bool isOnline,
  }) async {
    final uid = await FirebaseService.ensureSignedInAnonymously();
    await _presence(gameId).doc(playerId).set(<String, dynamic>{
      'playerId': playerId,
      'uid': uid,
      'isOnline': isOnline,
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    GameDifficulty difficulty = GameDifficulty.normal,
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
      difficulty: difficulty,
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
      'difficulty': difficulty.name,
      'state': _stateToFirestoreMap(waitingState),
      'updatedByUid': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await markPlayerPresence(
      gameId: gameId,
      playerId: hostPlayerId,
      isOnline: true,
    );

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
    String? systemMessage;

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('Game not found.');
      }

      final hostUid = data['hostUid'] as String?;
      if (hostUid == null || hostUid.isEmpty) {
        throw StateError('This online game was created by an older build.');
      }

      final participants = _participantsFromData(data);
      final existingParticipant = _participantForUid(participants, uid);
      final status = data['status'] as String? ?? statusWaiting;
      final maxHumanPlayers = _maxHumanPlayersFromData(data);

      if (existingParticipant != null) {
        final state =
            _stateFromDocument(data) ??
            _stateForRoom(
              gameId: normalizedGameId,
              participants: participants,
              botCount: _boundedOnlineBotCount(
                _botCountFromData(data),
                participants,
              ),
              difficulty: _difficultyFromData(data),
            );
        session = OnlineGameSession(
          gameId: normalizedGameId,
          localPlayerId: existingParticipant.playerId,
          state: state,
          status: status,
          isHost: hostUid == uid,
          maxHumanPlayers: maxHumanPlayers,
        );
        systemMessage = '${existingParticipant.name} oyuna geri döndü.';
        return;
      }

      if (status != statusWaiting) {
        throw StateError('This game has already started.');
      }
      if (participants.length >= maxHumanPlayers) {
        throw StateError('This room is full.');
      }

      final botCount = _botCountFromData(data);
      final difficulty = _difficultyFromData(data);
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
        difficulty: difficulty,
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
      systemMessage = '${participant.name} oyuna katıldı.';
    });

    await markPlayerPresence(
      gameId: normalizedGameId,
      playerId: session.localPlayerId,
      isOnline: true,
    );
    final message = systemMessage;
    if (message != null) {
      unawaited(
        FirestoreChatRepository(firestore: _firestore)
            .sendSystemMessage(gameId: normalizedGameId, text: message)
            .catchError((Object _) {}),
      );
    }

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

      final botCount = _botCountFromData(data);
      final difficulty = _difficultyFromData(data);
      final activeState = _stateForRoom(
        gameId: normalizedGameId,
        participants: participants,
        botCount: _boundedOnlineBotCount(botCount, participants),
        difficulty: difficulty,
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
      FirestoreChatRepository(firestore: _firestore)
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
    GameDifficulty difficulty = GameDifficulty.normal,
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
      difficulty: difficulty,
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

  int _botCountFromData(Map<String, dynamic> data) {
    final raw = data['botCount'];
    if (raw is int) {
      return raw.clamp(0, GameConstants.maxBotPlayers).toInt();
    }
    return 0;
  }

  GameDifficulty _difficultyFromData(Map<String, dynamic> data) {
    return GameDifficulty.values.firstWhere(
      (difficulty) => difficulty.name == (data['difficulty'] as String?),
      orElse: () => GameDifficulty.normal,
    );
  }

  _OnlineRoomParticipant? _participantForUid(
    List<_OnlineRoomParticipant> participants,
    String uid,
  ) {
    for (final participant in participants) {
      if (participant.uid == uid) {
        return participant;
      }
    }
    return null;
  }

  OnlinePlayerPresence _presenceFromDoc(
    String fallbackPlayerId,
    Map<String, dynamic> data,
  ) {
    final lastSeenAt = data['lastSeenAt'];
    return OnlinePlayerPresence(
      playerId: data['playerId'] as String? ?? fallbackPlayerId,
      uid: data['uid'] as String? ?? '',
      isOnline: data['isOnline'] as bool? ?? false,
      lastSeenAt: lastSeenAt is Timestamp ? lastSeenAt.toDate() : null,
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
