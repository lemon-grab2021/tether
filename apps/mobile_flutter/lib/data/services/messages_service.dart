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
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };
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

  // Send message via REST (not WebSocket)
  Future<Message> sendMessage({
    required String token,
    required int circleId,
    String? body,
    String? mediaUrl,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.circleMessages(circleId)),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'body': body,
        'mediaUrl': mediaUrl,
      }),
    );

    if (response.statusCode == 201) {
      return Message.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to send message');
    }
  }
}