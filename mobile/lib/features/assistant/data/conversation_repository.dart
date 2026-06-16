import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/local_storage.dart';
import '../../../shared/models/aria_conversation.dart';
import '../../../shared/demo/demo_data.dart';

class ConversationRepository {
  final ApiClient _client;
  final bool isDemoMode;

  ConversationRepository(this._client, {this.isDemoMode = false});

  Future<List<Conversation>> getConversations() async {
    if (isDemoMode) return [];
    final response = await _client.get('/conversations');
    return (response.data['items'] as List)
        .map((j) => Conversation.fromJson(j))
        .toList();
  }

  Future<Conversation> createConversation() async {
    if (isDemoMode) {
      return Conversation(
        id: 'demo-conv-001',
        userId: 'demo-user-001',
        title: 'Demo',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    final response = await _client.post('/conversations', data: {});
    return Conversation.fromJson(response.data);
  }

  Future<List<Message>> getMessages(String conversationId) async {
    if (isDemoMode) return [];
    final response = await _client.get('/conversations/$conversationId/messages');
    return (response.data['items'] as List)
        .map((j) => Message.fromJson(j))
        .toList();
  }

  Stream<String> streamMessage(String conversationId, String content) {
    if (isDemoMode) return _demoStream(content);
    return _client.streamPost(
      '/conversations/$conversationId/messages',
      data: {'content': content, 'role': 'user'},
    );
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
  return ConversationRepository(ref.read(apiClientProvider), isDemoMode: storage.isDemoMode());
});
