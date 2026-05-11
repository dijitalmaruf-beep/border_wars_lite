import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/firebase/firestore_chat_repository.dart';
import '../../models/chat_message.dart';
import '../../models/player.dart';
import 'match_chat_panel.dart';

class MatchChatButton extends StatefulWidget {
  const MatchChatButton({
    required this.gameId,
    required this.localPlayer,
    required this.repository,
    super.key,
  });

  final String gameId;
  final Player localPlayer;
  final FirestoreChatRepository repository;

  static bool shouldShow({required bool isOnline}) => isOnline;

  @override
  State<MatchChatButton> createState() => _MatchChatButtonState();
}

class _MatchChatButtonState extends State<MatchChatButton> {
  final ChatUnreadCounter _unreadCounter = ChatUnreadCounter();
  late Stream<List<ChatMessage>> _messagesStream;
  List<ChatMessage> _latestMessages = const <ChatMessage>[];

  @override
  void initState() {
    super.initState();
    _messagesStream = widget.repository.watchMessages(widget.gameId);
  }

  @override
  void didUpdateWidget(covariant MatchChatButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameId != widget.gameId ||
        oldWidget.repository != widget.repository) {
      _messagesStream = widget.repository.watchMessages(widget.gameId);
      _latestMessages = const <ChatMessage>[];
      _unreadCounter.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatMessage>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        final messages = snapshot.data ?? _latestMessages;
        if (snapshot.hasData) {
          _latestMessages = snapshot.data!;
        }
        _unreadCounter.sync(messages);
        final unreadCount = _unreadCounter.unreadCount;
        return SizedBox(
          width: 38,
          height: 38,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _openChat,
                    splashColor: AppColors.premiumCyan.withValues(alpha: 0.18),
                    highlightColor: AppColors.premiumCyan.withValues(
                      alpha: 0.08,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: const Color(0xCC071C2B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: unreadCount > 0
                              ? AppColors.premiumGold.withValues(alpha: 0.82)
                              : AppColors.premiumBorder.withValues(alpha: 0.62),
                        ),
                        boxShadow: <BoxShadow>[
                          if (unreadCount > 0)
                            BoxShadow(
                              color: AppColors.premiumGold.withValues(
                                alpha: 0.24,
                              ),
                              blurRadius: 14,
                            ),
                        ],
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        color: unreadCount > 0
                            ? AppColors.premiumGold
                            : AppColors.premiumText,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: _UnreadBadge(count: unreadCount),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openChat() async {
    setState(_unreadCounter.open);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => MatchChatPanel(
        gameId: widget.gameId,
        localPlayer: widget.localPlayer,
        repository: widget.repository,
        messagesStream: _messagesStream,
        initialMessages: _latestMessages,
      ),
    );
    if (mounted) {
      setState(_unreadCounter.close);
    }
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.premiumRed,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.premiumText, width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.premiumRed.withValues(alpha: 0.45),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          count > 9 ? '9+' : '$count',
          style: const TextStyle(
            color: AppColors.premiumText,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
