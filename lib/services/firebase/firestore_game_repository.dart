import 'package:cloud_firestore/cloud_firestore.dart';

import '../../game/models/game_state.dart';

class FirestoreGameRepository {
  FirestoreGameRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _games =>
      _firestore.collection('games');

  Future<void> saveGameState(GameState state) async {
    await _games.doc(state.id).set(state.toMap());
  }

  Future<GameState?> loadGameState(String gameId) async {
    final snapshot = await _games.doc(gameId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      return null;
    }
    return GameState.fromMap(data);
  }

  Future<String> createOnlineGame({
    required String hostPlayerName,
  }) async {
    // TODO: Add lobby creation once multiplayer enters scope.
    throw UnimplementedError('Online games are not part of the MVP.');
  }

  Future<void> joinOnlineGame({
    required String gameId,
    required String playerName,
  }) async {
    // TODO: Add lobby joining once multiplayer enters scope.
    throw UnimplementedError('Online games are not part of the MVP.');
  }
}
