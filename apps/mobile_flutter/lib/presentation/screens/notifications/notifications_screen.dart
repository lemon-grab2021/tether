import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/circles_provider.dart';
import '../../../providers/direct_conversations_provider.dart';
import '../../../providers/direct_messages_provider.dart';

import '../chat/chat_screen.dart';
import '../chat/direct_chat_screen.dart';
import '../../screens/home/links_screen.dart';
import '../../../data/models/tether_notification.dart';
import '../../../providers/notifications_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationsProvider>().loadNotifications();
    });
  }

  int? _metadataInt(dynamic metadata, String key) {
    if (metadata == null) return null;

    final value = metadata[key];

    if (value is int) return value;
    if (value is String) return int.tryParse(value);

    return null;
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'DIRECT_MESSAGE':
        return Icons.chat_bubble_outline_rounded;
      case 'CIRCLE_MESSAGE':
        return Icons.blur_circular_rounded;
      case 'LINK_REQUEST':
        return Icons.person_add_alt_1_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'DIRECT_MESSAGE':
        return const Color(0xFF6F63F6);
      case 'CIRCLE_MESSAGE':
        return const Color(0xFF11C5B7);
      case 'LINK_REQUEST':
        return const Color(0xFFD96BEF);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(local.year, local.month, local.day);

    final time = DateFormat('h:mm a').format(local);

    if (target == today) return 'Today at $time';
    if (target == yesterday) return 'Yesterday at $time';

    return DateFormat('dd/MM/yyyy, h:mm a').format(local);
  }

  Future<void> _openLinkRequestNotification() async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LinksScreen(initialTab: LinksTab.requests, showBackButton: true,),
      ),
    );
  }

  Future<void> _openNotification(dynamic notification) async {
    final notificationsProvider = context.read<NotificationsProvider>();

    // Mark notification as read first so the badge updates immediately.
    try {
      await notificationsProvider.markAsRead(notification.id);
    } catch (_) {
      // Keep navigation working even if mark-as-read fails.
    }

    final type = notification.type.toString().toUpperCase();
    final metadata = notification.metadata;

    switch (type) {
      case 'DIRECT_MESSAGE':
      case 'DM':
      case 'DIRECT':
        await _openDirectMessageNotification(metadata);
        break;

      case 'CIRCLE_MESSAGE':
      case 'CIRCLE':
      case 'GROUP_MESSAGE':
        await _openCircleMessageNotification(metadata);
        break;

      case 'LINK_REQUEST':
      case 'LINK':
      case 'REQUEST':
        await _openLinkRequestNotification();
        break;

      default:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unsupported notification type: $type'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }

    if (mounted) {
      await notificationsProvider.refreshUnreadCount();
    }
  }

  Future<void> _openDirectMessageNotification(dynamic metadata) async {
    final conversationId = _metadataInt(metadata, 'conversationId');

    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This notification is missing a conversation ID.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final directProvider = context.read<DirectConversationsProvider>();
    final currentUserId = authProvider.user?.id;

    if (currentUserId == null) return;

    await directProvider.loadConversations(currentUserId: currentUserId);

    dynamic conversation;

    for (final item in directProvider.conversations) {
      if (item.id == conversationId) {
        conversation = item;
        break;
      }
    }

    if (conversation == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not find this direct conversation.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => DirectMessagesProvider(),
          child: DirectChatScreen(conversation: conversation),
        ),
      ),
    );

    if (mounted) {
      await directProvider.loadConversations(currentUserId: currentUserId);
    }
  }

  Future<void> _openCircleMessageNotification(dynamic metadata) async {
    final circleId = _metadataInt(metadata, 'circleId');

    if (circleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This notification is missing a circle ID.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final circlesProvider = context.read<CirclesProvider>();

    await circlesProvider.loadCircles();

    dynamic circle;

    for (final item in circlesProvider.circles) {
      if (item.id == circleId) {
        circle = item;
        break;
      }
    }

    if (circle == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not find this circle.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(circle: circle)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();
    final notifications = provider.notifications;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FBFF),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF101828),
          ),
        ),
        actions: [
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: provider.markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6F63F6),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadNotifications(),
        child: provider.isLoading && notifications.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.error != null && notifications.isEmpty
            ? _ErrorState(
                message: provider.error!,
                onRetry: () => provider.loadNotifications(),
              )
            : notifications.isEmpty
            ? const _EmptyNotificationsState()
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final accent = _colorForType(notification.type);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _NotificationCard(
                      notification: notification,
                      accent: accent,
                      icon: _iconForType(notification.type),
                      dateLabel: _dateLabel(notification.createdAt),
                      onTap: () => _openNotification(notification),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final TetherNotification notification;
  final Color accent;
  final IconData icon;
  final String dateLabel;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.accent,
    required this.icon,
    required this.dateLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isUnread
                ? accent.withOpacity(0.40)
                : const Color(0xFFE4E7EC),
            width: isUnread ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(isUnread ? 0.08 : 0.03),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF101828),
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.35,
                      color: Color(0xFF667085),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF98A2B3),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Icon(
          Icons.notifications_none_rounded,
          size: 72,
          color: Color(0xFF98A2B3),
        ),
        SizedBox(height: 18),
        Center(
          child: Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
        ),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'New messages, link requests, and activity updates will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: Color(0xFF667085),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        const Icon(
          Icons.error_outline_rounded,
          size: 64,
          color: Color(0xFF98A2B3),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'Could not load notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF101828),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.4,
            color: Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: ElevatedButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}
