class TravelBooking {
  final String id;
  final String userId;
  final String type; // flight | hotel | train | car_rental
  final DateTime departureTime;
  final DateTime? arrivalTime;
  final String status; // confirmed | pending | cancelled
  final Map<String, dynamic> details;
  final String? sourceEmail;

  const TravelBooking({
    required this.id,
    required this.userId,
    required this.type,
    required this.departureTime,
    this.arrivalTime,
    this.status = 'confirmed',
    this.details = const {},
    this.sourceEmail,
  });

  bool get isFlight => type == 'flight';
  bool get isHotel => type == 'hotel';

  TravelBooking copyWith({
    String? id,
    String? userId,
    String? type,
    DateTime? departureTime,
    DateTime? arrivalTime,
    String? status,
    Map<String, dynamic>? details,
    String? sourceEmail,
  }) {
    return TravelBooking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      status: status ?? this.status,
      details: details ?? this.details,
      sourceEmail: sourceEmail ?? this.sourceEmail,
    );
  }

  factory TravelBooking.fromJson(Map<String, dynamic> json) => TravelBooking(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        type: json['type'] as String,
        departureTime: DateTime.parse(json['departure_time'] as String),
        arrivalTime: json['arrival_time'] != null
            ? DateTime.parse(json['arrival_time'] as String)
            : null,
        status: json['status'] as String? ?? 'confirmed',
        details: (json['details'] as Map<String, dynamic>?) ?? {},
        sourceEmail: json['source_email'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'departure_time': departureTime.toIso8601String(),
        'arrival_time': arrivalTime?.toIso8601String(),
        'status': status,
        'details': details,
        'source_email': sourceEmail,
      };
}
