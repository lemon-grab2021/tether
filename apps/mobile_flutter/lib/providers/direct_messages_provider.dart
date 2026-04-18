import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants/api_constants.dart';
import '../data/models/direct_conversation.dart';
import '../data/models/direct_message.dart';
import '../data/services/auth_service.dart';
import '../data/services/direct_messages_service.dart';

class DirectMessagesProvider extends ChangeNotifier {
  final DirectMessagesService _service = DirectMessagesService();
  final AuthService _authService = AuthService();

  IO.Socket? _socket;
  List<DirectMessage> _messages = [];
  DirectConversation? _conversation;

  bool _isLoading = false;
  bool _isConnected = false;
  bool _isJoinedRoom = false;
  String? _error;

  List<DirectMessage> get messages => _messages;
  DirectConversation? get conversation => _conversation;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  bool get isJoinedRoom => _isJoinedRoom;
  String? get error => _error;

  Future<void> loadMessages(int conversationId, {int? cursor}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _authService.getAccessToken();
      if (token == null) throw Exception('Not authenticated');

      final fetched = await _service.getMessages(
        token: token,
        conversationId: conversationId,
        cursor: cursor,
      );

      fetched.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (cursor == null) {
        _messages = fetched;
      } else {
        _messages.addAll(fetched);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshMessagesSilently(int conversationId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) return;

      final fetched = await _service.getMessages(
        token: token,
        conversationId: conversationId,
      );

      fetched.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _messages = fetched;
      _error = null;
      notifyListeners();
    } catch (_) {
      // keep current UI stable
    }
  }

  Future<void> loadConversation({
    required int conversationId,
    required int currentUserId,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) return;

      _conversation = await _service.getConversationById(
        token: token,
        conversationId: conversationId,
        currentUserId: currentUserId,
      );
      notifyListeners();
    } catch (_) {
      // Don't replace whole screen with error
    }
  }

  Future<void> refreshConversationSilently({
    required int conversationId,
    required int currentUserId,
  }) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) return;

      final refreshed = await _service.getConversationById(
        token: token,
        conversationId: conversationId,
        currentUserId: currentUserId,
      );

      _conversation = refreshed;
      _error = null;
      notifyListeners();
    } catch (_) {
      // keep current UI stable
    }
  }

  Future<void> markConversationAsRead(int conversationId) async {
    final token = await _authService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    await _service.markConversationAsRead(
      token: token,
      conversationId: conversationId,
    );
  }

  Future<void> markConversationAsReadSilently(int conversationId) async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) return;

      await _service.markConversationAsRead(
        token: token,
        conversationId: conversationId,
      );
    } catch (_) {
      // ignore background errors
    }
  }

  Future<void> connectToConversation({
    required int conversationId,
    required int currentUserId,
  }) async {
    final token = await _authService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    disconnect();

    _socket = IO.io(
      ApiConstants.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      _isJoinedRoom = false;
      notifyListeners();

      _socket!.emit('direct:join', {'conversationId': conversationId});
    });

    _socket!.on('direct:joined', (_) async {
      _isJoinedRoom = true;
      notifyListeners();

      await markConversationAsReadSilently(conversationId);
      _socket!.emit('direct:read', {'conversationId': conversationId});

      await refreshConversationSilently(
        conversationId: conversationId,
        currentUserId: currentUserId,
      );
    });

    _socket!.on('direct:message:new', (data) async {
      final message = DirectMessage.fromJson(
        Map<String, dynamic>.from(data as Map),
      );

      final exists = _messages.any((m) => m.id == message.id);
      if (!exists) {
        _messages.add(message);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        notifyListeners();
      }

      await markConversationAsReadSilently(conversationId);
      _socket!.emit('direct:read', {'conversationId': conversationId});

      await refreshConversationSilently(
        conversationId: conversationId,
        currentUserId: currentUserId,
      );
    });

    _socket!.on('direct:conversation:read', (data) async {
      await refreshConversationSilently(
        conversationId: conversationId,
        currentUserId: currentUserId,
      );
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _isJoinedRoom = false;
      notifyListeners();
    });

    _socket!.connect();
  }

  void sendMessage({
    required int conversationId,
    String? body,
    String? mediaUrl,
  }) {
    if (_socket == null || !_isJoinedRoom) {
      throw Exception('Not connected to direct conversation');
    }

    _socket!.emit('direct:message:send', {
      'conversationId': conversationId,
      'body': body,
      'mediaUrl': mediaUrl,
    });
  }

  Future<void> editMessage({
    required int conversationId,
    required int messageId,
    required String body,
  }) async {
    final token = await _authService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final updated = await _service.editMessage(
      token: token,
      conversationId: conversationId,
      messageId: messageId,
      body: body,
    );

    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteMessage({
    required int conversationId,
    required int messageId,
  }) async {
    final token = await _authService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final deleted = await _service.deleteMessage(
      token: token,
      conversationId: conversationId,
      messageId: messageId,
    );

    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = deleted;
      notifyListeners();
    }
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }

    _isConnected = false;
    _isJoinedRoom = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
