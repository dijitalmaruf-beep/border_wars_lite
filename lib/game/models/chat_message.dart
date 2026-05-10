enum ChatMessageType { user, system }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.gameId,
    required this.senderPlayerId,
    required this.senderName,
    required this.senderColorValue,
    required this.text,
    required this.createdAt,
    required this.type,
  });

  static const maxTextLength = 120;
  static const messageLimit = 50;
  static const sendCooldown = Duration(seconds: 2);

  final String id;
  final String gameId;
  final String senderPlayerId;
  final String senderName;
  final int senderColorValue;
  final String text;
  final DateTime createdAt;
  final ChatMessageType type;

  bool get isSystem => type == ChatMessageType.system;

  static String? normalizeUserText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > maxTextLength) {
      return null;
    }
    return trimmed;
  }

  static bool canSendAt(DateTime now, DateTime? lastSentAt) {
    if (lastSentAt == null) {
      return true;
    }
    return now.difference(lastSentAt) >= sendCooldown;
  }

  static List<ChatMessage> chronological(Iterable<ChatMessage> messages) {
    final sorted = messages.toList(growable: false)
      ..sort((a, b) {
        final dateCompare = a.createdAt.compareTo(b.createdAt);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.id.compareTo(b.id);
      });
    return sorted;
  }

  static ChatMessageType typeFromName(String? value) {
    return ChatMessageType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ChatMessageType.user,
    );
  }
}

class ChatUnreadCounter {
  bool _isOpen = false;
  bool _hasSynced = false;
  final Set<String> _seenMessageIds = <String>{};

  int unreadCount = 0;

  bool get isOpen => _isOpen;

  void open() {
    _isOpen = true;
    unreadCount = 0;
  }

  void close() {
    _isOpen = false;
  }

  void reset() {
    _isOpen = false;
    _hasSynced = false;
    _seenMessageIds.clear();
    unreadCount = 0;
  }

  void sync(List<ChatMessage> messages) {
    final incomingIds = messages.map((message) => message.id).toSet();
    if (!_hasSynced) {
      _seenMessageIds.addAll(incomingIds);
      _hasSynced = true;
      unreadCount = 0;
      return;
    }

    final newIds = incomingIds.difference(_seenMessageIds);
    _seenMessageIds
      ..clear()
      ..addAll(incomingIds);

    if (_isOpen) {
      unreadCount = 0;
      return;
    }
    unreadCount += newIds.length;
  }
}
