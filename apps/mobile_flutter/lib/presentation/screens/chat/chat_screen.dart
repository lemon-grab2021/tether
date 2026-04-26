import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:mime/mime.dart';
import '../../widgets/tether_chat_ui.dart';

import '../../../data/services/uploads_service.dart';
import 'package:intl/intl.dart';
import '../../../providers/in_app_notifications_provider.dart';
import 'package:provider/provider.dart';
import 'package:tether/providers/auth_provider.dart';
import 'package:tether/providers/messages_provider.dart';
import '../../../data/models/circle.dart';
import '../../../providers/deleted_conversations_provider.dart';
import '../../widgets/delete_conversation_sheet.dart';
import '../../widgets/conversation_overflow_button.dart';

class ChatScreen extends StatefulWidget {
  final Circle circle;

  const ChatScreen({super.key, required this.circle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final UploadsService _uploadsService = UploadsService();

  MessagesProvider? _messagesProvider;
  bool _isUploading = false;

  int? _lastRenderedMessageId;
  bool _didInitialAutoScroll = false;

  List<String> _typingNames(MessagesProvider provider, int? currentUserId) {
    final members = widget.circle.members ?? [];

    return members
        .where(
          (m) =>
              m.user != null &&
              m.user!.id != currentUserId &&
              provider.typingUserIds.contains(m.user!.id),
        )
        .map((m) => m.user!.displayName)
        .toList();
  }

  String _typingLabel(List<String> names) {
    if (names.isEmpty) return '';
    if (names.length == 1) return '${names.first} is typing...';
    if (names.length == 2) return '${names[0]} and ${names[1]} are typing...';
    return '${names[0]}, ${names[1]} and others are typing...';
  }

  int _onlineCount(MessagesProvider provider) {
    final members = widget.circle.members ?? [];
    return members
        .where(
          (m) => m.user != null && provider.onlineUserIds.contains(m.user!.id),
        )
        .length;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      context.read<InAppNotificationsProvider>().setActiveCircle(
        widget.circle.id,
      );

      _messagesProvider = context.read<MessagesProvider>();

      _messagesProvider!.onIncomingMessage = (message) {
        if (!mounted) return;

        final currentUserId = context.read<AuthProvider>().user?.id;

        if (message.senderId == currentUserId) return;
        if (currentUserId == null) return;

        final rawDisplayName = message.sender?.displayName;
        final senderName =
            rawDisplayName != null && rawDisplayName.trim().isNotEmpty
            ? rawDisplayName.trim()
            : message.sender?.username ?? 'Someone';

        context.read<InAppNotificationsProvider>().notifyCircleMessage(
          circleId: widget.circle.id,
          senderId: message.senderId,
          currentUserId: currentUserId,
          circleName: widget.circle.name,
          senderName: senderName,
          messagePreview: message.body ?? '',
        );
      };

      await _messagesProvider!.loadMessages(widget.circle.id);
      await _messagesProvider!.connectToCircle(widget.circle.id);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    _messagesProvider?.onIncomingMessage = null;
    _messagesProvider?.disconnect();
    try {
      context.read<InAppNotificationsProvider>().setActiveCircle(null);
    } catch (_) {}
    super.dispose();
  }

  // Scroll function
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
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

  void _maybeAutoScrollForMessages(List<dynamic> messages, int? currentUserId) {
    if (messages.isEmpty) return;

    final latestMessage = messages.last;
    final latestMessageId = latestMessage.id as int;

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

  void _sendMessage() {
    final provider = context.read<MessagesProvider>();
    final text = _messageController.text.trim();

    if (text.isEmpty) return;

    if (!provider.isJoinedRoom) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a moment and try again.'),
          backgroundColor: Colors.grey,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      provider.sendMessage(circleId: widget.circle.id, body: text);
      _messageController.clear();
      setState(() {});
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to send message: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickAndSendMedia() async {
    if (_isUploading) return;

    final provider = context.read<MessagesProvider>();

    if (!provider.isJoinedRoom) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait a moment and try again.'),
          backgroundColor: Colors.grey,
          behavior: SnackBarBehavior.floating,
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
      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception('Could not read selected file');
      }

      final mimeType =
          lookupMimeType(file.name, headerBytes: bytes) ??
          'application/octet-stream';

      final isAllowed =
          mimeType.startsWith('image/') || mimeType.startsWith('video/');

      if (!isAllowed) {
        throw Exception('Only images and videos are allowed');
      }

      setState(() => _isUploading = true);

      final uploaded = await _uploadsService.uploadMedia(
        filename: file.name,
        mimeType: mimeType,
        fileSize: bytes.length,
        bytes: bytes,
      );

      if (uploaded.fileUrl.isEmpty) {
        throw Exception('Upload completed but no file URL was returned');
      }

      provider.sendMessage(
        circleId: widget.circle.id,
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
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  String _memberCountText() {
    final count =
        widget.circle.messageCount?.members ??
        widget.circle.members?.length ??
        0;
    return '$count member${count == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessagesProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.user?.id;
    final messages = provider.messages;
    final typingNames = _typingNames(provider, currentUserId);

    _maybeAutoScrollForMessages(messages, currentUserId);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: TetherChatPalette.background,
      endDrawer: _CircleMembersDrawer(circle: widget.circle),
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.96),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 4),
            _HeaderGroupAvatar(circle: widget.circle),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.circle.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_memberCountText()} · ${_onlineCount(provider)} online'
                        '${provider.isJoinedRoom ? ' · connected' : ''}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.people_outline_rounded),
            color: const Color(0xFF475569),
          ),
          IconButton(
            onPressed: () => _showCircleInfoSheet(context),
            icon: const Icon(Icons.settings_outlined),
            color: const Color(0xFF475569),
          ),
          ConversationOverflowButton(
            onPin: () {},
            onMute: () {},
            onDelete: () async {
              final confirmed = await showDeleteConversationSheet(
                context,
                title: widget.circle.name,
                isCircle: true,
              );

              if (!confirmed || !mounted) return;

              context.read<DeletedConversationsProvider>().softDeleteCircle(
                widget.circle,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Conversation moved to Deleted')),
              );

              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: TetherChatBackground(
        child: Column(
          children: [
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.error != null && messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 54,
                              color: Colors.blueGrey.shade300,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Could not load messages',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              provider.error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                      itemCount: messages.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _CircleConversationIntro(
                            circle: widget.circle,
                          );
                        }

                        final message = messages[index - 1];
                        final prev = index - 2 >= 0
                            ? messages[index - 2]
                            : null;
                        final next = index < messages.length
                            ? messages[index]
                            : null;

                        final isMe = message.senderId == currentUserId;
                        final dateChanged =
                            prev == null ||
                            !_isSameLocalDate(
                              prev.createdAt,
                              message.createdAt,
                            );

                        final senderChangedFromPrevious =
                            prev == null ||
                            dateChanged ||
                            prev.senderId != message.senderId;
                        final senderChangesNext =
                            next == null || next.senderId != message.senderId;

                        final showSender = !isMe && senderChangedFromPrevious;
                        final showAvatar = !isMe && senderChangesNext;
                        final showTimestamp = true;

                        final showDateSeparator =
                            prev == null ||
                            !_isSameLocalDate(
                              prev.createdAt,
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
                            _CircleMessageBubble(
                              message: message,
                              isMe: isMe,
                              showSender: showSender,
                              showAvatar: showAvatar,
                              showTail: senderChangesNext,
                              showTimestamp: showTimestamp,
                            ),
                          ],
                        );
                      },
                    ),
            ),
            TetherTypingPill(
              visible: typingNames.isNotEmpty,
              label: _typingLabel(typingNames),
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
                context.read<MessagesProvider>().handleComposerChanged(
                  circleId: widget.circle.id,
                  value: value,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCircleInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CircleInfoSheet(circle: widget.circle),
    );
  }
}

class _CircleConversationIntro extends StatelessWidget {
  final Circle circle;

  const _CircleConversationIntro({required this.circle});

  @override
  Widget build(BuildContext context) {
    final memberCount =
        circle.messageCount?.members ?? circle.members?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 4),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: const Color(0x141274E7),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.blur_circular_rounded,
                    size: 34,
                    color: Color(0xFF1274E7),
                  ),
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1274E7),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$memberCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            circle.name,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'This is the beginning of your conversation in ${circle.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleMessageBubble extends StatelessWidget {
  final dynamic message;
  final bool isMe;
  final bool showSender;
  final bool showAvatar;
  final bool showTail;
  final bool showTimestamp;

  const _CircleMessageBubble({
    required this.message,
    required this.isMe,
    required this.showSender,
    required this.showAvatar,
    required this.showTail,
    required this.showTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    final senderName = message.sender?.displayName ?? 'Unknown';
    final senderAvatar = message.sender?.avatarUrl as String?;
    final formattedTime = DateFormat(
      'h:mm a',
    ).format(message.createdAt.toLocal());

    final isDeleted = message.deletedAt != null;
    final isEdited = message.editedAt != null && !isDeleted;

    final metaText = '$formattedTime${isEdited ? ' • edited' : ''}';

    return TetherChatBubble(
      isMe: isMe,
      text: message.body,
      mediaUrl: message.mediaUrl,
      isDeleted: isDeleted,
      metaText: metaText,
      showSender: showSender,
      senderName: senderName,
      senderAvatarUrl: senderAvatar,
      showAvatar: showAvatar,
      showTail: showTail,
    );
  }
}

class _HeaderGroupAvatar extends StatelessWidget {
  final Circle circle;

  const _HeaderGroupAvatar({required this.circle});

  @override
  Widget build(BuildContext context) {
    final members = circle.members ?? [];

    if (members.isEmpty) {
      return _SeedGroupAvatar(seed: circle.name, size: 42);
    }

    final display = members.take(3).toList();

    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (display.isNotEmpty)
            Positioned(
              left: 0,
              top: 6,
              child: _UserAvatar(
                name:
                    display[0].user?.displayName ??
                    display[0].user?.username ??
                    '?',
                avatarUrl: display[0].user?.avatarUrl,
                radius: 12,
              ),
            ),
          if (display.length > 1)
            Positioned(
              left: 14,
              top: 0,
              child: _UserAvatar(
                name:
                    display[1].user?.displayName ??
                    display[1].user?.username ??
                    '?',
                avatarUrl: display[1].user?.avatarUrl,
                radius: 12,
              ),
            ),
          if (display.length > 2)
            Positioned(
              left: 10,
              top: 16,
              child: _UserAvatar(
                name:
                    display[2].user?.displayName ??
                    display[2].user?.username ??
                    '?',
                avatarUrl: display[2].user?.avatarUrl,
                radius: 12,
              ),
            ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.blur_circular_rounded,
                size: 11,
                color: Color(0xFF1274E7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeedGroupAvatar extends StatelessWidget {
  final String seed;
  final double size;

  const _SeedGroupAvatar({required this.seed, this.size = 42});

  Color _colorForIndex(int index) {
    const colors = [Color(0xFF11C5B7), Color(0xFF4F7DF3), Color(0xFF6E63F6)];
    return colors[index % colors.length];
  }

  String _initialForIndex(int index) {
    if (seed.isEmpty) return '?';
    final chars = seed.replaceAll(' ', '');
    if (chars.isEmpty) return '?';
    return chars[index % chars.length].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final small = size * 0.50;

    return SizedBox(
      width: size + 12,
      height: size + 4,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 6,
            child: _MiniSeedCircle(
              size: small,
              label: _initialForIndex(0),
              color: _colorForIndex(0),
            ),
          ),
          Positioned(
            left: size * 0.30,
            top: 0,
            child: _MiniSeedCircle(
              size: small,
              label: _initialForIndex(1),
              color: _colorForIndex(1),
            ),
          ),
          Positioned(
            left: size * 0.18,
            top: size * 0.34,
            child: _MiniSeedCircle(
              size: small,
              label: _initialForIndex(2),
              color: _colorForIndex(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSeedCircle extends StatelessWidget {
  final double size;
  final String label;
  final Color color;

  const _MiniSeedCircle({
    required this.size,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;

  const _UserAvatar({required this.name, this.avatarUrl, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEDE9FE),
      backgroundImage: avatarUrl != null && avatarUrl!.trim().isNotEmpty
          ? NetworkImage(avatarUrl!)
          : null,
      child: avatarUrl == null || avatarUrl!.trim().isEmpty
          ? Text(
              initial,
              style: TextStyle(
                color: const Color(0xFF5B21B6),
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.85,
              ),
            )
          : null,
    );
  }
}

class _CircleMembersDrawer extends StatelessWidget {
  final Circle circle;

  const _CircleMembersDrawer({required this.circle});

  @override
  Widget build(BuildContext context) {
    final members = circle.members ?? [];

    return Drawer(
      width: 320,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Members',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: members.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No member details available yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final provider = context.watch<MessagesProvider>();

                        final onlineMembers = members.where((m) {
                          final userId = m.user?.id;
                          return userId != null &&
                              provider.onlineUserIds.contains(userId);
                        }).toList();

                        final offlineMembers = members.where((m) {
                          final userId = m.user?.id;
                          return userId == null ||
                              !provider.onlineUserIds.contains(userId);
                        }).toList();

                        Widget buildMemberTile(
                          CircleMember member, {
                          required bool online,
                        }) {
                          final name =
                              member.user?.displayName ??
                              member.user?.username ??
                              'Unknown';

                          return ListTile(
                            leading: Stack(
                              children: [
                                _UserAvatar(
                                  name: name,
                                  avatarUrl: member.user?.avatarUrl,
                                  radius: 20,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 11,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      color: online
                                          ? Colors.green
                                          : Colors.grey,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: Text(
                              online ? 'Online' : 'Offline',
                              style: const TextStyle(color: Color(0xFF64748B)),
                            ),
                          );
                        }

                        return ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            if (onlineMembers.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  6,
                                  18,
                                  8,
                                ),
                                child: Text(
                                  'ONLINE — ${onlineMembers.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    letterSpacing: 0.6,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              ...onlineMembers.map(
                                (m) => buildMemberTile(m, online: true),
                              ),
                            ],
                            if (offlineMembers.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  14,
                                  18,
                                  8,
                                ),
                                child: Text(
                                  'OFFLINE — ${offlineMembers.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    letterSpacing: 0.6,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              ...offlineMembers.map(
                                (m) => buildMemberTile(m, online: false),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleInfoSheet extends StatelessWidget {
  final Circle circle;

  const _CircleInfoSheet({required this.circle});

  @override
  Widget build(BuildContext context) {
    final memberCount =
        circle.messageCount?.members ?? circle.members?.length ?? 0;
    final messageCount = circle.messageCount?.messages ?? 0;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FBFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD7E3F0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _SeedGroupAvatar(seed: circle.name, size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          circle.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          circle.isPrivate ? 'Private circle' : 'Public circle',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (circle.description != null &&
                  circle.description!.trim().isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    circle.description!,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.35,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              if (circle.description != null &&
                  circle.description!.trim().isNotEmpty)
                const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _InfoStatCard(
                      label: 'Members',
                      value: '$memberCount',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoStatCard(
                      label: 'Messages',
                      value: '$messageCount',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoStatCard extends StatelessWidget {
  final String label;
  final String value;

  const _InfoStatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
          ),
        ],
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
