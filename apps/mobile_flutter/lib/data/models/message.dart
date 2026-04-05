import 'user.dart';

class Message {
  final int id;
  final int circleId;
  final int senderId;
  final String? body;
  final String? mediaUrl;
  final DateTime createdAt; // can't be null because server will set it to current time if not provided
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
    // ignore: avoid_print
    print('Raw message JSON: $json'); // Debugging line
    
    return Message(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()), // Handle both int and string IDs
      circleId: json['circleId'] is int ? json['circleId'] : int.parse(json['circleId'].toString()),
      senderId: json['senderId'] is int ? json['senderId'] : int.parse(json['senderId'].toString()),
      body: json['body']?.toString(),
      mediaUrl: json['mediaUrl']?.toString(),
      createdAt:json['createdAt'] != null ? DateTime.parse(json['createdAt'].toString()) : DateTime.now(),
      editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt'].toString()) : null,
      deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt'].toString()) : null,
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