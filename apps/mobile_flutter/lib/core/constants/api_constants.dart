import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    return 'http://10.0.2.2:3000';
  }

  // Auth endpoints
  static String get register => '$baseUrl/auth/register';
  static String get login => '$baseUrl/auth/login';
  static String get refresh => '$baseUrl/auth/refresh';
  static String get logout => '$baseUrl/auth/logout';

  // User endpoints
  static String get userMe => '$baseUrl/users/me';

  // Circles endpoints
  static String get circles => '$baseUrl/circles';
  static String circleById(int id) => '$baseUrl/circles/$id';
  static String circleInvite(int id) => '$baseUrl/circles/$id/invite';
  static String get circleJoin => '$baseUrl/circles/join';

  // Circle messages
  static String circleMessages(int circleId) =>
      '$baseUrl/circles/$circleId/messages';

  // Links endpoints
  static String get links => '$baseUrl/links';
  static String get linkSearch => '$baseUrl/links/search';
  static String get linkRequests => '$baseUrl/links/requests';
  static String get incomingLinkRequests =>
      '$baseUrl/links/requests/incoming';
  static String get outgoingLinkRequests =>
      '$baseUrl/links/requests/outgoing';
  static String linkRequestById(int requestId) =>
      '$baseUrl/links/requests/$requestId';
  static String linkByUserId(int userId) => '$baseUrl/links/$userId';

  // Direct conversations / direct messages
  static String get directConversations => '$baseUrl/direct-conversations';
  static String directConversationMessages(int conversationId) =>
      '$baseUrl/direct-conversations/$conversationId/messages';

  // Uploads
  static String get uploadRequest => '$baseUrl/uploads/request';

  // WebSocket
  static String get socketUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    return 'http://10.0.2.2:3000';
  }
}