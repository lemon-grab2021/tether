import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants/api_constants.dart';
import '../data/models/direct_message.dart';
import '../data/services/auth_service.dart';
import '../data/services/direct_messages_service.dart';

class DirectMessagesProvider extends ChangeNotifier {
  final DirectMessagesService _service = DirectMessagesService();
  final AuthService _authService = AuthService();

  IO.Socket? _socket;
  List<DirectMessage> _messages = [];
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isJoinedRoom = false;
  String? _error;

  List<DirectMessage> get messages => _messages;
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

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
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

  Future<void> connectToConversation(int conversationId) async {
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

    _socket!.on('direct:joined', (_) {
      _isJoinedRoom = true;
      notifyListeners();
    });

    _socket!.on('direct:message:new', (data) {
      final message = DirectMessage.fromJson(
        Map<String, dynamic>.from(data as Map),
      );

      final exists = _messages.any((m) => m.id == message.id);
      if (exists) return;

      _messages.add(message);
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();
    });

    _socket!.on('message:updated', (data) {
      try {
        final updated = DirectMessage.fromJson(
          Map<String, dynamic>.from(data as Map),
        );

        final index = _messages.indexWhere((m) => m.id == updated.id);
        if (index != -1) {
          _messages[index] = updated;
          notifyListeners();
        }
      } catch (e) {
        print('Failed to parse message:updated -> $e');
      }
    });

    _socket!.on('message:deleted', (data) {
      try {
        final deleted = DirectMessage.fromJson(
          Map<String, dynamic>.from(data as Map),
        );

        final index = _messages.indexWhere((m) => m.id == deleted.id);
        if (index != -1) {
          _messages[index] = deleted;
          notifyListeners();
        }
      } catch (e) {
        print('Failed to parse message:deleted -> $e');
      }
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
