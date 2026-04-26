import 'dart:async';

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
  bool _isOtherUserTyping = false;
  String? _error;

  List<DirectMessage> get messages => _messages;
  DirectConversation? get conversation => _conversation;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  bool get isJoinedRoom => _isJoinedRoom;
  bool get isOtherUserTyping => _isOtherUserTyping;
  String? get error => _error;

  Future<void> loadMessages(int conversationId, {int? cursor}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _authService.getAccessToken();
      if (token == null) throw Exception('Not authenticated');

      print('Loading direct messages for conversationId=$conversationId');

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
      print('Direct messages load failed for conversationId=$conversationId');
      print(e);
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

  void Function(DirectMessage message)? onIncomingMessage;

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
    _error = null;
    _isConnected = false;
    _isJoinedRoom = false;
    _isOtherUserTyping = false;
    notifyListeners();

    _socket = IO.io(
      ApiConstants.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.onConnect((_) {
      print('DM socket connected for conversationId=$conversationId');
      _isConnected = true;
      _error = null;
      notifyListeners();

      _socket!.emitWithAck(
        'direct:join',
        {'conversationId': conversationId},
        ack: (data) async {
          if (data == null) {
            _error = 'No response when joining conversation';
            _isJoinedRoom = false;
            notifyListeners();
            return;
          }

          final map = Map<String, dynamic>.from(data as Map);

          if (map['success'] == true) {
            print('Joined DM room successfully');
            _isJoinedRoom = true;
            _error = null;
            notifyListeners();

            await markConversationAsReadSilently(conversationId);
            _socket!.emit('direct:read', {'conversationId': conversationId});

            await refreshConversationSilently(
              conversationId: conversationId,
              currentUserId: currentUserId,
            );
          } else {
            print('Join failed: ${map['error']}');
            _isJoinedRoom = false;
            _error = map['error']?.toString() ?? 'Failed to join conversation';
            notifyListeners();
          }
        },
      );
    });

    _socket!.onConnectError((data) {
      print('DM socket connect error: $data');
      _isConnected = false;
      _isJoinedRoom = false;
      _error = 'Socket connection failed: $data';
      notifyListeners();
    });

    _socket!.onError((data) {
      print('DM socket error: $data');
      _error = 'Socket error: $data';
      notifyListeners();
    });

    _socket!.on('direct:typing:update', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      // final isTyping = map['isTyping'] == true;

      _isOtherUserTyping = map['isTyping'] == true;
      notifyListeners();
    });

    _socket!.on('direct:joined', (_) async {
      _isJoinedRoom = true;
      _error = null;
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

        onIncomingMessage?.call(message);

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

  Future<void> sendMessage({
    required int conversationId,
    String? body,
    String? mediaUrl,
  }) async {
    if (_socket == null || !_isJoinedRoom) {
      throw Exception('Not connected to direct conversation');
    }

    final payload = <String, dynamic>{'conversationId': conversationId};

    final trimmedBody = body?.trim();
    final trimmedMediaUrl = mediaUrl?.trim();

    if (trimmedBody != null && trimmedBody.isNotEmpty) {
      payload['body'] = trimmedBody;
    }

    if (trimmedMediaUrl != null && trimmedMediaUrl.isNotEmpty) {
      payload['mediaUrl'] = trimmedMediaUrl;
    }

    if (!payload.containsKey('body') && !payload.containsKey('mediaUrl')) {
      throw Exception('Message cannot be empty');
    }

    _socket!.emitWithAck('direct:message:send', payload);
  }

  void startTyping(int conversationId) {
    if (_socket == null || !_isJoinedRoom) return;
    _socket!.emit('direct:typing:start', {'conversationId': conversationId});
  }

  void stopTyping(int conversationId) {
    if (_socket == null || !_isJoinedRoom) return;
    _socket!.emit('direct:typing:stop', {'conversationId': conversationId});
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
    _isOtherUserTyping = false;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
