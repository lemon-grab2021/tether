import 'dart:async';
import 'package:flutter/material.dart';

import '../data/models/tether_notification.dart';
import '../data/services/notifications_service.dart';

class NotificationsProvider extends ChangeNotifier {
  final NotificationsService _service = NotificationsService();

  List<TetherNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;
  Timer? _pollingTimer;

  List<TetherNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadNotifications({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final results = await _service.getNotifications();
      final count = await _service.getUnreadCount();

      _notifications = results;
      _unreadCount = count;
      _error = null;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _service.getUnreadCount();
      notifyListeners();
    } catch (_) {
      // Keep UI stable if count refresh fails.
    }
  }

  Future<void> markAsRead(int notificationId) async {
    await _service.markAsRead(notificationId);

    final index = _notifications.indexWhere((n) => n.id == notificationId);

    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(
        readAt: DateTime.now(),
      );

      if (_unreadCount > 0) {
        _unreadCount--;
      }

      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    await _service.markAllAsRead();

    _notifications = _notifications
        .map((notification) => notification.isRead
            ? notification
            : notification.copyWith(readAt: DateTime.now()))
        .toList();

    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> deleteNotification(int notificationId) async {
    await _service.deleteNotification(notificationId);

    final removed = _notifications.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => _notifications.first,
    );

    _notifications.removeWhere((n) => n.id == notificationId);

    if (!removed.isRead && _unreadCount > 0) {
      _unreadCount--;
    }

    notifyListeners();
  }

  void startPolling() {
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      loadNotifications(silent: true);
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}