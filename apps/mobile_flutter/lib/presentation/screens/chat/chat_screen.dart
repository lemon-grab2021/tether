import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tether/providers/auth_provider.dart';
import 'package:tether/providers/messages_provider.dart';
import '../../../data/models/circle.dart';

class ChatScreen extends StatefulWidget {
  final Circle circle;

  const ChatScreen({super.key, required this.circle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();  
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  MessagesProvider? messagesProvider;

  @override
  void initState() {
    super.initState();
    // Load initial messages for the circle
    WidgetsBinding.instance.addPostFrameCallback((_) {
     if (!mounted) return;
     
      messagesProvider = context.read<MessagesProvider>();
      messagesProvider!.loadMessages(widget.circle.id);
      messagesProvider!.connectToCircle(widget.circle.id);
    }); 

}

  @override 
  void dispose(){
    _messageController.dispose();
    _scrollController.dispose();
    messagesProvider?.disconnect();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage(){
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      context.read<MessagesProvider>().sendMessage(
        circleId: widget.circle.id,
        body: text,
      );
      _messageController.clear();

      // Scroll to bottom after sending a message
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesProvider = context.watch<MessagesProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.user?.id;

    // Scroll to bottom when new messages arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messagesProvider.messages.isNotEmpty) {
        _scrollToBottom();
      }
    });

        return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.circle.name),
            Text(
              messagesProvider.isConnected ? 'Connected' : 'Connecting...',
              style: TextStyle(
                fontSize: 12,
                color: messagesProvider.isConnected ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show circle info
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(widget.circle.name),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.circle.description != null)
                        Text(widget.circle.description!),
                      const SizedBox(height: 16),
                      Text('Members: ${widget.circle.messageCount?.members ?? 0}'),
                      Text('Messages: ${widget.circle.messageCount?.messages ?? 0}'),
                      if (widget.circle.inviteCode != null) ...[
                        const SizedBox(height: 16),
                        const Text('Invite Code:'),
                        SelectableText(
                          widget.circle.inviteCode!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messagesProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : messagesProvider.error != null
                    ? Center(child: Text('Error: ${messagesProvider.error}'))
                    : messagesProvider.messages.isEmpty
                        ? const Center(
                            child: Text('No messages yet. Start the conversation!'),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: messagesProvider.messages.length,
                            itemBuilder: (context, index) {
                              final message = messagesProvider.messages[index];
                              final isMe = message.senderId == currentUserId;
                              final showSender = index == 0 ||
                                  messagesProvider.messages[index - 1].senderId !=
                                      message.senderId;

                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.7,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Column(
                                    crossAxisAlignment: isMe
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      if (showSender && !isMe)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 12,
                                            bottom: 4,
                                          ),
                                          child: Text(
                                            message.sender?.displayName ?? 'Unknown',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? Colors.blue
                                              : Colors.grey[300],
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (message.body != null)
                                              Text(
                                                message.body!,
                                                style: TextStyle(
                                                  color: isMe
                                                      ? Colors.white
                                                      : Colors.black,
                                                ),
                                              ),
                                            if (message.mediaUrl != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Image.network(
                                                  message.mediaUrl!,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 12,
                                          right: 12,
                                          top: 2,
                                        ),
                                        child: Text(
                                          DateFormat('HH:mm')
                                              .format(message.createdAt.toLocal()),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: messagesProvider.isJoinedRoom
                        ? _sendMessage
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}