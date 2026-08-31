import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/local_storage.dart';
import '../../../shared/models/aria_travel.dart';
import '../../../shared/demo/demo_data.dart';

class TravelRepository {
  final ApiClient _client;
  final bool isDemoMode;
  TravelRepository(this._client, {this.isDemoMode = false});

  Future<List<TravelBooking>> getUpcomingBookings() async {
    if (isDemoMode) return DemoData.travelBookings;
    try {
      final response = await _client.get('/travel', queryParameters: {'status': 'confirmed'});
      return (response.data['items'] as List)
          .map((j) => TravelBooking.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

final travelRepositoryProvider = Provider<TravelRepository>((ref) {
  final storage = ref.read(localStorageProvider);
  return TravelRepository(ref.read(apiClientProvider), isDemoMode: storage.isDemoMode());
});

final upcomingTravelProvider = FutureProvider<List<TravelBooking>>((ref) async {
  return ref.read(travelRepositoryProvider).getUpcomingBookings();
});
