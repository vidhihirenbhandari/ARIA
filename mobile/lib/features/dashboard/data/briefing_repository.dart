import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/api_client.dart';

class DailyBriefing {
  final String greeting;
  final String summary;
  final int meetingsCount;
  final int tasksCount;
  final int pendingCount;

  const DailyBriefing({
    required this.greeting,
    required this.summary,
    required this.meetingsCount,
    required this.tasksCount,
    required this.pendingCount,
  });

  factory DailyBriefing.fromJson(Map<String, dynamic> json) => DailyBriefing(
        greeting: json['greeting'] as String? ?? 'Good morning',
        summary: json['summary'] as String? ?? '',
        meetingsCount: json['meetings_count'] as int? ?? 0,
        tasksCount: json['tasks_count'] as int? ?? 0,
        pendingCount: json['pending_count'] as int? ?? 0,
      );

  // Fallback when offline
  factory DailyBriefing.fallback() {
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return DailyBriefing(
      greeting: greet,
      summary: 'Your assistant is ready.',
      meetingsCount: 0,
      tasksCount: 0,
      pendingCount: 0,
    );
  }
}

class BriefingRepository {
  final ApiClient _client;
  BriefingRepository(this._client);

  Future<DailyBriefing> getTodaysBriefing() async {
    try {
      final response = await _client.get('/briefing/today');
      return DailyBriefing.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return DailyBriefing.fallback();
    }
  }
}

final briefingRepositoryProvider = Provider<BriefingRepository>((ref) {
  return BriefingRepository(ref.read(apiClientProvider));
});

final dailyBriefingProvider = FutureProvider<DailyBriefing>((ref) async {
  return ref.read(briefingRepositoryProvider).getTodaysBriefing();
});
