enum EventSource { google, apple, outlook, whatsapp, email, slack, manual }

enum EventStatus { pending, approved, rejected, confirmed }

class CalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? description;
  final List<String> attendees;
  final EventSource source;
  final EventStatus status;
  final double? confidence;
  final bool isAllDay;
  final String? meetingLink;
  final DateTime createdAt;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.location,
    this.description,
    this.attendees = const [],
    required this.source,
    this.status = EventStatus.confirmed,
    this.confidence,
    this.isAllDay = false,
    this.meetingLink,
    required this.createdAt,
  });

  bool get isPending => status == EventStatus.pending;
  bool get isApproved => status == EventStatus.approved;
  Duration get duration => endTime.difference(startTime);

  CalendarEvent copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? description,
    List<String>? attendees,
    EventSource? source,
    EventStatus? status,
    double? confidence,
    bool? isAllDay,
    String? meetingLink,
    DateTime? createdAt,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      description: description ?? this.description,
      attendees: attendees ?? this.attendees,
      source: source ?? this.source,
      status: status ?? this.status,
      confidence: confidence ?? this.confidence,
      isAllDay: isAllDay ?? this.isAllDay,
      meetingLink: meetingLink ?? this.meetingLink,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'location': location,
    'description': description,
    'attendees': attendees,
    'source': source.name,
    'status': status.name,
    'confidence': confidence,
    'isAllDay': isAllDay,
    'meetingLink': meetingLink,
    'createdAt': createdAt.toIso8601String(),
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    location: json['location'] as String?,
    description: json['description'] as String?,
    attendees: (json['attendees'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    source: EventSource.values.firstWhere(
      (e) => e.name == json['source'],
      orElse: () => EventSource.manual,
    ),
    status: EventStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => EventStatus.confirmed,
    ),
    confidence: (json['confidence'] as num?)?.toDouble(),
    isAllDay: json['isAllDay'] as bool? ?? false,
    meetingLink: json['meetingLink'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
