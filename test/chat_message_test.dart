import 'package:chroma_conquest/game/models/chat_message.dart';
import 'package:chroma_conquest/game/ui/widgets/match_chat_button.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMessage validation', () {
    test('empty message is rejected', () {
      expect(ChatMessage.normalizeUserText('   '), isNull);
    });

    test('over-limit message is rejected', () {
      expect(ChatMessage.normalizeUserText('a' * 121), isNull);
      expect(ChatMessage.normalizeUserText('a' * 120), 'a' * 120);
    });

    test('send cooldown requires two seconds between messages', () {
      final firstSentAt = DateTime(2026, 5, 10, 12);

      expect(ChatMessage.canSendAt(firstSentAt, null), isTrue);
      expect(
        ChatMessage.canSendAt(
          firstSentAt.add(const Duration(milliseconds: 1500)),
          firstSentAt,
        ),
        isFalse,
      );
      expect(
        ChatMessage.canSendAt(
          firstSentAt.add(const Duration(seconds: 2)),
          firstSentAt,
        ),
        isTrue,
      );
    });
  });

  test('messages are sorted chronologically', () {
    final messages = <ChatMessage>[
      _message('c', DateTime(2026, 5, 10, 12, 3)),
      _message('a', DateTime(2026, 5, 10, 12, 1)),
      _message('b', DateTime(2026, 5, 10, 12, 2)),
    ];

    expect(
      ChatMessage.chronological(messages).map((message) => message.id),
      <String>['a', 'b', 'c'],
    );
  });

  test('unread count resets when chat opens', () {
    final counter = ChatUnreadCounter();

    counter.sync(const <ChatMessage>[]);
    counter.sync(<ChatMessage>[_message('a', DateTime(2026, 5, 10, 12))]);
    expect(counter.unreadCount, 1);

    counter.open();
    expect(counter.unreadCount, 0);

    counter.sync(<ChatMessage>[
      _message('a', DateTime(2026, 5, 10, 12)),
      _message('b', DateTime(2026, 5, 10, 12, 1)),
    ]);
    expect(counter.unreadCount, 0);

    counter.close();
    counter.sync(<ChatMessage>[
      _message('a', DateTime(2026, 5, 10, 12)),
      _message('b', DateTime(2026, 5, 10, 12, 1)),
      _message('c', DateTime(2026, 5, 10, 12, 2)),
    ]);
    expect(counter.unreadCount, 1);
  });

  test('single-player game does not show chat', () {
    expect(MatchChatButton.shouldShow(isOnline: false), isFalse);
    expect(MatchChatButton.shouldShow(isOnline: true), isTrue);
  });
}

ChatMessage _message(String id, DateTime createdAt) {
  return ChatMessage(
    id: id,
    gameId: 'ABC123',
    senderPlayerId: 'player',
    senderName: 'Komutan',
    senderColorValue: 0xFF2563EB,
    text: 'Mesaj',
    createdAt: createdAt,
    type: ChatMessageType.user,
  );
}
