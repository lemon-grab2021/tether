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
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  MessagesProvider? _messagesProvider;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      _messagesProvider = context.read<MessagesProvider>();
      await _messagesProvider!.loadMessages(widget.circle.id);
      await _messagesProvider!.connectToCircle(widget.circle.id);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesProvider?.disconnect();
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
      provider.sendMessage(
        circleId: widget.circle.id,
        body: text,
      );
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

  String _memberCountText() {
    final count = widget.circle.messageCount?.members ?? widget.circle.members?.length ?? 0;
    return '$count member${count == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessagesProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.user?.id;
    final messages = provider.messages;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messages.isNotEmpty) {
        _scrollToBottom();
      }
    });

    final hasTypedText = _messageController.text.trim().isNotEmpty;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF3F7FB),
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
                        '${_memberCountText()}'
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
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded),
            color: const Color(0xFF475569),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
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
                            return _CircleConversationIntro(circle: widget.circle);
                          }

                          final message = messages[index - 1];
                          final prev = index - 2 >= 0 ? messages[index - 2] : null;
                          final next = index < messages.length ? messages[index] : null;

                          final isMe = message.senderId == currentUserId;
                          final senderChangedFromPrevious =
                              prev == null || prev.senderId != message.senderId;
                          final senderChangesNext =
                              next == null || next.senderId != message.senderId;

                          final showSender = !isMe && senderChangedFromPrevious;
                          final showAvatar = !isMe && senderChangesNext;
                          final showTimestamp = true;

                          return _CircleMessageBubble(
                            message: message,
                            isMe: isMe,
                            showSender: showSender,
                            showAvatar: showAvatar,
                            showTail: senderChangesNext,
                            showTimestamp: showTimestamp,
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBFF),
                border: const Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.attach_file_rounded),
                    color: const Color(0xFF64748B),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF4F8),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              minLines: 1,
                              maxLines: 4,
                              onChanged: (_) => setState(() {}),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                              decoration: InputDecoration(
                                hintText: 'Message ${widget.circle.name}...',
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.mood_outlined),
                            color: const Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: hasTypedText
                          ? const Color(0xFF1274E7)
                          : const Color(0xFFE2E8F0),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: hasTypedText && provider.isJoinedRoom ? _sendMessage : null,
                      icon: Icon(
                        hasTypedText ? Icons.send_rounded : Icons.mic_none_rounded,
                        color: hasTypedText ? Colors.white : const Color(0xFF64748B),
                      ),
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
    final memberCount = circle.messageCount?.members ?? circle.members?.length ?? 0;

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

  Color _senderColor(String name) {
    const colors = [
      Color(0xFF2563EB),
      Color(0xFF4F46E5),
      Color(0xFF0891B2),
      Color(0xFF0F766E),
      Color(0xFF7C3AED),
      Color(0xFF0284C7),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final senderName = message.sender?.displayName ?? 'Unknown';
    final senderAvatar = message.sender?.avatarUrl as String?;
    final formattedTime = DateFormat('h:mm a').format(message.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            SizedBox(
              width: 42,
              child: showAvatar
                  ? Align(
                      alignment: Alignment.bottomLeft,
                      child: _UserAvatar(
                        name: senderName,
                        avatarUrl: senderAvatar,
                        radius: 18,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSender)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 4),
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _senderColor(senderName),
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.68,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF1274E7) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(isMe ? 22 : (showTail ? 8 : 22)),
                      bottomRight: Radius.circular(isMe ? (showTail ? 8 : 22) : 22),
                    ),
                    border: isMe
                        ? null
                        : Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment:
                        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (message.body != null)
                        Text(
                          message.body!,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            color: isMe ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (message.mediaUrl != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              message.mediaUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      if (showTimestamp) ...[
                        const SizedBox(height: 6),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe
                                ? Colors.white.withOpacity(0.72)
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
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
                name: display[0].user?.displayName ?? display[0].user?.username ?? '?',
                avatarUrl: display[0].user?.avatarUrl,
                radius: 12,
              ),
            ),
          if (display.length > 1)
            Positioned(
              left: 14,
              top: 0,
              child: _UserAvatar(
                name: display[1].user?.displayName ?? display[1].user?.username ?? '?',
                avatarUrl: display[1].user?.avatarUrl,
                radius: 12,
              ),
            ),
          if (display.length > 2)
            Positioned(
              left: 10,
              top: 16,
              child: _UserAvatar(
                name: display[2].user?.displayName ?? display[2].user?.username ?? '?',
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

  const _SeedGroupAvatar({
    required this.seed,
    this.size = 42,
  });

  Color _colorForIndex(int index) {
    const colors = [
      Color(0xFF11C5B7),
      Color(0xFF4F7DF3),
      Color(0xFF6E63F6),
    ];
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

  const _UserAvatar({
    required this.name,
    this.avatarUrl,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEDE9FE),
      backgroundImage:
          avatarUrl != null && avatarUrl!.trim().isNotEmpty ? NetworkImage(avatarUrl!) : null,
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
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final name = member.user?.displayName ??
                            member.user?.username ??
                            'Unknown';

                        return ListTile(
                          leading: _UserAvatar(
                            name: name,
                            avatarUrl: member.user?.avatarUrl,
                            radius: 20,
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Text(
                            member.role,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                            ),
                          ),
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
    final memberCount = circle.messageCount?.members ?? circle.members?.length ?? 0;
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
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                          ),
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
              if (circle.description != null && circle.description!.trim().isNotEmpty)
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
              if (circle.description != null && circle.description!.trim().isNotEmpty)
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

  const _InfoStatCard({
    required this.label,
    required this.value,
  });

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
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}