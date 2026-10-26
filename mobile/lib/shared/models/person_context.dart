class PersonContext {
  final String id;
  final String name;
  final String relationship; // 'colleague', 'friend', 'family', 'client', 'vendor', 'other'
  final String? phone;
  final String? email;
  final String notes;
  final String preferences;
  final DateTime? lastContact;
  final DateTime? followUpDate;
  final String? followUpNote;
  final DateTime createdAt;

  const PersonContext({
    required this.id,
    required this.name,
    this.relationship = 'other',
    this.phone,
    this.email,
    this.notes = '',
    this.preferences = '',
    this.lastContact,
    this.followUpDate,
    this.followUpNote,
    required this.createdAt,
  });

  PersonContext copyWith({
    String? id,
    String? name,
    String? relationship,
    String? phone,
    String? email,
    String? notes,
    String? preferences,
    DateTime? lastContact,
    DateTime? followUpDate,
    String? followUpNote,
    DateTime? createdAt,
  }) {
    return PersonContext(
      id: id ?? this.id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      preferences: preferences ?? this.preferences,
      lastContact: lastContact ?? this.lastContact,
      followUpDate: followUpDate ?? this.followUpDate,
      followUpNote: followUpNote ?? this.followUpNote,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'relationship': relationship,
        'phone': phone,
        'email': email,
        'notes': notes,
        'preferences': preferences,
        'last_contact': lastContact?.toIso8601String(),
        'follow_up_date': followUpDate?.toIso8601String(),
        'follow_up_note': followUpNote,
        'created_at': createdAt.toIso8601String(),
      };

  factory PersonContext.fromJson(Map<String, dynamic> json) => PersonContext(
        id: json['id'] as String,
        name: json['name'] as String,
        relationship: json['relationship'] as String? ?? 'other',
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        notes: json['notes'] as String? ?? '',
        preferences: json['preferences'] as String? ?? '',
        lastContact: json['last_contact'] != null
            ? DateTime.parse(json['last_contact'] as String)
            : null,
        followUpDate: json['follow_up_date'] != null
            ? DateTime.parse(json['follow_up_date'] as String)
            : null,
        followUpNote: json['follow_up_note'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
      );
}
