import 'user.dart';
import 'direct_message.dart';

class DirectConversation {
  final int id;
  final User otherUser;
  final DirectMessage? lastMessage;
  final DateTime lastMessageAt;

  // we need currentUserId to determine which user in the conversation is the "other" user.
  DirectConversation({
    required this.id,
    required this.otherUser,
    required this.lastMessage,
    required this.lastMessageAt,
  });

  factory DirectConversation.fromJson(Map<String, dynamic> json, int currentUserId) {
    final userOne = User.fromJson(Map<String, dynamic>.from(json['userOne']));
    final userTwo = User.fromJson(Map<String, dynamic>.from(json['userTwo']));

    final otherUser = userOne.id == currentUserId ? userTwo : userOne;

    final messages = json['messages'] as List<dynamic>? ?? [];
  
  // We assume messages are ordered by createdAt descending, so the first message is the last message in the conversation.
    return DirectConversation(
      id: json['id'],
      otherUser: otherUser,
      lastMessage: messages.isNotEmpty
          ? DirectMessage.fromJson(Map<String, dynamic>.from(messages.first))
          : null,
      lastMessageAt: DateTime.parse(json['lastMessageAt'].toString()),
    );
  }
}