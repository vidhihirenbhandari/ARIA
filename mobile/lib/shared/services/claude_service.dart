import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/aria_conversation.dart';
import '../models/user_profile.dart';
import 'local_storage.dart';
import 'profile_service.dart';

class ClaudeService {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-haiku-4-5';
  static const String _anthropicVersion = '2023-06-01';

  final Dio _dio;
  final LocalStorage _storage;
  final ProfileService _profileService;

  ClaudeService(this._dio, this._storage, this._profileService);

  String? get apiKey => _storage.getApiKey();
  bool get hasApiKey => apiKey != null && apiKey!.isNotEmpty;

  String _buildSystemPrompt(UserProfile profile) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateStr =
        '${now.day} ${_monthName(now.month)} ${now.year}, ${_dayName(now.weekday)}';

    final buffer = StringBuffer();
    buffer.writeln(
        'You are ARIA (Adaptive Real-time Intelligence Assistant), a proactive AI personal assistant.');
    buffer.writeln(
        'You are warm, concise, and genuinely helpful. You remember context and proactively surface useful information.');
    buffer.writeln();
    buffer.writeln('Current date and time: $dateStr, $timeStr');
    buffer.writeln();

    if (profile.fullName.isNotEmpty) {
      buffer.writeln('User: ${profile.fullName}');
    }
    if (profile.workplace.isNotEmpty) {
      buffer.writeln('Works at: ${profile.workplace}');
    }
    if (profile.role.isNotEmpty) {
      buffer.writeln('Role: ${profile.role}');
    }
    if (profile.homeLocation.isNotEmpty) {
      buffer.writeln('Home: ${profile.homeLocation}');
    }
    if (profile.workLocation.isNotEmpty) {
      buffer.writeln('Office: ${profile.workLocation}');
    }
    if (profile.goals.isNotEmpty) {
      buffer.writeln('Goals: ${profile.goals}');
    }
    if (profile.healthGoals.isNotEmpty) {
      buffer.writeln('Health goals: ${profile.healthGoals}');
    }
    if (profile.wakeTime.isNotEmpty) {
      buffer.writeln(
          'Schedule: wakes at ${profile.wakeTime}, sleeps at ${profile.sleepTime}');
    }

    if (profile.importantContacts.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Important contacts:');
      for (final contact in profile.importantContacts) {
        final line = '- ${contact.name} (${contact.relationship})';
        if (contact.notes.isNotEmpty) {
          buffer.writeln('$line: ${contact.notes}');
        } else {
          buffer.writeln(line);
        }
      }
    }

    buffer.writeln();
    buffer.writeln(
        'Be proactive, brief, and personal. Use the user\'s name occasionally. '
        'If you detect a commitment or important information in the conversation, '
        'acknowledge it and offer to remember it.');

    return buffer.toString();
  }

  Stream<String> streamMessage({
    required String userMessage,
    required List<Message> history,
  }) async* {
    final key = apiKey;
    if (key == null || key.isEmpty) {
      yield 'API key not configured. Please add your Anthropic API key in Settings.';
      return;
    }

    final profile = _profileService.getProfile();
    final systemPrompt = _buildSystemPrompt(profile);

    // Build messages list (last 20 messages for context)
    final recentHistory = history.length > 20
        ? history.sublist(history.length - 20)
        : history;

    final messages = <Map<String, String>>[];
    for (final msg in recentHistory) {
      messages.add({'role': msg.role, 'content': msg.content});
    }
    messages.add({'role': 'user', 'content': userMessage});

    final body = {
      'model': _model,
      'max_tokens': 1024,
      'system': systemPrompt,
      'messages': messages,
      'stream': true,
    };

    try {
      final response = await _dio.post<ResponseBody>(
        _baseUrl,
        data: jsonEncode(body),
        options: Options(
          headers: {
            'x-api-key': key,
            'anthropic-version': _anthropicVersion,
            'content-type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
      );

      final stream = response.data!.stream;
      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        final lines = buffer.split('\n');
        buffer = lines.last;

        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') return;
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final type = json['type'] as String?;
              if (type == 'content_block_delta') {
                final delta = json['delta'] as Map<String, dynamic>?;
                if (delta != null && delta['type'] == 'text_delta') {
                  final text = delta['text'] as String? ?? '';
                  if (text.isNotEmpty) yield text;
                }
              }
            } catch (_) {
              // skip malformed SSE lines
            }
          }
        }
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        yield 'Invalid API key. Please check your Anthropic API key in Settings.';
      } else if (statusCode == 429) {
        yield 'Rate limit reached. Please wait a moment and try again.';
      } else {
        yield 'Connection error. Please check your internet connection.';
      }
    } catch (_) {
      yield 'An unexpected error occurred. Please try again.';
    }
  }

  Future<String> sendMessage({
    required String userMessage,
    required List<Message> history,
  }) async {
    final key = apiKey;
    if (key == null || key.isEmpty) {
      return 'API key not configured. Please add your Anthropic API key in Settings.';
    }

    final profile = _profileService.getProfile();
    final systemPrompt = _buildSystemPrompt(profile);

    final recentHistory = history.length > 20
        ? history.sublist(history.length - 20)
        : history;

    final messages = <Map<String, String>>[];
    for (final msg in recentHistory) {
      messages.add({'role': msg.role, 'content': msg.content});
    }
    messages.add({'role': 'user', 'content': userMessage});

    final body = {
      'model': _model,
      'max_tokens': 1024,
      'system': systemPrompt,
      'messages': messages,
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _baseUrl,
        data: jsonEncode(body),
        options: Options(
          headers: {
            'x-api-key': key,
            'anthropic-version': _anthropicVersion,
            'content-type': 'application/json',
          },
        ),
      );

      final content = response.data?['content'] as List<dynamic>?;
      if (content != null && content.isNotEmpty) {
        final firstBlock = content.first as Map<String, dynamic>;
        return firstBlock['text'] as String? ?? '';
      }
      return '';
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) {
        return 'Invalid API key. Please check your Anthropic API key in Settings.';
      } else if (statusCode == 429) {
        return 'Rate limit reached. Please wait a moment and try again.';
      } else {
        return 'Connection error. Please check your internet connection.';
      }
    } catch (_) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  String _monthName(int month) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month];
  }

  String _dayName(int weekday) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday];
  }
}

final claudeServiceProvider = Provider<ClaudeService>((ref) {
  final storage = ref.read(localStorageProvider);
  final profileService = ref.read(profileServiceProvider);
  return ClaudeService(Dio(), storage, profileService);
});
