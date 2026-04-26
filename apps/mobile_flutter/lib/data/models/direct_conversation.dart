import 'user.dart';
import 'direct_message.dart';

class DirectConversation {
  final int id;
  final User otherUser;
  final DirectMessage? lastMessage;
  final DateTime lastMessageAt;
  final DateTime createdAt;
  final int? userOneId;
  final int? userTwoId;
  final DateTime? userOneLastReadAt;
  final DateTime? userTwoLastReadAt;
 

  // we need currentUserId to determine which user in the conversation is the "other" user.
  DirectConversation({
    required this.id,
    required this.otherUser,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.createdAt,
    this.userOneLastReadAt,
    this.userTwoLastReadAt,
    this.userOneId,
    this.userTwoId,
  });

  factory DirectConversation.fromJson(
    Map<String, dynamic> json,
    int currentUserId,
  ) {
    final userOne = User.fromJson(Map<String, dynamic>.from(json['userOne']));
    final userTwo = User.fromJson(Map<String, dynamic>.from(json['userTwo']));

    final otherUser = userOne.id == currentUserId ? userTwo : userOne;

    final messages = json['messages'] as List<dynamic>? ?? [];

    // We assume messages are ordered by createdAt descending, so the first message is the last message in the conversation.
    return DirectConversation(
      id: json['id'],
      otherUser: otherUser,
      createdAt: DateTime.parse(json['createdAt']),
      lastMessage: messages.isNotEmpty
          ? DirectMessage.fromJson(Map<String, dynamic>.from(messages.first))
          : null,
      lastMessageAt: DateTime.parse(json['lastMessageAt'].toString()),
      userOneLastReadAt: json['userOneLastReadAt'] != null
          ? DateTime.parse(json['userOneLastReadAt'].toString())
          : null,
      userTwoLastReadAt: json['userTwoLastReadAt'] != null
          ? DateTime.parse(json['userTwoLastReadAt'].toString())
          : null,
      userOneId: json['userOneId'],
      userTwoId: json['userTwoId'],
      
    );
  }
}
