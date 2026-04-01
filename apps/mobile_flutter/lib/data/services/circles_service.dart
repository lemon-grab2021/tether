import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../models/circle.dart';

class CirclesService {

  // Get user's circles
  Future<List<Circle>> getUserCircles(String token) async {
    final response = await http.get(
      Uri.parse(ApiConstants.circles),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Circle.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load circles');
    }
  }

  // Create circle
  Future<Circle> createCircle({
    required String token,
    required String name,
    String? description,
    bool isPrivate = true,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.circles),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'description': description,
        'isPrivate': isPrivate,
      }),
    );

    if (response.statusCode == 201) {
      return Circle.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to create circle');
    }
  }

  // Join circle via invite code
  Future<Circle> joinCircle({
    required String token,
    required String inviteCode,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConstants.circleJoin),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'inviteCode': inviteCode}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Circle.fromJson(jsonDecode(response.body));
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to join circle');
    }
  }

  // Get circle details
  Future<Circle> getCircle({
    required String token,
    required int circleId,
  }) async {
    final response = await http.get(
      Uri.parse(ApiConstants.circleById(circleId)),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return Circle.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load circle');
    }
  }
}