import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tether/providers/auth_provider.dart';
import 'package:tether/providers/direct_messages_provider.dart';
import '../../../data/models/direct_conversation.dart';
import '../../../data/models/direct_message.dart';

class DirectChatScreen extends StatefulWidget {
  final DirectConversation conversation;

  const DirectChatScreen({super.key, required this.conversation});

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  DirectMessagesProvider? directMessagesProvider;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      directMessagesProvider = context.read<DirectMessagesProvider>();
      directMessagesProvider!.loadMessages(widget.conversation.id);
      directMessagesProvider!.connectToConversation(widget.conversation.id);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    directMessagesProvider?.disconnect();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final provider = context.read<DirectMessagesProvider>();
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (!provider.isJoinedRoom) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a moment and try again.'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    try {
      provider.sendMessage(
        conversationId: widget.conversation.id,
        body: text,
      );
      _messageController.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to send message: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showMessageActions(DirectMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete message'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await context.read<DirectMessagesProvider>().deleteMessage(
                          conversationId: widget.conversation.id,
                          messageId: message.id,
                        );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to delete message: ${e.toString().replaceAll('Exception: ', '')}',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(DirectMessage message) {
    final controller = TextEditingController(text: message.body ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: controller,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Update your message',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedText = controller.text.trim();
              if (updatedText.isEmpty) return;

              try {
                await context.read<DirectMessagesProvider>().editMessage(
                      conversationId: widget.conversation.id,
                      messageId: message.id,
                      body: updatedText,
                    );

                if (!mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to edit message: ${e.toString().replaceAll('Exception: ', '')}',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DirectMessagesProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.user?.id;
    final otherUser = widget.conversation.otherUser;

    final displayName = (otherUser.displayName != null &&
            otherUser.displayName!.trim().isNotEmpty)
        ? otherUser.displayName!.trim()
        : otherUser.username;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.messages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFEDE9FE),
              backgroundImage: (otherUser.avatarUrl != null &&
                      otherUser.avatarUrl!.trim().isNotEmpty)
                  ? NetworkImage(otherUser.avatarUrl!)
                  : null,
              child: (otherUser.avatarUrl == null ||
                      otherUser.avatarUrl!.trim().isEmpty)
                  ? Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFF5B21B6),
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    provider.isJoinedRoom
                        ? 'Online'
                        : provider.isConnected
                            ? 'Joining Conversation...'
                            : 'Connecting...',
                    style: TextStyle(
                      fontSize: 12,
                      color: provider.isJoinedRoom
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? Center(child: Text('Error: ${provider.error}'))
                    : provider.messages.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No messages yet.\nSay hello and start the conversation.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: provider.messages.length,
                            itemBuilder: (context, index) {
                              final message = provider.messages[index];
                              final isMe = message.senderId == currentUserId;
                              final isDeleted = message.deletedAt != null;
                              final isEdited =
                                  message.editedAt != null && !isDeleted;

                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.72,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment: isMe
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onLongPress:
                                            isMe && !isDeleted
                                                ? () =>
                                                    _showMessageActions(message)
                                                : null,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDeleted
                                                ? (isMe
                                                    ? const Color(0xFF818CF8)
                                                    : Colors.grey.shade200)
                                                : (isMe
                                                    ? const Color(0xFF4F46E5)
                                                    : Colors.white),
                                            borderRadius: BorderRadius.only(
                                              topLeft:
                                                  const Radius.circular(20),
                                              topRight:
                                                  const Radius.circular(20),
                                              bottomLeft: Radius.circular(
                                                  isMe ? 20 : 6),
                                              bottomRight: Radius.circular(
                                                  isMe ? 6 : 20),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.05),
                                                blurRadius: 12,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (isDeleted)
                                                Text(
                                                  'Message deleted',
                                                  style: TextStyle(
                                                    fontStyle: FontStyle.italic,
                                                    color: isMe
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                  ),
                                                )
                                              else ...[
                                                if (message.body != null)
                                                  Text(
                                                    message.body!,
                                                    style: TextStyle(
                                                      color: isMe
                                                          ? Colors.white
                                                          : Colors.black87,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                if (message.mediaUrl != null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 8),
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              14),
                                                      child: Image.network(
                                                        message.mediaUrl!,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 10,
                                          right: 10,
                                          top: 4,
                                        ),
                                        child: Text(
                                          '${DateFormat('HH:mm').format(message.createdAt.toLocal())}'
                                          '${isEdited ? ' • edited' : ''}',
                                          style: TextStyle(
                                            fontSize: 11,
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
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 14,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Message $displayName...',
                        filled: true,
                        fillColor: const Color(0xFFF4F4F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF4F46E5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: provider.isJoinedRoom ? _sendMessage : null,
                      icon:
                          const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}