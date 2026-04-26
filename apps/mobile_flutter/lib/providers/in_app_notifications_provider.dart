import 'package:flutter/material.dart';
import '../data/models/in_app_notification.dart';

class InAppNotificationsProvider extends ChangeNotifier {
  final List<InAppNotification> _notifications = [];

  int? _activeDirectConversationId;
  int? _activeCircleId;

  List<InAppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount =>
      _notifications.where((notification) => !notification.read).length;

  bool get hasUnread => unreadCount > 0;

  void setActiveDirectConversation(int? conversationId) {
    _activeDirectConversationId = conversationId;
  }

  void setActiveCircle(int? circleId) {
    _activeCircleId = circleId;
  }

  void addNotification(InAppNotification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  void notifyDirectMessage({
    required int conversationId,
    required int senderId,
    required int currentUserId,
    required String senderName,
    required String messagePreview,
  }) {
    if (senderId == currentUserId) return;

    // Do not show a notification if the user is already inside that DM.
    if (_activeDirectConversationId == conversationId) return;

    addNotification(
      InAppNotification(
        id: 'dm-$conversationId-${DateTime.now().millisecondsSinceEpoch}',
        type: InAppNotificationType.directMessage,
        title: senderName,
        body: messagePreview.isEmpty ? 'Sent an attachment' : messagePreview,
        createdAt: DateTime.now(),
        directConversationId: conversationId,
        senderId: senderId,
      ),
    );
  }

  void notifyCircleMessage({
    required int circleId,
    required int senderId,
    required int currentUserId,
    required String circleName,
    required String senderName,
    required String messagePreview,
  }) {
    if (senderId == currentUserId) return;

    // Do'nt show a notification if the user is already in the chat.
    if (_activeCircleId == circleId) return;

    addNotification(
      InAppNotification(
        id: 'circle-$circleId-${DateTime.now().millisecondsSinceEpoch}',
        type: InAppNotificationType.circleMessage,
        title: circleName,
        body: '$senderName: ${messagePreview.isEmpty ? 'Sent an attachment' : messagePreview}',
        createdAt: DateTime.now(),
        circleId: circleId,
        senderId: senderId,
      ),
    );
  }

  void notifyLinkRequest({
    required int senderId,
    required String senderName,
  }) {
    addNotification(
      InAppNotification(
        id: 'link-$senderId-${DateTime.now().millisecondsSinceEpoch}',
        type: InAppNotificationType.linkRequest,
        title: 'New link request',
        body: '$senderName wants to link with you',
        createdAt: DateTime.now(),
        senderId: senderId,
      ),
    );
  }

  void markAsRead(String notificationId) {
    final index = _notifications.indexWhere((item) => item.id == notificationId);
    if (index == -1) return;

    _notifications[index] = _notifications[index].copyWith(read: true);
    notifyListeners();
  }

  void markAllAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(read: true);
    }
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }
}