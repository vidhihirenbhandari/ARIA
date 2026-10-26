import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/local_storage.dart';
import '../../../shared/services/claude_service.dart';
import '../../../shared/models/aria_conversation.dart';
import '../../../shared/demo/demo_data.dart';

class ConversationRepository {
  final ApiClient _client;
  final LocalStorage _storage;
  final ClaudeService _claudeService;
  final bool isDemoMode;

  static const String _historyKey = 'conversation_history';
  static const int _maxHistoryMessages = 20;

  ConversationRepository(
    this._client,
    this._storage,
    this._claudeService, {
    this.isDemoMode = false,
  });

  bool get _useClaudeApi => !isDemoMode && _claudeService.hasApiKey;

  // Load stored conversation history from Hive
  List<Message> _loadHistory() {
    final raw = _storage.get(_historyKey) as String?;
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Persist conversation history to Hive (keep last N messages)
  Future<void> _saveHistory(List<Message> messages) async {
    final trimmed = messages.length > _maxHistoryMessages
        ? messages.sublist(messages.length - _maxHistoryMessages)
        : messages;
    await _storage.put(_historyKey, jsonEncode(trimmed.map((m) => m.toJson()).toList()));
  }

  Future<List<Conversation>> getConversations() async {
    if (_useClaudeApi) return [];
    if (isDemoMode) return [];
    final response = await _client.get('/conversations');
    return (response.data['items'] as List)
        .map((j) => Conversation.fromJson(j))
        .toList();
  }

  Future<Conversation> createConversation() async {
    if (_useClaudeApi || isDemoMode) {
      return Conversation(
        id: 'aria-conv-${DateTime.now().millisecondsSinceEpoch}',
        userId: 'local-user',
        title: 'Chat',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final response = await _client.post('/conversations', data: {});
    return Conversation.fromJson(response.data);
  }

  Future<List<Message>> getMessages(String conversationId) async {
    if (_useClaudeApi) return _loadHistory();
    if (isDemoMode) return [];
    final response = await _client.get('/conversations/$conversationId/messages');
    return (response.data['items'] as List)
        .map((j) => Message.fromJson(j))
        .toList();
  }

  Stream<String> streamMessage(String conversationId, String content) {
    if (_useClaudeApi) return _claudeApiStream(conversationId, content);
    if (isDemoMode) return _demoStream(content);
    return _client.streamPost(
      '/conversations/$conversationId/messages',
      data: {'content': content, 'role': 'user'},
    );
  }

  Stream<String> _claudeApiStream(
      String conversationId, String userMessage) async* {
    final history = _loadHistory();

    // Add user message to history immediately
    final userMsg = Message(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      role: 'user',
      content: userMessage,
      createdAt: DateTime.now(),
    );
    final updatedHistory = [...history, userMsg];

    // Stream the assistant response
    final responseBuffer = StringBuffer();
    await for (final chunk in _claudeService.streamMessage(
      userMessage: userMessage,
      history: history,
    )) {
      responseBuffer.write(chunk);
      yield chunk;
    }

    // Save assistant response to history
    final assistantMsg = Message(
      id: 'asst-${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      role: 'assistant',
      content: responseBuffer.toString(),
      createdAt: DateTime.now(),
    );
    await _saveHistory([...updatedHistory, assistantMsg]);

    // Auto-extract memories (simple heuristic)
    _extractAndSaveMemories(userMessage, responseBuffer.toString());
  }

  void _extractAndSaveMemories(String userMessage, String assistantResponse) {
    final keywords = [
      'remember',
      'don\'t forget',
      'important',
      'promised',
      'meeting',
      'deadline',
      'birthday',
      'anniversary',
    ];
    final lowerMsg = userMessage.toLowerCase();
    final hasMemorySignal = keywords.any((k) => lowerMsg.contains(k));
    if (!hasMemorySignal) return;

    // Store as a quick memory note
    final memories = _storage.getList('aria_memories');
    memories.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'content': userMessage,
      'source': 'conversation',
      'created_at': DateTime.now().toIso8601String(),
      'tags': ['auto-extracted'],
    });
    // Keep last 100 memories
    final trimmed = memories.length > 100
        ? memories.sublist(memories.length - 100)
        : memories;
    _storage.putList('aria_memories', trimmed);
  }

  Stream<String> _demoStream(String userMessage) async* {
    await Future.delayed(const Duration(milliseconds: 400));
    final response = DemoData.chatResponse(userMessage);
    for (final char in response.split('')) {
      yield char;
      await Future.delayed(const Duration(milliseconds: 12));
    }
  }
}

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  final storage = ref.read(localStorageProvider);
  final claudeService = ref.read(claudeServiceProvider);
  return ConversationRepository(
    ref.read(apiClientProvider),
    storage,
    claudeService,
    isDemoMode: storage.isDemoMode(),
  );
});
