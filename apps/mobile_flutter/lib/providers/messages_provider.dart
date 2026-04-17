import 'package:flutter/material.dart';
import '../data/models/message.dart';
import '../data/services/messages_service.dart';
import '../data/services/auth_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants/api_constants.dart';

class MessagesProvider extends ChangeNotifier {
  final MessagesService _messagesService = MessagesService();
  final AuthService _authService = AuthService();

  IO.Socket? _socket;
  List<Message> _messages = [];
  bool _isLoading = false;
  bool _isConnected = false;
  bool _isJoinedRoom = false;
  String? _error;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  bool get isJoinedRoom => _isJoinedRoom;
  String? get error => _error;

  // Load messages for a circle
  Future<void> loadMessages(int circleId, {int? cursor}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _authService.getAccessToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final fetchedMessages = await _messagesService.getMessages(
        token: token,
        circleId: circleId,
        cursor: cursor,
      );

      fetchedMessages.sort(
        (a, b) => a.createdAt.compareTo(b.createdAt),
      ); // Ensure messages are sorted by creation time

      if (cursor == null) {
        // Initial load
        _messages = fetchedMessages;
      } else {
        // Pagination - append older messages
        _messages.addAll(fetchedMessages);
        _messages.sort(
          (a, b) => a.createdAt.compareTo(b.createdAt),
        ); // Re-sort after adding new messages
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
    required int circleId,
    required int messageId,
    required String body,
  }) async {
    final token = await _authService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final updated = await _messagesService.editMessage(
      token: token,
      circleId: circleId,
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
    required int circleId,
    required int messageId,
  }) async {
    final token = await _authService.getAccessToken();
    if (token == null) throw Exception('Not authenticated');

    final deleted = await _messagesService.deleteMessage(
      token: token,
      circleId: circleId,
      messageId: messageId,
    );

    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = deleted;
      notifyListeners();
    }
  }

  // Connect to WebSocket
  Future<void> connectToCircle(int circleId) async {
    // ignore: avoid_print
    print('Attempting to connect to circle: $circleId');

    final token = await _authService.getAccessToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    //ignore: avoid_print
    print('Got access token: ${token.substring(0, 20)}...');

    // Disconnect existing socket if any
    disconnect();

    // Create a new socket connection
    // ignore: avoid_print
    print('Creating a socket connection to ${ApiConstants.socketUrl}');

    _socket = IO.io(
      ApiConstants.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    // Listen for socket events
    _socket!.onConnect((_) {
      // ignore: avoid_print
      print('Connected to WebSocket');
      _isConnected = true;
      _isJoinedRoom = false;
      notifyListeners();

      // Join the circle room
      // ignore: avoid_print
      print('Joining circle room: $circleId');
      _socket!.emit('circle:join', {'circleId': circleId});
    });

    // Listen for successful room join
    _socket!.on('circle:joined', (data) {
      // ignore: avoid_print
      print('Joined room successfully: $data');
      _isJoinedRoom = true;
      notifyListeners();
    });

    // Listen for disconnects
    _socket!.onDisconnect((_) {
      // ignore: avoid_print
      print('Disconnected from WebSocket');
      _isConnected = false;
      _isJoinedRoom = false;
      notifyListeners();
    });

    // Listen for new messages
    _socket!.on('message:new', (data) {
      print('Received new message: $data'); // Debugging line

      try {
        final message = Message.fromJson(
          Map<String, dynamic>.from(data as Map),
        );

        final alreadyExists = _messages.any(
          (m) => m.id == message.id,
        ); // new messages shouldn't already exist, but just in case
        if (alreadyExists) return;

        _messages.add(message);
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        notifyListeners();
      } catch (e) {
        // ignore: avoid_print
        print('Failed to parse incoming message: $e');
        print('Raw payload: $data');
      }
    });

    _socket!.on('message:updated', (data) {
      try {
        final updated = Message.fromJson(
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
        final deleted = Message.fromJson(
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

    // Listen for live events for debugging
    _socket!.onAny((event, data) {
      // ignore: avoid_print
      print('Socket event -> $event | $data');
    });

    // listen for connect_error
    _socket!.on('connect_error', (error) {
      // ignore: avoid_print
      print('Connection error: $error');
    });

    // Listen for typing indicators
    _socket!.on('typing:update', (data) {
      // Handle typing indicator (e.g., show "User is typing...")
      // ignore: avoid_print
      print('Typing: $data');
    });

    // Connect the socket
    // ignore: avoid_print
    print('Calling socket.connect()...');
    _socket!.connect();
  }

  // Send message via WebSocket
  void sendMessage({required int circleId, String? body, String? mediaUrl}) {
    if (_socket == null || !_isConnected) {
      throw Exception('Not connected to WebSocket');
    }

    _socket!.emit('message:send', {
      'circleId': circleId,
      'body': body,
      'mediaUrl': mediaUrl,
    });
  }

  // Disconnect from Websocket
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      _isJoinedRoom = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
