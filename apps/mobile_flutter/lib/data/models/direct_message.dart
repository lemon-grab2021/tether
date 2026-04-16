import 'user.dart';

class DirectMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final String? body;
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final User? sender;

  DirectMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.body,
    this.mediaUrl,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
    this.sender,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      conversationId: json['conversationId'] is int
          ? json['conversationId']
          : int.parse(json['conversationId'].toString()),
      senderId: json['senderId'] is int
          ? json['senderId']
          : int.parse(json['senderId'].toString()),
      body: json['body']?.toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      createdAt: DateTime.parse(json['createdAt'].toString()),
      editedAt: json['editedAt'] != null
          ? DateTime.parse(json['editedAt'].toString())
          : null,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'].toString())
          : null,
      sender: json['sender'] != null
          ? User.fromJson(Map<String, dynamic>.from(json['sender']))
          : null,
    );
  }
}