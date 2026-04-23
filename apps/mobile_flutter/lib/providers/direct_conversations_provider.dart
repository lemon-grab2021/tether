import 'package:flutter/material.dart';
import '../data/models/direct_conversation.dart';
import '../data/services/auth_service.dart';
import '../data/services/direct_messages_service.dart';


class DirectConversationsProvider extends ChangeNotifier {
  final DirectMessagesService _directMessagesService = DirectMessagesService();
  final AuthService _authService = AuthService();

  List<DirectConversation> _conversations = [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  String? _error;

  List<DirectConversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;
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
      _hasLoadedOnce = true;
    } catch (e) {
      _error = e.toString();
      _hasLoadedOnce = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshConversationsSilently({
    required int currentUserId,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) return;

      final newConversations = await _directMessagesService.getConversations(
        token: token,
        currentUserId: currentUserId,
      );

      _conversations = newConversations;
      _error = null;
      _hasLoadedOnce = true;
      notifyListeners();
    } catch (_) {
      // Keep current conversations visible during background refresh
    }
  }

  Future<void> deleteConversation({
    required int conversationId,
    required String token,
    required int currentUserId,
  }) async {
    await _directMessagesService.deleteConversation(
      token: token,
      conversationId: conversationId,
    );

    conversations.removeWhere((c) => c.id == conversationId);
    notifyListeners();

    await loadConversations(currentUserId: currentUserId);
  }

  Future<void> restoreConversation({
    required int conversationId,
    required String token,
    required int currentUserId,
  }) async {
    await _directMessagesService.restoreConversation(
      token: token,
      conversationId: conversationId,
    );

    await loadConversations(currentUserId: currentUserId);
  }

  void clear() {
    _conversations = [];
    _error = null;
    _isLoading = false;
    _hasLoadedOnce = false;
    notifyListeners();
  }
}
