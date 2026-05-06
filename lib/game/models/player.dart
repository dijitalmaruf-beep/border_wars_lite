import 'bot_personality.dart';

const Object _playerSentinel = Object();

class Player {
  const Player({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.isBot,
    this.botPersonality,
  });

  final String id;
  final String name;
  final int colorValue;
  final bool isBot;
  final BotPersonality? botPersonality;

  Player copyWith({
    String? id,
    String? name,
    int? colorValue,
    bool? isBot,
    Object? botPersonality = _playerSentinel,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      isBot: isBot ?? this.isBot,
      botPersonality: identical(botPersonality, _playerSentinel)
          ? this.botPersonality
          : botPersonality as BotPersonality?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'isBot': isBot,
      'botPersonality': botPersonality?.name,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    final personalityName = map['botPersonality'] as String?;
    return Player(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: map['colorValue'] as int,
      isBot: map['isBot'] as bool,
      botPersonality: personalityName == null
          ? null
          : BotPersonality.values.firstWhere(
              (personality) => personality.name == personalityName,
            ),
    );
  }
}
