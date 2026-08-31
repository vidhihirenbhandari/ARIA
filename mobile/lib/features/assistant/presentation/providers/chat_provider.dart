import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/aria_conversation.dart';
import '../../data/conversation_repository.dart';

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final bool isStreaming;
  final String? streamingContent;
  final String? conversationId;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isStreaming = false,
    this.streamingContent,
    this.conversationId,
    this.error,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isStreaming,
    String? streamingContent,
    String? conversationId,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
      streamingContent: streamingContent ?? this.streamingContent,
      conversationId: conversationId ?? this.conversationId,
      error: error ?? this.error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ConversationRepository _repo;

  ChatNotifier(this._repo) : super(const ChatState());

  Future<void> initConversation() async {
    if (state.conversationId != null) return;
    state = state.copyWith(isLoading: true);
    try {
      final conv = await _repo.createConversation();
      state = state.copyWith(conversationId: conv.id, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> sendMessage(String content) async {
    if (state.conversationId == null) await initConversation();

    final userMsg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: state.conversationId!,
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isStreaming: true,
      streamingContent: '',
    );

    String accumulated = '';
    try {
      await for (final chunk
          in _repo.streamMessage(state.conversationId!, content)) {
        accumulated += chunk;
        state = state.copyWith(streamingContent: accumulated);
      }

      final assistantMsg = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        conversationId: state.conversationId!,
        role: 'assistant',
        content: accumulated,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isStreaming: false,
        streamingContent: null,
      );
    } catch (e) {
      state = state.copyWith(
        isStreaming: false,
        streamingContent: null,
        error: e.toString(),
      );
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.read(conversationRepositoryProvider));
});
