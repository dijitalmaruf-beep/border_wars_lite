import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/app_colors.dart';
import '../../game/models/chat_message.dart';
import 'firebase_service.dart';

class FirestoreChatRepository {
  FirestoreChatRepository({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;
  final Map<String, DateTime> _lastSentAtByPlayer = <String, DateTime>{};

  FirebaseFirestore get _db => _firestore ?? FirebaseService.firestore;

  CollectionReference<Map<String, dynamic>> _messages(String gameId) {
    return _db
        .collection('games')
        .doc(_normalizeGameId(gameId))
        .collection('chatMessages');
  }

  Stream<List<ChatMessage>> watchMessages(String gameId) {
    final normalizedGameId = _normalizeGameId(gameId);
    return _messages(normalizedGameId)
        .orderBy('createdAt', descending: true)
        .limit(ChatMessage.messageLimit)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) => _messageFromDoc(normalizedGameId, doc))
              .toList(growable: false);
          return ChatMessage.chronological(messages);
        });
  }

  Future<void> sendUserMessage({
    required String gameId,
    required String senderPlayerId,
    required String senderName,
    required int senderColorValue,
    required String text,
    DateTime? now,
  }) async {
    await FirebaseService.ensureSignedInAnonymously();
    final normalizedText = ChatMessage.normalizeUserText(text);
    if (normalizedText == null) {
      throw StateError('Mesaj boş veya 120 karakterden uzun olamaz.');
    }

    final normalizedGameId = _normalizeGameId(gameId);
    final sentAt = now ?? DateTime.now();
    final cooldownKey = '$normalizedGameId:$senderPlayerId';
    final previousSentAt = _lastSentAtByPlayer[cooldownKey];
    if (!ChatMessage.canSendAt(sentAt, previousSentAt)) {
      throw StateError('Yeni mesaj göndermek için 2 saniye bekle.');
    }

    _lastSentAtByPlayer[cooldownKey] = sentAt;
    try {
      await _messages(normalizedGameId).add(<String, dynamic>{
        'gameId': normalizedGameId,
        'senderPlayerId': senderPlayerId,
        'senderName': _cleanSenderName(senderName),
        'senderColor': senderColorValue,
        'text': normalizedText,
        'createdAt': Timestamp.fromDate(sentAt),
        'type': ChatMessageType.user.name,
      });
    } catch (_) {
      if (previousSentAt == null) {
        _lastSentAtByPlayer.remove(cooldownKey);
      } else {
        _lastSentAtByPlayer[cooldownKey] = previousSentAt;
      }
      rethrow;
    }
  }

  Future<void> sendSystemMessage({
    required String gameId,
    required String text,
  }) async {
    await FirebaseService.ensureSignedInAnonymously();
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return;
    }
    final normalizedGameId = _normalizeGameId(gameId);
    final sentAt = DateTime.now();
    await _messages(normalizedGameId).add(<String, dynamic>{
      'gameId': normalizedGameId,
      'senderPlayerId': 'system',
      'senderName': 'Sistem',
      'senderColor': 0xFFE9A22A,
      'text': normalizedText.length > ChatMessage.maxTextLength
          ? normalizedText.substring(0, ChatMessage.maxTextLength)
          : normalizedText,
      'createdAt': Timestamp.fromDate(sentAt),
      'type': ChatMessageType.system.name,
    });
  }

  ChatMessage _messageFromDoc(
    String fallbackGameId,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    return ChatMessage(
      id: doc.id,
      gameId: data['gameId'] as String? ?? fallbackGameId,
      senderPlayerId: data['senderPlayerId'] as String? ?? 'unknown',
      senderName: data['senderName'] as String? ?? 'Komutan',
      senderColorValue: data['senderColor'] as int? ?? AppColors.humanBlueValue,
      text: data['text'] as String? ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      type: ChatMessage.typeFromName(data['type'] as String?),
    );
  }

  String _normalizeGameId(String gameId) {
    return gameId.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  String _cleanSenderName(String value) {
    final clean = value.trim();
    if (clean.isEmpty) {
      return 'Komutan';
    }
    return clean.length > 18 ? clean.substring(0, 18) : clean;
  }
}
