class TetherNotification {
  final int id;
  final int userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? metadata;
  final DateTime? readAt;
  final DateTime createdAt;

  const TetherNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.metadata,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory TetherNotification.fromJson(Map<String, dynamic> json) {
    return TetherNotification(
      id: json['id'] as int,
      userId: json['userId'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      metadata: json['metadata'] == null
          ? null
          : Map<String, dynamic>.from(json['metadata'] as Map),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  TetherNotification copyWith({
    DateTime? readAt,
  }) {
    return TetherNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      body: body,
      metadata: metadata,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}