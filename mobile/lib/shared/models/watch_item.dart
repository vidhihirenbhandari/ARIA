enum WatchType { flight, deadline, price, subscription, custom }

class WatchItem {
  final String id;
  final String title;
  final String? detail;
  final WatchType type;
  final DateTime? alertDate;
  final String? status;
  final bool isResolved;
  final DateTime createdAt;

  const WatchItem({
    required this.id,
    required this.title,
    this.detail,
    required this.type,
    this.alertDate,
    this.status,
    this.isResolved = false,
    required this.createdAt,
  });

  WatchItem copyWith({
    String? id,
    String? title,
    String? detail,
    WatchType? type,
    DateTime? alertDate,
    String? status,
    bool? isResolved,
    DateTime? createdAt,
  }) {
    return WatchItem(
      id: id ?? this.id,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      type: type ?? this.type,
      alertDate: alertDate ?? this.alertDate,
      status: status ?? this.status,
      isResolved: isResolved ?? this.isResolved,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'detail': detail,
        'type': type.name,
        'alertDate': alertDate?.toIso8601String(),
        'status': status,
        'isResolved': isResolved,
        'createdAt': createdAt.toIso8601String(),
      };

  factory WatchItem.fromJson(Map<String, dynamic> json) => WatchItem(
        id: json['id'] as String,
        title: json['title'] as String,
        detail: json['detail'] as String?,
        type: WatchType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => WatchType.custom,
        ),
        alertDate: json['alertDate'] != null
            ? DateTime.tryParse(json['alertDate'] as String)
            : null,
        status: json['status'] as String?,
        isResolved: json['isResolved'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
