import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tether/data/models/link_search_result.dart';
import '../../core/constants/api_constants.dart';
import '../models/link.dart';
import '../models/link_request.dart';

class LinksService {
  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Future<List<LinkSearchResult>> searchUsers({
    required String token,
    required String query,
  }) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}/links/search',
    ).replace(queryParameters: {'q': query.trim()});

    final response = await http.get(uri, headers: _headers(token));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to search users');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => LinkSearchResult.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> sendRequest({
    required String token,
    required int receiverId,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/links/requests'),
      headers: _headers(token),
      body: jsonEncode({'receiverId': receiverId}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to send link request');
    }
  }

  Future<List<LinkRequestModel>> getIncomingRequests({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/links/requests/incoming'),
      headers: _headers(token),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load incoming requests');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => LinkRequestModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<LinkRequestModel>> getOutgoingRequests({
    required String token,
  }) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/links/requests/outgoing'),
      headers: _headers(token),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load outgoing requests');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => LinkRequestModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> respondToRequest({
    required String token,
    required int requestId,
    required String action,
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConstants.baseUrl}/links/requests/$requestId'),
      headers: _headers(token),
      body: jsonEncode({'action': action}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to respond to request');
    }
  }

  Future<List<LinkModel>> getLinks({required String token}) async {
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}/links'),
      headers: _headers(token),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load links');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => LinkModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> removeLink({
    required String token,
    required int otherUserId,
  }) async {
    final response = await http.delete(
      Uri.parse('${ApiConstants.baseUrl}/links/$otherUserId'),
      headers: _headers(token),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to remove link');
    }
  }
}
