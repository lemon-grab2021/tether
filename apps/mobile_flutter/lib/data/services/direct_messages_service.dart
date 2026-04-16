import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/direct_conversation.dart';
import '../models/direct_message.dart';
import '../../core/constants/api_constants.dart';

class DirectMessagesService {
  Future<DirectConversation> createOrGetConversation({
    required String token,
    required int otherUserId,
    required int currentUserId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/direct-conversations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'otherUserId': otherUserId}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to create direct conversation');
    }

    final data = jsonDecode(response.body);
    return DirectConversation.fromJson(data, currentUserId);
  }

  Future<List<DirectConversation>> getConversations({
    required String token,
    required int currentUserId,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/direct-conversations'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load direct conversations');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => DirectConversation.fromJson(Map<String, dynamic>.from(e), currentUserId))
        .toList();
  }

  Future<List<DirectMessage>> getMessages({
    required String token,
    required int conversationId,
    int? cursor,
  }) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/direct-conversations/$conversationId/messages'
      '${cursor != null ? '?cursor=$cursor' : ''}',
    );

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load direct messages');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => DirectMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}