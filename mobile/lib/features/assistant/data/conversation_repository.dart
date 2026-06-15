import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/models/aria_conversation.dart';

class ConversationRepository {
  final ApiClient _client;

  ConversationRepository(this._client);

  Future<List<Conversation>> getConversations() async {
    final response = await _client.get('/conversations');
    return (response.data['items'] as List)
        .map((j) => Conversation.fromJson(j))
        .toList();
  }

  Future<Conversation> createConversation() async {
    final response = await _client.post('/conversations', data: {});
    return Conversation.fromJson(response.data);
  }

  Future<List<Message>> getMessages(String conversationId) async {
    final response = await _client.get('/conversations/$conversationId/messages');
    return (response.data['items'] as List)
        .map((j) => Message.fromJson(j))
        .toList();
  }

  Stream<String> streamMessage(String conversationId, String content) {
    return _client.streamPost(
      '/conversations/$conversationId/messages',
      data: {'content': content, 'role': 'user'},
    );
  }
}

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(ref.read(apiClientProvider));
});
