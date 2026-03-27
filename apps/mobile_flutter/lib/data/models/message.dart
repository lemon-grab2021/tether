import 'user.dart';

class Message {
  final int id;
  final int circleId;
  final int senderId;
  final String? body;
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final User? sender;

  Message({
    required this.id,
    required this.circleId,
    required this.senderId,
    this.body,
    this.mediaUrl,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.sender,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      circleId: json['circleId'],
      senderId: json['senderId'],
      body: json['body'],
      mediaUrl: json['mediaUrl'],
      createdAt: DateTime.parse(json['createdAt']),
      editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt']) : null,
      deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt']) : null,
      sender: json['sender'] != null ? User.fromJson(json['sender']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'circleId': circleId,
      'senderId': senderId,
      'body': body,
      'mediaUrl': mediaUrl,
      'createdAt': createdAt.toIso8601String(),
      'editedAt': editedAt?.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }
}