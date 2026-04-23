import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/circles_provider.dart';
import '../../../providers/direct_conversations_provider.dart';
import '../../../providers/direct_messages_provider.dart';

import '../chat/chat_screen.dart';
import '../chat/direct_chat_screen.dart';

import '../../widgets/app_avatar.dart';
import '../../widgets/create_circle_dialog.dart';
import '../../widgets/join_circle_dialog.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenLinksTab;
  final VoidCallback? onOpenProfileTab;
  final VoidCallback? onOpenSearchTab;

  const HomeScreen({
    super.key,
    this.onOpenLinksTab,
    this.onOpenProfileTab,
    this.onOpenSearchTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final circlesProvider = context.read<CirclesProvider>();
      final directConversationsProvider =
          context.read<DirectConversationsProvider>();

      circlesProvider.loadCircles();

      final currentUserId = authProvider.user?.id;
      if (currentUserId != null) {
        directConversationsProvider.loadConversations(
          currentUserId: currentUserId,
        );
      }

      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;

        final authProvider = context.read<AuthProvider>();
        final currentUserId = authProvider.user?.id;

        context.read<CirclesProvider>().refreshCirclesSilently();

        if (currentUserId != null) {
          context.read<DirectConversationsProvider>().refreshConversationsSilently(
                currentUserId: currentUserId,
              );
        }
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _openLinksTab() {
    widget.onOpenLinksTab?.call();
  }

  void _openProfileTab() {
    widget.onOpenProfileTab?.call();
  }

  void _openSearchTab() {
    widget.onOpenSearchTab?.call();
  }

  Future<void> _refreshHome() async {
    final authProvider = context.read<AuthProvider>();
    final circlesProvider = context.read<CirclesProvider>();
    final directConversationsProvider =
        context.read<DirectConversationsProvider>();

    await circlesProvider.loadCircles();

    final currentUserId = authProvider.user?.id;
    if (currentUserId != null) {
      await directConversationsProvider.loadConversations(
        currentUserId: currentUserId,
      );
    }
  }

  String _formatRelativeTime(DateTime? value) {
    if (value == null) return '';
    final now = DateTime.now();
    final diff = now.difference(value);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${value.day}/${value.month}';
  }

  bool _isUnreadForCurrentUser({
    required dynamic conversation,
    required int currentUserId,
  }) {
    final lastMessage = conversation.lastMessage;
    if (lastMessage == null) return false;
    if (lastMessage.senderId == currentUserId) return false;

    final myLastReadAt = conversation.userOneId == currentUserId
        ? conversation.userOneLastReadAt
        : conversation.userTwoLastReadAt;

    return myLastReadAt == null || myLastReadAt.isBefore(lastMessage.createdAt);
  }

  int _totalUnreadCount({
    required DirectConversationsProvider directConversationsProvider,
    required int? currentUserId,
  }) {
    if (currentUserId == null) return 0;

    return directConversationsProvider.conversations.where((conversation) {
      return _isUnreadForCurrentUser(
        conversation: conversation,
        currentUserId: currentUserId,
      );
    }).length;
  }

  List<_InboxItem> _buildInboxItems({
    required DirectConversationsProvider directConversationsProvider,
    required CirclesProvider circlesProvider,
    required int? currentUserId,
  }) {
    final items = <_InboxItem>[];

    for (final conversation in directConversationsProvider.conversations) {
      final otherUser = conversation.otherUser;

      final name =
          (otherUser.displayName != null &&
                  otherUser.displayName!.trim().isNotEmpty)
              ? otherUser.displayName!
              : otherUser.username;

      final preview = conversation.lastMessage?.body?.trim().isNotEmpty == true
          ? conversation.lastMessage!.body!
          : conversation.lastMessage?.mediaUrl != null
              ? 'Sent an attachment'
              : 'Start your conversation';

      final isUnread = currentUserId == null
          ? false
          : _isUnreadForCurrentUser(
              conversation: conversation,
              currentUserId: currentUserId,
            );

      items.add(
        _InboxItem(
          sortAt:
              conversation.lastMessage?.createdAt ?? conversation.lastMessageAt,
          leading: AppAvatar(
            name: name,
            avatarUrl: otherUser.avatarUrl,
            radius: 24,
          ),
          title: name,
          subtitle: preview,
          timeLabel: _formatRelativeTime(
            conversation.lastMessage?.createdAt ?? conversation.lastMessageAt,
          ),
          badgeCount: isUnread ? 1 : null,
          subtitleBold: isUnread,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => DirectMessagesProvider(),
                  child: DirectChatScreen(conversation: conversation),
                ),
              ),
            );
          },
        ),
      );
    }

    for (final circle in circlesProvider.circles) {
      final preview =
          (circle.description != null && circle.description!.trim().isNotEmpty)
              ? circle.description!
              : 'Circle conversation';

      items.add(
        _InboxItem(
          sortAt: circle.updatedAt,
          leading: _CircleClusterAvatar(seed: circle.name),
          title: circle.name,
          subtitle: preview,
          timeLabel: _formatRelativeTime(circle.updatedAt),
          badgeCount: null,
          subtitleBold: false,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(circle: circle)),
            );
          },
        ),
      );
    }

    items.sort((a, b) => b.sortAt.compareTo(a.sortAt));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final circlesProvider = context.watch<CirclesProvider>();
    final directConversationsProvider =
        context.watch<DirectConversationsProvider>();

    final user = authProvider.user;
    final displayName =
        (user?.displayName != null && user!.displayName!.trim().isNotEmpty)
            ? user.displayName!.trim()
            : (user?.username ?? 'User');

    final currentUserId = user?.id;

    final inboxItems = _buildInboxItems(
      directConversationsProvider: directConversationsProvider,
      circlesProvider: circlesProvider,
      currentUserId: currentUserId,
    );

    final totalUnread = _totalUnreadCount(
      directConversationsProvider: directConversationsProvider,
      currentUserId: currentUserId,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(7),
                child: CustomPaint(
                  painter: _TetherIconPainter(color: Color(0xFF1274E7)),
                ),
              ),
            ),
            const SizedBox(width: 15),
            const Text(
              'Tether',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            color: const Color(0xFF475569),
            onPressed: _openSearchTab,
          ),
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            color: const Color(0xFF475569),
            onPressed: _openLinksTab,
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            color: const Color(0xFF475569),
            onPressed: _openProfileTab,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshHome,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _WelcomeCard(displayName: displayName, unreadCount: totalUnread),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 80,
                    child: _ActionTile(
                      label: 'Create',
                      icon: Icons.add,
                      filled: true,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const CreateCircleDialog(),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 80,
                    child: _ActionTile(
                      label: 'Join',
                      icon: Icons.group_add_outlined,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const JoinCircleDialog(),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 80,
                    child: _ActionTile(
                      label: 'Links',
                      icon: Icons.link,
                      onTap: _openLinksTab,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'MESSAGES',
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
                Text(
                  '${inboxItems.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if ((!directConversationsProvider.hasLoadedOnce &&
                    directConversationsProvider.conversations.isEmpty) &&
                circlesProvider.isLoading &&
                circlesProvider.circles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (inboxItems.isEmpty &&
                (directConversationsProvider.error != null ||
                    circlesProvider.error != null))
              _MessageEmptyState(
                title: 'Could not load messages',
                subtitle:
                    directConversationsProvider.error ??
                    circlesProvider.error ??
                    'Something went wrong.',
              )
            else if (inboxItems.isEmpty)
              const _MessageEmptyState(
                title: 'No messages yet',
                subtitle:
                    'Create a circle, join one, or start a conversation from Links.',
              )
            else
              ...inboxItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MessageCard(
                    leading: item.leading,
                    title: item.title,
                    subtitle: item.subtitle,
                    timeLabel: item.timeLabel,
                    badgeCount: item.badgeCount,
                    subtitleBold: item.subtitleBold,
                    onTap: item.onTap,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _InboxItem {
  final DateTime sortAt;
  final Widget leading;
  final String title;
  final String subtitle;
  final String timeLabel;
  final int? badgeCount;
  final bool subtitleBold;
  final VoidCallback onTap;

  const _InboxItem({
    required this.sortAt,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.onTap,
    this.badgeCount,
    this.subtitleBold = false,
  });
}

class _WelcomeCard extends StatelessWidget {
  final String displayName;
  final int unreadCount;

  const _WelcomeCard({required this.displayName, required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 6,
            top: 4,
            child: Opacity(
              opacity: 0.20,
              child: SizedBox(
                width: 54,
                height: 54,
                child: CustomPaint(
                  painter: const _TetherIconPainter(
                    color: Color.fromARGB(255, 19, 142, 243),
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Spacer(),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$unreadCount unread',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Hello,',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Stay connected with the people who matter most to you.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _ActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = filled ? const Color(0xFF1274E7) : Colors.white;
    final foreground = filled ? Colors.white : const Color(0xFF0F172A);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(22),
      elevation: filled ? 2 : 0,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: foreground),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final String timeLabel;
  final int? badgeCount;
  final bool subtitleBold;
  final VoidCallback onTap;

  const _MessageCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.onTap,
    this.badgeCount,
    this.subtitleBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FBFF),
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: subtitleBold
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF475569),
                        fontWeight: subtitleBold
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (timeLabel.isNotEmpty)
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1274E7),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (badgeCount != null) ...[
                    if (timeLabel.isNotEmpty) const SizedBox(height: 8),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1274E7),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleClusterAvatar extends StatelessWidget {
  final String seed;

  const _CircleClusterAvatar({required this.seed});

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
    return SizedBox(
      width: 56,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 3,
            child: _MiniCircle(
              label: _initialForIndex(0),
              color: _colorForIndex(0),
            ),
          ),
          Positioned(
            left: 18,
            top: 0,
            child: _MiniCircle(
              label: _initialForIndex(1),
              color: _colorForIndex(1),
            ),
          ),
          Positioned(
            left: 9,
            top: 18,
            child: _MiniCircle(
              label: _initialForIndex(2),
              color: _colorForIndex(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniCircle extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniCircle({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MessageEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MessageEmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 44,
            color: Colors.blue.shade300,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TetherIconPainter extends CustomPainter {
  final Color color;

  const _TetherIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final center1 = Offset(size.width * 0.35, size.height * 0.4);
    final center2 = Offset(size.width * 0.65, size.height * 0.6);
    final radius = size.width * 0.25;

    canvas.drawLine(center1, center2, paint);
    canvas.drawCircle(center1, radius, fillPaint);
    canvas.drawCircle(center1, radius, paint);
    canvas.drawCircle(center2, radius, fillPaint);
    canvas.drawCircle(center2, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}