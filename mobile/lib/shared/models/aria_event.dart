class Event {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final List<String> attendees;
  final String source;
  final double? confidenceScore;
  final String status; // pending | approved | rejected
  final String? externalId;

  const Event({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.location,
    this.attendees = const [],
    required this.source,
    this.confidenceScore,
    this.status = 'approved',
    this.externalId,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  Duration get duration => endTime.difference(startTime);

  Event copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    List<String>? attendees,
    String? source,
    double? confidenceScore,
    String? status,
    String? externalId,
  }) {
    return Event(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      attendees: attendees ?? this.attendees,
      source: source ?? this.source,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      status: status ?? this.status,
      externalId: externalId ?? this.externalId,
    );
  }

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        startTime: DateTime.parse(json['start_time'] as String),
        endTime: DateTime.parse(json['end_time'] as String),
        location: json['location'] as String?,
        attendees: (json['attendees'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        source: json['source'] as String? ?? 'manual',
        confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
        status: json['status'] as String? ?? 'approved',
        externalId: json['external_calendar_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'location': location,
        'attendees': attendees,
        'source': source,
        'confidence_score': confidenceScore,
        'status': status,
        'external_calendar_id': externalId,
      };
}
