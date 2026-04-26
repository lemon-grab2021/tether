import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/message.dart';

class MessagesService {
  // Get messages for a circle
  Future<List<Message>> getMessages({
    required String token,
    required int circleId,
    int? cursor,
    int limit = 50,
  }) async {
    var uri = Uri.parse(ApiConstants.circleMessages(circleId));

    // Add query parameters
    final queryParams = <String, String>{'limit': limit.toString()};
    if (cursor != null) {
      queryParams['cursor'] = cursor.toString();
    }

    uri = uri.replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load messages');
    }
  }

  // Edit Message
  Future<Message> editMessage({
    required String token,
    required int circleId,
    required int messageId,
    required String body,
  }) async {
    final response = await http.patch(
      Uri.parse(
        '${ApiConstants.baseUrl}/circles/$circleId/messages/$messageId',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'body': body}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to edit message');
    }

    return Message.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body)),
    );
  }

  // Delete Message
  Future<Message> deleteMessage({
    required String token,
    required int circleId,
    required int messageId,
  }) async {
    final response = await http.delete(
      Uri.parse(
        '${ApiConstants.baseUrl}/circles/$circleId/messages/$messageId',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to delete message');
    }

    return Message.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body)),
    );
  }

  // Send message 
  Future<Message> sendMessage({
    required String token,
    required int circleId,
    String? body,
    String? mediaUrl,
  }) async {
    final payload = <String, dynamic>{};

    final trimmedBody = body?.trim();
    final trimmedMediaUrl = mediaUrl?.trim();

    if (trimmedBody != null && trimmedBody.isNotEmpty) {
      payload['body'] = trimmedBody;
    }

    if (trimmedMediaUrl != null && trimmedMediaUrl.isNotEmpty) {
      payload['mediaUrl'] = trimmedMediaUrl;
    }

    if (payload.isEmpty) {
      throw Exception('Message cannot be empty');
    }

    final response = await http.post(
      Uri.parse(ApiConstants.circleMessages(circleId)),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to send message');
      } catch (_) {
        throw Exception('Failed to send message: ${response.body}');
      }
    }

    return Message.fromJson(
      Map<String, dynamic>.from(jsonDecode(response.body)),
    );
  }
}
