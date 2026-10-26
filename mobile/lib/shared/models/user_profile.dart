class ContactContext {
  final String name;
  final String relationship;
  final String notes;

  const ContactContext({
    required this.name,
    required this.relationship,
    this.notes = '',
  });

  factory ContactContext.fromJson(Map<String, dynamic> json) => ContactContext(
        name: json['name'] as String? ?? '',
        relationship: json['relationship'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'relationship': relationship,
        'notes': notes,
      };
}

class UserProfile {
  final String fullName;
  final String workplace;
  final String homeLocation;
  final String workLocation;
  final String role;
  final String goals;
  final String healthGoals;
  final String wakeTime;
  final String sleepTime;
  final String anthropicApiKey;
  final List<ContactContext> importantContacts;

  const UserProfile({
    this.fullName = '',
    this.workplace = '',
    this.homeLocation = '',
    this.workLocation = '',
    this.role = '',
    this.goals = '',
    this.healthGoals = '',
    this.wakeTime = '07:00',
    this.sleepTime = '23:00',
    this.anthropicApiKey = '',
    this.importantContacts = const [],
  });

  UserProfile copyWith({
    String? fullName,
    String? workplace,
    String? homeLocation,
    String? workLocation,
    String? role,
    String? goals,
    String? healthGoals,
    String? wakeTime,
    String? sleepTime,
    String? anthropicApiKey,
    List<ContactContext>? importantContacts,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      workplace: workplace ?? this.workplace,
      homeLocation: homeLocation ?? this.homeLocation,
      workLocation: workLocation ?? this.workLocation,
      role: role ?? this.role,
      goals: goals ?? this.goals,
      healthGoals: healthGoals ?? this.healthGoals,
      wakeTime: wakeTime ?? this.wakeTime,
      sleepTime: sleepTime ?? this.sleepTime,
      anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
      importantContacts: importantContacts ?? this.importantContacts,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        fullName: json['full_name'] as String? ?? '',
        workplace: json['workplace'] as String? ?? '',
        homeLocation: json['home_location'] as String? ?? '',
        workLocation: json['work_location'] as String? ?? '',
        role: json['role'] as String? ?? '',
        goals: json['goals'] as String? ?? '',
        healthGoals: json['health_goals'] as String? ?? '',
        wakeTime: json['wake_time'] as String? ?? '07:00',
        sleepTime: json['sleep_time'] as String? ?? '23:00',
        anthropicApiKey: json['anthropic_api_key'] as String? ?? '',
        importantContacts: (json['important_contacts'] as List<dynamic>?)
                ?.map((c) => ContactContext.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'workplace': workplace,
        'home_location': homeLocation,
        'work_location': workLocation,
        'role': role,
        'goals': goals,
        'health_goals': healthGoals,
        'wake_time': wakeTime,
        'sleep_time': sleepTime,
        'anthropic_api_key': anthropicApiKey,
        'important_contacts': importantContacts.map((c) => c.toJson()).toList(),
      };
}
