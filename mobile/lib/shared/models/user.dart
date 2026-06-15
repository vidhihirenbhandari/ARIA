class User {
  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final String assistantName;
  final DateTime createdAt;
  final bool onboardingComplete;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    this.assistantName = 'ARIA',
    required this.createdAt,
    this.onboardingComplete = false,
  });

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? photoUrl,
    String? assistantName,
    DateTime? createdAt,
    bool? onboardingComplete,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      assistantName: assistantName ?? this.assistantName,
      createdAt: createdAt ?? this.createdAt,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'photoUrl': photoUrl,
    'assistantName': assistantName,
    'createdAt': createdAt.toIso8601String(),
    'onboardingComplete': onboardingComplete,
  };

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String,
    photoUrl: json['photoUrl'] as String?,
    assistantName: json['assistantName'] as String? ?? 'ARIA',
    createdAt: DateTime.parse(json['createdAt'] as String),
    onboardingComplete: json['onboardingComplete'] as bool? ?? false,
  );
}
