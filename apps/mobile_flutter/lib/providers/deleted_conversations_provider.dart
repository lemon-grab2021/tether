import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/models/circle.dart';
import '../data/models/direct_conversation.dart';

enum DeletedConversationType { direct, circle }

class DeletedConversationMember {
  final String name;
  final String? avatarUrl;

  const DeletedConversationMember({
    required this.name,
    this.avatarUrl,
  });
}

class DeletedConversationEntry {
  final String deletedId;
  final DeletedConversationType type;
  final int sourceId;
  final String name;
  final String preview;
  final String? avatarUrl;
  final List<DeletedConversationMember> members;
  final DateTime deletedAt;

  const DeletedConversationEntry({
    required this.deletedId,
    required this.type,
    required this.sourceId,
    required this.name,
    required this.preview,
    required this.deletedAt,
    this.avatarUrl,
    this.members = const [],
  });

  int get daysRemaining {
    final elapsedDays = DateTime.now().difference(deletedAt).inDays;
    return max(0, 30 - elapsedDays);
  }

  bool get isExpired => daysRemaining <= 0;
}

class DeletedConversationsProvider extends ChangeNotifier {
  final List<DeletedConversationEntry> _items = [];

  List<DeletedConversationEntry> get items {
    final copy = [..._items];
    copy.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
    return copy;
  }

  bool isDirectConversationDeleted(int conversationId) {
    return _items.any(
      (item) =>
          item.type == DeletedConversationType.direct &&
          item.sourceId == conversationId,
    );
  }

  bool isCircleDeleted(int circleId) {
    return _items.any(
      (item) =>
          item.type == DeletedConversationType.circle &&
          item.sourceId == circleId,
    );
  }

  void softDeleteDirectConversation(DirectConversation conversation) {
    if (isDirectConversationDeleted(conversation.id)) return;

    final otherUser = conversation.otherUser;
    final displayName =
        (otherUser.displayName != null &&
                otherUser.displayName!.trim().isNotEmpty)
            ? otherUser.displayName!.trim()
            : otherUser.username;

    final preview = conversation.lastMessage?.body?.trim().isNotEmpty == true
        ? conversation.lastMessage!.body!
        : conversation.lastMessage?.mediaUrl != null
            ? 'Sent an attachment'
            : 'Start your conversation';

    _items.insert(
      0,
      DeletedConversationEntry(
        deletedId: 'dm_${conversation.id}_${DateTime.now().millisecondsSinceEpoch}',
        type: DeletedConversationType.direct,
        sourceId: conversation.id,
        name: displayName,
        preview: preview,
        avatarUrl: otherUser.avatarUrl,
        deletedAt: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  void softDeleteCircle(Circle circle) {
    if (isCircleDeleted(circle.id)) return;

    final preview =
        (circle.description != null && circle.description!.trim().isNotEmpty)
            ? circle.description!.trim()
            : 'Circle conversation';

    final members = (circle.members ?? [])
        .where((m) => m.user != null)
        .map(
          (m) => DeletedConversationMember(
            name: m.user!.displayName,
            avatarUrl: m.user!.avatarUrl,
          ),
        )
        .toList();

    _items.insert(
      0,
      DeletedConversationEntry(
        deletedId:
            'circle_${circle.id}_${DateTime.now().millisecondsSinceEpoch}',
        type: DeletedConversationType.circle,
        sourceId: circle.id,
        name: circle.name,
        preview: preview,
        members: members,
        deletedAt: DateTime.now(),
      ),
    );

    notifyListeners();
  }

  void restoreConversation(String deletedId) {
    _items.removeWhere((item) => item.deletedId == deletedId);
    notifyListeners();
  }

  void permanentlyDeleteConversation(String deletedId) {
    _items.removeWhere((item) => item.deletedId == deletedId);
    notifyListeners();
  }

  void purgeExpired() {
    _items.removeWhere((item) => item.isExpired);
    notifyListeners();
  }
}