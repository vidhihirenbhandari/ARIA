import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/aria_conversation.dart';
import '../../../../shared/services/voice_service.dart';
import '../../data/events_repository.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/voice_input_button.dart';
import '../widgets/suggestion_card.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isRecording = false;
  bool _isListeningOverlay = false;

  // Suggestions loaded from API; fallback to empty list
  List<Map<String, dynamic>> _suggestions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).initConversation();
      _loadSuggestions();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    try {
      final events = await ref.read(eventsRepositoryProvider).getPendingEvents();
      if (!mounted) return;
      setState(() {
        _suggestions = events
            .map((e) => {
                  'id': e.id,
                  'title': e.title,
                  'confidence': e.confidenceScore ?? 0.9,
                  'source': e.source,
                  'details': {
                    'Description': e.description ?? '',
                    'Date': e.startTime.toLocal().toString().substring(0, 10),
                    'Time':
                        '${e.startTime.hour.toString().padLeft(2, '0')}:${e.startTime.minute.toString().padLeft(2, '0')}',
                    if (e.location != null) 'Location': e.location!,
                  },
                })
            .toList();
      });
    } catch (_) {
      // Leave suggestions empty on error
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(chatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _startVoiceRecording() async {
    final voiceService = ref.read(voiceServiceProvider);
    setState(() {
      _isRecording = true;
      _isListeningOverlay = true;
    });
    try {
      final transcript = await voiceService.listen();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isListeningOverlay = false;
      });
      if (transcript != null && transcript.trim().isNotEmpty) {
        _textController.text = transcript;
        _sendMessage();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isListeningOverlay = false;
      });
    }
  }

  Future<void> _stopVoiceRecording() async {
    final voiceService = ref.read(voiceServiceProvider);
    await voiceService.stopListening();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isListeningOverlay = false;
    });
  }

  void _handleVoiceTap() {
    if (_isRecording) {
      _stopVoiceRecording();
    } else {
      _startVoiceRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    ref.listen(chatProvider, (_, next) {
      if (next.messages.isNotEmpty || next.isStreaming) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
            children: [
              if (_suggestions.isNotEmpty) _buildSuggestionsBar(),
              Expanded(
                child: chatState.messages.isEmpty && !chatState.isStreaming
                    ? _buildEmptyState()
                    : _buildMessageList(chatState),
              ),
              _buildInputBar(chatState),
            ],
          ),
          if (_isListeningOverlay) _buildListeningOverlay(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppColors.border),
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ARIA', style: AppTextStyles.headlineSmall),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.success.withOpacity(0.5), blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text('Online', style: AppTextStyles.caption.copyWith(color: AppColors.success)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildSuggestionsBar() {
    return Container(
      color: AppColors.accent.withOpacity(0.05),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.notifications_outlined, color: AppColors.accent, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_suggestions.length} pending suggestion${_suggestions.length > 1 ? 's' : ''} — tap to review',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent),
            ),
          ),
          GestureDetector(
            onTap: _showSuggestions,
            child: Text(
              'Review',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuggestions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  const Text('Pending Suggestions', style: AppTextStyles.headlineMedium),
                  const Spacer(),
                  Text(
                    '${_suggestions.length} items',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            ..._suggestions.map((s) => SuggestionCard(
                  title: s['title'] as String,
                  confidence: (s['confidence'] as num).toDouble(),
                  details: Map<String, String>.from(
                    (s['details'] as Map<String, dynamic>).map(
                      (k, v) => MapEntry(k, v.toString()),
                    ),
                  ),
                  source: s['source'] as String,
                  onApprove: () async {
                    final id = s['id'] as String;
                    await ref.read(eventsRepositoryProvider).approveEvent(id);
                    setState(() => _suggestions.remove(s));
                    if (mounted) Navigator.pop(context);
                  },
                  onIgnore: () async {
                    final id = s['id'] as String;
                    await ref.read(eventsRepositoryProvider).rejectEvent(id);
                    setState(() => _suggestions.remove(s));
                    if (mounted) Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                'Listening...',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap mic to stop',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 30, spreadRadius: 5),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          const Text('How can I help?', style: AppTextStyles.displaySmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Ask me anything, or let me know what you need to organize.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildSuggestionChips(),
        ],
      ),
    );
  }

  Widget _buildSuggestionChips() {
    final prompts = [
      "What do I have today?",
      "Any meetings tomorrow?",
      "Remind me to call Raj",
      "What commitments did I make?",
      "Prepare for my next meeting",
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: prompts.map((p) {
        return GestureDetector(
          onTap: () {
            _textController.text = p;
            _sendMessage();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(p, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageList(ChatState chatState) {
    final allMessages = chatState.messages;
    final itemCount = allMessages.length + (chatState.isStreaming ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index < allMessages.length) {
          return MessageBubble(message: allMessages[index]);
        }
        if (chatState.streamingContent != null &&
            chatState.streamingContent!.isNotEmpty) {
          return MessageBubble(
            message: Message(
              id: 'streaming',
              conversationId: chatState.conversationId ?? '',
              role: 'assistant',
              content: chatState.streamingContent!,
              createdAt: DateTime.now(),
            ),
            isStreaming: true,
          );
        }
        return const TypingIndicator();
      },
    );
  }

  Widget _buildInputBar(ChatState chatState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Message ARIA...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  VoiceInputButton(
                    isRecording: _isRecording,
                    onTap: _handleVoiceTap,
                    onLongPressStart: _startVoiceRecording,
                    onLongPressEnd: _stopVoiceRecording,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
