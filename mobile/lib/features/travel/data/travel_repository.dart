import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/models/aria_travel.dart';

class TravelRepository {
  final ApiClient _client;
  TravelRepository(this._client);

  Future<List<TravelBooking>> getUpcomingBookings() async {
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
  return TravelRepository(ref.read(apiClientProvider));
});

final upcomingTravelProvider = FutureProvider<List<TravelBooking>>((ref) async {
  return ref.read(travelRepositoryProvider).getUpcomingBookings();
});
