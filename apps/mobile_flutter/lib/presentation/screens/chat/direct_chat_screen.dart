import 'dart:async';
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
  Timer? _refreshTimer;

  Timer? _typingDebounce;
  bool _sentTyping = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.user?.id;
      if (currentUserId == null) return;

      directMessagesProvider = context.read<DirectMessagesProvider>();

      await directMessagesProvider!.loadMessages(widget.conversation.id);
      await directMessagesProvider!.loadConversation(
        conversationId: widget.conversation.id,
        currentUserId: currentUserId,
      );
      await directMessagesProvider!.markConversationAsRead(
        widget.conversation.id,
      );
      await directMessagesProvider!.connectToConversation(
        conversationId: widget.conversation.id,
        currentUserId: currentUserId,
      );

      _startPolling(currentUserId);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _typingDebounce?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    directMessagesProvider?.disconnect();
    super.dispose();
  }

  void _startPolling(int currentUserId) {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || directMessagesProvider == null) return;

      await directMessagesProvider!.markConversationAsReadSilently(
        widget.conversation.id,
      );

      await directMessagesProvider!.refreshMessagesSilently(
        widget.conversation.id,
      );

      await directMessagesProvider!.refreshConversationSilently(
        conversationId: widget.conversation.id,
        currentUserId: currentUserId,
      );
    });
  }

  void _handleTyping(String value) {
    final provider = context.read<DirectMessagesProvider>();

    if (value.trim().isNotEmpty && !_sentTyping) {
      provider.startTyping(widget.conversation.id);
      _sentTyping = true;
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(milliseconds: 1200), () {
      provider.stopTyping(widget.conversation.id);
      _sentTyping = false;
    });

    if (value.trim().isEmpty && _sentTyping) {
      provider.stopTyping(widget.conversation.id);
      _sentTyping = false;
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
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
      provider.sendMessage(conversationId: widget.conversation.id, body: text);

      provider.stopTyping(widget.conversation.id);
      _sentTyping = false;
      _typingDebounce?.cancel();

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

  DateTime? _otherUserLastReadAt({
    required DirectConversation conversation,
    required int currentUserId,
  }) {
    if (conversation.userOneId == currentUserId) {
      return conversation.userTwoLastReadAt;
    } else {
      return conversation.userOneLastReadAt;
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
          decoration: const InputDecoration(hintText: 'Update your message'),
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

  Widget _buildAvatar({
    required String displayName,
    required String? avatarUrl,
  }) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: 21,
      backgroundColor: const Color(0xFFE9E5FF),
      backgroundImage: (avatarUrl != null && avatarUrl.trim().isNotEmpty)
          ? NetworkImage(avatarUrl)
          : null,
      child: (avatarUrl == null || avatarUrl.trim().isEmpty)
          ? Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF5B21B6),
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DirectMessagesProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.user?.id;

    final conversation = provider.conversation ?? widget.conversation;
    final otherUser = conversation.otherUser;
    final isOtherUserTyping = provider.isOtherUserTyping;
    final displayName =
        (otherUser.displayName != null &&
            otherUser.displayName!.trim().isNotEmpty)
        ? otherUser.displayName!.trim()
        : otherUser.username;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.messages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5EAF0), width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: const Color(0xFF111827),
                  ),
                  _buildAvatar(
                    displayName: displayName,
                    avatarUrl: otherUser.avatarUrl,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.isJoinedRoom
                              ? 'Online'
                              : provider.isConnected
                              ? 'Connecting...'
                              : 'Offline',
                          style: TextStyle(
                            fontSize: 13,
                            color: provider.isJoinedRoom
                                ? Colors.green
                                : const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.call_outlined),
                    color: const Color(0xFF475569),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.videocam_outlined),
                    color: const Color(0xFF475569),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_vert),
                    color: const Color(0xFF475569),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.error != null && provider.messages.isEmpty
                  ? Center(child: Text('Error: ${provider.error}'))
                  : provider.messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No messages yet.\nSay hello and start the conversation.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                      itemCount:
                          provider.messages.length +
                          (isOtherUserTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == provider.messages.length &&
                            isOtherUserTyping) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFE5EAF0),
                                ),
                              ),
                              child: const _TypingDots(),
                            ),
                          );
                        }

                        final message = provider.messages[index];
                        final isMe = message.senderId == currentUserId;
                        final isDeleted = message.deletedAt != null;
                        final isEdited = message.editedAt != null && !isDeleted;

                        final otherLastReadAt = currentUserId == null
                            ? null
                            : _otherUserLastReadAt(
                                conversation: conversation,
                                currentUserId: currentUserId,
                              );

                        final isSeen =
                            isMe &&
                            otherLastReadAt != null &&
                            !otherLastReadAt.isBefore(message.createdAt);

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
                                  onLongPress: isMe && !isDeleted
                                      ? () => _showMessageActions(message)
                                      : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDeleted
                                          ? (isMe
                                                ? const Color(0xFF7C89F7)
                                                : Colors.white)
                                          : (isMe
                                                ? const Color(0xFF1476E6)
                                                : Colors.white),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(22),
                                        topRight: const Radius.circular(22),
                                        bottomLeft: Radius.circular(
                                          isMe ? 22 : 8,
                                        ),
                                        bottomRight: Radius.circular(
                                          isMe ? 8 : 22,
                                        ),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                      border: isMe
                                          ? null
                                          : Border.all(
                                              color: const Color(0xFFE5EAF0),
                                            ),
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
                                                  : const Color(0xFF64748B),
                                            ),
                                          )
                                        else ...[
                                          if (message.body != null)
                                            Text(
                                              message.body!,
                                              style: TextStyle(
                                                color: isMe
                                                    ? Colors.white
                                                    : const Color(0xFF111827),
                                                fontSize: 16,
                                                height: 1.35,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          if (message.mediaUrl != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(14),
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
                                    left: 8,
                                    right: 8,
                                    top: 5,
                                  ),
                                  child: Text(
                                    '${DateFormat('h:mm a').format(message.createdAt.toLocal())}'
                                    '${isEdited ? ' • edited' : ''}'
                                    '${isMe && !isDeleted ? ' • ${isSeen ? 'Seen' : 'Sent'}' : ''}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
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
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE5EAF0), width: 1),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.attach_file_rounded),
                      color: const Color(0xFF64748B),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          onChanged: _handleTyping,
                          decoration: InputDecoration(
                            hintText: 'Message',
                            hintStyle: const TextStyle(
                              color: Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.emoji_emotions_outlined),
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1476E6),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: provider.isJoinedRoom ? _sendMessage : null,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _dot(double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = (_controller.value - delay).clamp(0.0, 1.0);
        final opacity = (value <= 0.5) ? value * 2 : (1 - value) * 2;

        return Opacity(
          opacity: opacity.clamp(0.25, 1.0),
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF94A3B8),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(0.0),
        const SizedBox(width: 6),
        _dot(0.2),
        const SizedBox(width: 6),
        _dot(0.4),
      ],
    );
  }
}
