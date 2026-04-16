import 'package:flutter/material.dart';
import '../data/models/circle.dart';
import '../data/services/circles_service.dart';
import '../data/services/auth_service.dart';

class CirclesProvider extends ChangeNotifier {
  final CirclesService _circlesService = CirclesService();
  final AuthService _authService = AuthService();

  List<Circle> _circles = [];
  bool _isLoading = false;
  String? _error;

  List<Circle> get circles => _circles;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load user's circles
  Future<void> loadCircles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      _circles = await _circlesService.getUserCircles(token);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create circle
  Future<Circle> createCircle({
    required String name,
    String? description,
    bool isPrivate = true,
  }) async {
    final token = await _authService.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final circle = await _circlesService.createCircle(
      token: token,
      name: name,
      description: description,
      isPrivate: isPrivate,
    );

    // Add to local list
    _circles.insert(0, circle);
    notifyListeners();

    return circle;
  }

  // Join circle
  Future<Circle> joinCircle(String inviteCode) async {
    final token = await _authService.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final circle = await _circlesService.joinCircle(
      token: token,
      inviteCode: inviteCode,
    );

    // Add to local list if not already there
    if (!_circles.any((c) => c.id == circle.id)) {
      _circles.insert(0, circle);
      notifyListeners();
    }

    return circle;
  }


  Future<void> refreshCirclesSilently() async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) return;

      final newCircles = await _circlesService.getUserCircles(token);
      _circles = newCircles;
      _error = null;
      notifyListeners();
    } catch (_) {
      // keep old circles on screen during background refresh
    }
  }
}
