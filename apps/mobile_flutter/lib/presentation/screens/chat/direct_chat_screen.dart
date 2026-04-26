import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../widgets/tether_chat_ui.dart';
import '../../../providers/in_app_notifications_provider.dart';
import 'package:tether/providers/auth_provider.dart';
import 'package:tether/providers/direct_messages_provider.dart';
import '../../../data/models/direct_conversation.dart';
import '../../../data/models/direct_message.dart';
import '../../../providers/deleted_conversations_provider.dart';
import '../../widgets/delete_conversation_sheet.dart';
import '../../widgets/conversation_overflow_button.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:mime/mime.dart';

import '../../../data/services/uploads_service.dart';

class DirectChatScreen extends StatefulWidget {
  final DirectConversation conversation;

  const DirectChatScreen({super.key, required this.conversation});

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final UploadsService _uploadsService = UploadsService();

  DirectMessagesProvider? directMessagesProvider;
  Timer? _refreshTimer;

  Timer? _typingDebounce;
  bool _sentTyping = false;
  bool _isUploading = false;

  int? _lastRenderedMessageId;
  bool _didInitialAutoScroll = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<InAppNotificationsProvider>().setActiveDirectConversation(
        widget.conversation.id,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.user?.id;
      if (currentUserId == null) return;

      final otherUser = widget.conversation.otherUser;
      final otherUserName =
          (otherUser.displayName != null &&
              otherUser.displayName!.trim().isNotEmpty)
          ? otherUser.displayName!.trim()
          : otherUser.username;

      context.read<InAppNotificationsProvider>().setActiveDirectConversation(
        widget.conversation.id,
      );

      directMessagesProvider = context.read<DirectMessagesProvider>();

      directMessagesProvider!.onIncomingMessage = (message) {
        if (!mounted) return;

        if (message.senderId == currentUserId) return;

        context.read<InAppNotificationsProvider>().notifyDirectMessage(
          conversationId: widget.conversation.id,
          senderId: message.senderId,
          currentUserId: currentUserId,
          senderName: otherUserName,
          messagePreview: message.body ?? '',
        );
      };

      try {
        await directMessagesProvider!.loadMessages(widget.conversation.id);
      } catch (_) {}

      try {
        await directMessagesProvider!.loadConversation(
          conversationId: widget.conversation.id,
          currentUserId: currentUserId,
        );
      } catch (_) {}

      try {
        await directMessagesProvider!.connectToConversation(
          conversationId: widget.conversation.id,
          currentUserId: currentUserId,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to connect to conversation: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Do this after socket connection starts, and do not block on it
      unawaited(
        directMessagesProvider!.markConversationAsReadSilently(
          widget.conversation.id,
        ),
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
    directMessagesProvider?.onIncomingMessage = null;
    directMessagesProvider?.disconnect();
    try {
      context.read<InAppNotificationsProvider>().setActiveDirectConversation(
        null,
      );
    } catch (_) {}

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

  bool _isNearBottom({double threshold = 180}) {
    if (!_scrollController.hasClients) return true;

    final position = _scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;

    return distanceFromBottom <= threshold;
  }

  void _maybeAutoScrollForMessages(
    List<DirectMessage> messages,
    int? currentUserId,
  ) {
    if (messages.isEmpty) return;

    final latestMessage = messages.last;
    final latestMessageId = latestMessage.id;

    final hasNewLatestMessage = _lastRenderedMessageId != latestMessageId;

    final shouldScroll =
        !_didInitialAutoScroll ||
        (hasNewLatestMessage &&
            (latestMessage.senderId == currentUserId || _isNearBottom()));

    _lastRenderedMessageId = latestMessageId;
    _didInitialAutoScroll = true;

    if (!shouldScroll) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom();
    });
  }

  bool _isSameLocalDate(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();

    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  String _chatDateLabel(DateTime value) {
    final localValue = value.toLocal();
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(
      localValue.year,
      localValue.month,
      localValue.day,
    );

    if (messageDate == today) return 'Today';
    if (messageDate == yesterday) return 'Yesterday';

    return DateFormat('dd/MM/yyyy').format(localValue);
  }

  Future<void> _sendMessage() async {
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
      await provider.sendMessage(
        conversationId: widget.conversation.id,
        body: text,
      );

      provider.stopTyping(widget.conversation.id);
      _sentTyping = false;
      _typingDebounce?.cancel();

      _messageController.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (!mounted) return;
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

  Future<void> _pickAndSendMedia() async {
    if (_isUploading) return;

    final provider = context.read<DirectMessagesProvider>();

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
      final result = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'mp4', 'webm', 'mov'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final Uint8List? bytes = file.bytes;

      if (bytes == null) {
        throw Exception('Could not read selected file');
      }

      final filename = file.name;
      final mimeType =
          lookupMimeType(filename, headerBytes: bytes) ??
          'application/octet-stream';

      final isAllowed =
          mimeType.startsWith('image/') || mimeType.startsWith('video/');

      if (!isAllowed) {
        throw Exception('Only images and videos are allowed');
      }

      setState(() => _isUploading = true);

      final uploaded = await _uploadsService.uploadMedia(
        filename: filename,
        mimeType: mimeType,
        fileSize: bytes.length,
        bytes: bytes,
      );

      if (uploaded.fileUrl.isEmpty) {
        throw Exception('Upload completed but no file URL was returned');
      }

      provider.sendMessage(
        conversationId: widget.conversation.id,
        mediaUrl: uploaded.fileUrl,
      );

      Future.delayed(const Duration(milliseconds: 120), _scrollToBottom);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to upload attachment: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
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

    _maybeAutoScrollForMessages(provider.messages, currentUserId);

    return Scaffold(
      backgroundColor: TetherChatPalette.background,
      body: TetherChatBackground(
        child: SafeArea(
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
                    ConversationOverflowButton(
                      onPin: () {},
                      onMute: () {},
                      onDelete: () async {
                        final otherUser = widget.conversation.otherUser;
                        final displayName =
                            (otherUser.displayName != null &&
                                otherUser.displayName!.trim().isNotEmpty)
                            ? otherUser.displayName!.trim()
                            : otherUser.username;

                        final confirmed = await showDeleteConversationSheet(
                          context,
                          title: displayName,
                          isCircle: false,
                        );

                        if (!confirmed || !mounted) return;

                        context
                            .read<DeletedConversationsProvider>()
                            .softDeleteDirectConversation(widget.conversation);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Conversation moved to Deleted'),
                          ),
                        );
                        Navigator.pop(context);
                      },
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
                            return const TetherTypingPill(
                              visible: true,
                              label: 'typing...',
                            );
                          }

                          final message = provider.messages[index];
                          final isMe = message.senderId == currentUserId;
                          final isDeleted = message.deletedAt != null;
                          final isEdited =
                              message.editedAt != null && !isDeleted;

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
                          final metaText =
                              '${DateFormat('h:mm a').format(message.createdAt.toLocal())}'
                              '${isEdited ? ' • edited' : ''}'
                              '${isMe && !isDeleted ? ' • ${isSeen ? 'Seen' : 'Sent'}' : ''}';

                          final previousMessage = index > 0
                              ? provider.messages[index - 1]
                              : null;

                          final showDateSeparator =
                              previousMessage == null ||
                              !_isSameLocalDate(
                                previousMessage.createdAt,
                                message.createdAt,
                              );

                          return Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              if (showDateSeparator)
                                _DateSeparator(
                                  label: _chatDateLabel(message.createdAt),
                                ),
                              TetherChatBubble(
                                isMe: isMe,
                                text: message.body,
                                mediaUrl: message.mediaUrl,
                                isDeleted: isDeleted,
                                metaText: metaText,
                                onLongPress: isMe && !isDeleted
                                    ? () => _showMessageActions(message)
                                    : null,
                              ),
                            ],
                          );
                        },
                      ),
              ),
              TetherComposer(
                controller: _messageController,
                hasText: _messageController.text.trim().isNotEmpty,
                canSend: provider.isJoinedRoom,
                isUploading: _isUploading,
                onAttach: _pickAndSendMedia,
                onSend: _sendMessage,
                onChanged: (value) {
                  setState(() {});
                  _handleTyping(value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final String label;

  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: Color(0xFFE4E7EC), thickness: 1),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE4E7EC)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF667085),
              ),
            ),
          ),
          const Expanded(
            child: Divider(color: Color(0xFFE4E7EC), thickness: 1),
          ),
        ],
      ),
    );
  }
}
