import 'package:flutter/material.dart';
import '../data/models/direct_conversation.dart';
import '../data/services/auth_service.dart';
import '../data/services/direct_messages_service.dart';

class DirectConversationsProvider extends ChangeNotifier {
  final DirectMessagesService _directMessagesService = DirectMessagesService();
  final AuthService _authService = AuthService();

  List<DirectConversation> _conversations = [];
  bool _isLoading = false;
  String? _error;

  List<DirectConversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadConversations({required int currentUserId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      _conversations = await _directMessagesService.getConversations(
        token: token,
        currentUserId: currentUserId,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _conversations = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}