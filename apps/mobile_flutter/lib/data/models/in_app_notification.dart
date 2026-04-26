enum InAppNotificationType {
  directMessage,
  circleMessage,
  linkRequest,
  system,
}

class InAppNotification {
  final String id;
  final InAppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  final int? directConversationId;
  final int? circleId;
  final int? senderId;

  const InAppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
    this.directConversationId,
    this.circleId,
    this.senderId,
  });

  InAppNotification copyWith({
    bool? read,
  }) {
    return InAppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      read: read ?? this.read,
      directConversationId: directConversationId,
      circleId: circleId,
      senderId: senderId,
    );
  }
}