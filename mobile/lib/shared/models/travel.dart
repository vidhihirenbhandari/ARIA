enum TravelType { flight, hotel, carRental, train, activity }
enum TravelStatus { upcoming, ongoing, completed, cancelled }

class TravelItinerary {
  final String id;
  final String destination;
  final DateTime departureDate;
  final DateTime returnDate;
  final List<TravelSegment> segments;
  final TravelStatus status;
  final String? bookingRef;
  final double? totalCost;
  final String? currency;

  const TravelItinerary({
    required this.id,
    required this.destination,
    required this.departureDate,
    required this.returnDate,
    this.segments = const [],
    this.status = TravelStatus.upcoming,
    this.bookingRef,
    this.totalCost,
    this.currency,
  });
}

class TravelSegment {
  final String id;
  final TravelType type;
  final String title;
  final String? subtitle;
  final DateTime startTime;
  final DateTime? endTime;
  final String? confirmationCode;
  final Map<String, dynamic>? details;

  const TravelSegment({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.startTime,
    this.endTime,
    this.confirmationCode,
    this.details,
  });
}

class TravelSuggestion {
  final String id;
  final String title;
  final String description;
  final TravelType type;
  final double? estimatedCost;
  final String? currency;
  final double confidence;
  final bool isPending;
  final Map<String, dynamic>? details;

  const TravelSuggestion({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.estimatedCost,
    this.currency,
    this.confidence = 0.8,
    this.isPending = true,
    this.details,
  });
}
