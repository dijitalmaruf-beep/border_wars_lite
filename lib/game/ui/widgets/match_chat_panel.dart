import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/firebase/firestore_chat_repository.dart';
import '../../models/chat_message.dart';
import '../../models/player.dart';
import 'chat_message_bubble.dart';
import 'premium_button.dart';
import 'premium_panel.dart';

class MatchChatPanel extends StatefulWidget {
  const MatchChatPanel({
    required this.gameId,
    required this.localPlayer,
    required this.repository,
    required this.messagesStream,
    super.key,
  });

  final String gameId;
  final Player localPlayer;
  final FirestoreChatRepository repository;
  final Stream<List<ChatMessage>> messagesStream;

  @override
  State<MatchChatPanel> createState() => _MatchChatPanelState();
}

class _MatchChatPanelState extends State<MatchChatPanel> {
  static const _quickMessages = <String>[
    'İyi hamle.',
    'Sıra sende.',
    'Hazırım.',
    'Anlaşma yapalım.',
    'Son renk kalana kadar.',
    'Kıtana saldırmayacağım.',
  ];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  DateTime? _lastSentAt;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
        child: PremiumPanel(
          borderColor: AppColors.premiumCyan.withValues(alpha: 0.58),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.forum_outlined,
                      color: AppColors.premiumCyan,
                      size: 21,
                    ),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text(
                        'Maç Sohbeti',
                        style: TextStyle(
                          color: AppColors.premiumText,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: AppColors.premiumMutedText,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<ChatMessage>>(
                    stream: widget.messagesStream,
                    builder: (context, snapshot) {
                      final messages =
                          snapshot.data ?? const <ChatMessage>[];
                      if (messages.isEmpty) {
                        return const Center(
                          child: Text(
                            'Henüz mesaj yok.',
                            style: TextStyle(
                              color: AppColors.premiumMutedText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(
                            _scrollController.position.maxScrollExtent,
                          );
                        }
                      });
                      return ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(right: 4, bottom: 8),
                        itemCount: messages.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return ChatMessageBubble(
                            message: message,
                            isLocalPlayer:
                                message.senderPlayerId ==
                                widget.localPlayer.id,
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _quickMessages.map((message) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: const Color(0xCC071C2B),
                          side: BorderSide(
                            color: AppColors.premiumBorder.withValues(
                              alpha: 0.70,
                            ),
                          ),
                          label: Text(
                            message,
                            style: const TextStyle(
                              color: AppColors.premiumText,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          onPressed: _isSending
                              ? null
                              : () => _sendText(message),
                        ),
                      );
                    }).toList(growable: false),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 2,
                        maxLength: ChatMessage.maxTextLength,
                        inputFormatters: <TextInputFormatter>[
                          LengthLimitingTextInputFormatter(
                            ChatMessage.maxTextLength,
                          ),
                        ],
                        enabled: !_isSending,
                        style: const TextStyle(
                          color: AppColors.premiumText,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Kısa komut mesajı yaz...',
                          hintStyle: const TextStyle(
                            color: AppColors.premiumMutedText,
                          ),
                          counterText: '',
                          filled: true,
                          fillColor: const Color(0xAA06121D),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.premiumBorder.withValues(
                                alpha: 0.72,
                              ),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.premiumCyan,
                              width: 1.4,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _sendText(_controller.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 102,
                      child: PremiumButton(
                        label: 'GÖNDER',
                        icon: Icons.send,
                        onPressed: _isSending
                            ? null
                            : () => _sendText(_controller.text),
                        tone: PremiumButtonTone.teal,
                        height: 48,
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.premiumRed,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendText(String value) async {
    final normalizedText = ChatMessage.normalizeUserText(value);
    if (normalizedText == null) {
      setState(() {
        _errorMessage = value.trim().isEmpty
            ? 'Mesaj boş olamaz.'
            : 'Mesaj 120 karakterden uzun olamaz.';
      });
      return;
    }

    final now = DateTime.now();
    if (!ChatMessage.canSendAt(now, _lastSentAt)) {
      setState(() {
        _errorMessage = 'Yeni mesaj göndermek için 2 saniye bekle.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      await widget.repository.sendUserMessage(
        gameId: widget.gameId,
        senderPlayerId: widget.localPlayer.id,
        senderName: widget.localPlayer.name,
        senderColorValue: widget.localPlayer.colorValue,
        text: normalizedText,
        now: now,
      );
      _lastSentAt = now;
      _controller.clear();
    } catch (error) {
      setState(() {
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }
}
