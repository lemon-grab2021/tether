import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/tether_notification.dart';
import '../../core/constants/api_constants.dart';
import 'auth_service.dart';

class NotificationsService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getAccessToken();

    if (token == null) {
      throw Exception('No access token found');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<TetherNotification>> getNotifications({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    final uri = Uri.parse(ApiConstants.notifications).replace(
      queryParameters: {
        'unreadOnly': unreadOnly.toString(),
        'limit': limit.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load notifications');
    }

    final data = jsonDecode(response.body) as List;

    return data
        .map((item) => TetherNotification.fromJson(item))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final response = await http.get(
      Uri.parse(ApiConstants.notificationUnreadCount),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load unread notification count');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['count'] as int;
  }

  Future<void> markAsRead(int notificationId) async {
    final response = await http.patch(
      Uri.parse(ApiConstants.notificationRead(notificationId)),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }

  Future<void> markAllAsRead() async {
    final response = await http.patch(
      Uri.parse(ApiConstants.notificationsReadAll),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark all notifications as read');
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    final response = await http.delete(
      Uri.parse(ApiConstants.notificationDelete(notificationId)),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete notification');
    }
  }
}