import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/circles_provider.dart';
import '../../../providers/direct_conversations_provider.dart';
import '../../../providers/direct_messages_provider.dart';
import '../../../providers/deleted_conversations_provider.dart';

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
          context
              .read<DirectConversationsProvider>()
              .refreshConversationsSilently(currentUserId: currentUserId);
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
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
    required DeletedConversationsProvider deletedProvider,
    required int? currentUserId,
  }) {
    final items = <_InboxItem>[];

    for (final conversation in directConversationsProvider.conversations.where(
      (c) => !deletedProvider.isDirectConversationDeleted(c.id),
    )) {
      final otherUser = conversation.otherUser;

      final name =
          (otherUser.displayName != null &&
              otherUser.displayName!.trim().isNotEmpty)
          ? otherUser.displayName!.trim()
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
          type: _InboxItemType.direct,
          sortAt:
              conversation.lastMessage?.createdAt ?? conversation.lastMessageAt,
          leading: AppAvatar(
            name: name,
            avatarUrl: otherUser.avatarUrl,
            radius: 26,
          ),
          title: name,
          subtitle: preview,
          timeLabel: _formatRelativeTime(
            conversation.lastMessage?.createdAt ?? conversation.lastMessageAt,
          ),
          badgeCount: isUnread ? 1 : null,
          subtitleBold: isUnread,
          isTyping: false,
          memberCount: null,
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

    for (final circle in circlesProvider.circles.where(
      (c) => !deletedProvider.isCircleDeleted(c.id),
    )) {
      final preview =
          (circle.description != null && circle.description!.trim().isNotEmpty)
              ? circle.description!
              : 'Circle conversation';

      items.add(
        _InboxItem(
          type: _InboxItemType.circle,
          sortAt: circle.updatedAt,
          leading: _CircleClusterAvatar(seed: circle.name),
          title: circle.name,
          subtitle: preview,
          timeLabel: _formatRelativeTime(circle.updatedAt),
          badgeCount: null,
          subtitleBold: false,
          isTyping: false,
          memberCount: null,
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
    final deletedProvider = context.watch<DeletedConversationsProvider>();
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
      deletedProvider: deletedProvider,
      currentUserId: currentUserId,
    );

    final totalUnread = _totalUnreadCount(
      directConversationsProvider: directConversationsProvider,
      currentUserId: currentUserId,
    );

    final isInitialLoading =
        (!directConversationsProvider.hasLoadedOnce &&
                directConversationsProvider.conversations.isEmpty) &&
            circlesProvider.isLoading &&
            circlesProvider.circles.isEmpty;

    final hasLoadError = inboxItems.isEmpty &&
        (directConversationsProvider.error != null ||
            circlesProvider.error != null);

    return Scaffold(
      backgroundColor: _TetherPalette.background,
      body: Stack(
        children: [
          const _DecorativeBackground(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshHome,
              color: _TetherPalette.primary,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HomeHeader(
                              hasNotifications: totalUnread > 0,
                              onSearch: _openSearchTab,
                              onNotifications: () {},
                              onProfile: _openProfileTab,
                            ),
                            const SizedBox(height: 18),
                            _WelcomeHeroCard(
                              greeting: _getGreeting(),
                              displayName: displayName,
                              unreadCount: totalUnread,
                            ),
                            const SizedBox(height: 24),
                            _QuickActionRow(
                              onCreate: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => const CreateCircleDialog(),
                                );
                              },
                              onJoin: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => const JoinCircleDialog(),
                                );
                              },
                              onLinks: _openLinksTab,
                            ),
                            const SizedBox(height: 28),
                            _SectionHeader(
                              title: 'Recent Conversations',
                              countLabel: '${inboxItems.length} active',
                            ),
                            const SizedBox(height: 14),
                            if (isInitialLoading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 42),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: _TetherPalette.primary,
                                  ),
                                ),
                              )
                            else if (hasLoadError)
                              _MessageEmptyState(
                                title: 'Could not load messages',
                                subtitle: directConversationsProvider.error ??
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
                              ...List.generate(inboxItems.length, (index) {
                                final item = inboxItems[index];
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: Duration(
                                    milliseconds: 260 + (index * 35),
                                  ),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 16 * (1 - value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _ConversationCard(
                                      item: item,
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _InboxItemType { direct, circle }

class _InboxItem {
  final _InboxItemType type;
  final DateTime sortAt;
  final Widget leading;
  final String title;
  final String subtitle;
  final String timeLabel;
  final int? badgeCount;
  final bool subtitleBold;
  final bool isTyping;
  final int? memberCount;
  final VoidCallback onTap;

  const _InboxItem({
    required this.type,
    required this.sortAt,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    required this.onTap,
    this.badgeCount,
    this.subtitleBold = false,
    this.isTyping = false,
    this.memberCount,
  });
}

class _TetherPalette {
  static const Color background = Color(0xFFFBFAFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);
  static const Color softMuted = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFECEAF8);

  static const Color primary = Color(0xFF6C5CFF);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color accent = Color(0xFFD66BEE);
  static const Color teal = Color(0xFF12B8B0);
  static const Color green = Color(0xFF22C55E);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF5D5FEF),
      Color(0xFF7B61FF),
      Color(0xFFD76BEF),
    ],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6C5CFF),
      Color(0xFF7B61FF),
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD66BEE),
      Color(0xFFBD5FEA),
    ],
  );
}

class _DecorativeBackground extends StatelessWidget {
  const _DecorativeBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _TetherPalette.background,
                    const Color(0xFFFFFFFF),
                    _TetherPalette.primary.withOpacity(0.035),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -120,
            child: _BlurOrb(
              size: 280,
              color: _TetherPalette.primary.withOpacity(0.10),
            ),
          ),
          Positioned(
            top: 240,
            left: -110,
            child: _BlurOrb(
              size: 230,
              color: _TetherPalette.accent.withOpacity(0.10),
            ),
          ),
          Positioned(
            bottom: 120,
            right: -90,
            child: _BlurOrb(
              size: 220,
              color: _TetherPalette.primary.withOpacity(0.07),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 80,
            spreadRadius: 30,
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final bool hasNotifications;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  const _HomeHeader({
    required this.hasNotifications,
    required this.onSearch,
    required this.onNotifications,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _GradientLogoButton(),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tether',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: _TetherPalette.text,
                ),
              ),
              SizedBox(height: 1),
              Text(
                'Stay connected',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _TetherPalette.muted,
                ),
              ),
            ],
          ),
        ),
        _HeaderIconButton(
          icon: Icons.search_rounded,
          onPressed: onSearch,
        ),
        _HeaderIconButton(
          icon: Icons.notifications_none_rounded,
          showBadge: hasNotifications,
          onPressed: onNotifications,
        ),
        _HeaderIconButton(
          icon: Icons.settings_outlined,
          onPressed: onProfile,
        ),
      ],
    );
  }
}

class _GradientLogoButton extends StatelessWidget {
  const _GradientLogoButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 47,
      height: 47,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _TetherPalette.primary.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: _TetherPalette.primaryGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: CustomPaint(
            painter: _TetherIconPainter(
              color: Colors.white,
              strokeFactor: 0.10,
              fillOpacity: 0.00,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final bool showBadge;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.onPressed,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          onPressed: onPressed,
          splashRadius: 22,
          icon: Icon(
            icon,
            color: _TetherPalette.muted,
            size: 23,
          ),
        ),
        if (showBadge)
          Positioned(
            top: 9,
            right: 10,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _TetherPalette.accentGradient,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _WelcomeHeroCard extends StatelessWidget {
  final String greeting;
  final String displayName;
  final int unreadCount;

  const _WelcomeHeroCard({
    required this.greeting,
    required this.displayName,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 164),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      decoration: BoxDecoration(
        gradient: _TetherPalette.heroGradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _TetherPalette.primary.withOpacity(0.28),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -58,
            right: -42,
            child: _HeroOrb(size: 128, opacity: 0.12),
          ),
          Positioned(
            bottom: -55,
            left: -40,
            child: _HeroOrb(size: 108, opacity: 0.10),
          ),
          Positioned(
            right: -4,
            top: -1,
            child: Opacity(
              opacity: 0.22,
              child: SizedBox(
                width: 92,
                height: 92,
                child: CustomPaint(
                  painter: const _TetherIconPainter(
                    color: Colors.white,
                    strokeFactor: 0.045,
                    fillOpacity: 0.00,
                  ),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 35,
                          height: 1.03,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text.rich(
                        TextSpan(
                          text: unreadCount > 0 ? 'You have ' : '',
                          children: [
                            if (unreadCount > 0)
                              TextSpan(
                                text: '$unreadCount unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            TextSpan(
                              text: unreadCount > 0
                                  ? ' messages'
                                  : 'All caught up!',
                            ),
                          ],
                        ),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroOrb extends StatelessWidget {
  final double size;
  final double opacity;

  const _HeroOrb({
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onJoin;
  final VoidCallback onLinks;

  const _QuickActionRow({
    required this.onCreate,
    required this.onJoin,
    required this.onLinks,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'Create',
            icon: Icons.add_rounded,
            gradient: _TetherPalette.primaryGradient,
            foreground: Colors.white,
            shadowColor: _TetherPalette.primary,
            onTap: onCreate,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: 'Join',
            icon: Icons.group_add_rounded,
            gradient: _TetherPalette.accentGradient,
            foreground: Colors.white,
            shadowColor: _TetherPalette.accent,
            onTap: onJoin,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: 'Links',
            icon: Icons.link_rounded,
            foreground: _TetherPalette.text,
            onTap: onLinks,
            isPlain: true,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final LinearGradient? gradient;
  final Color foreground;
  final Color? shadowColor;
  final VoidCallback onTap;
  final bool isPlain;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.onTap,
    this.gradient,
    this.shadowColor,
    this.isPlain = false,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapCancel: () => _setPressed(false),
        onTapUp: (_) => _setPressed(false),
        onTap: widget.onTap,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: widget.isPlain ? Colors.white : null,
            gradient: widget.isPlain ? null : widget.gradient,
            borderRadius: BorderRadius.circular(20),
            border: widget.isPlain
                ? Border.all(color: _TetherPalette.border, width: 1.2)
                : null,
            boxShadow: [
              BoxShadow(
                color: (widget.shadowColor ?? Colors.black).withOpacity(
                  widget.isPlain ? 0.08 : 0.24,
                ),
                blurRadius: widget.isPlain ? 14 : 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (!widget.isPlain)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                    ),
                  ),
                ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.icon,
                      size: 21,
                      color: widget.isPlain
                          ? _TetherPalette.primary
                          : widget.foreground,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String countLabel;

  const _SectionHeader({
    required this.title,
    required this.countLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _TetherPalette.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.1,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.82),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _TetherPalette.border),
            ),
            child: Text(
              countLabel,
              style: const TextStyle(
                color: _TetherPalette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatefulWidget {
  final _InboxItem item;

  const _ConversationCard({
    required this.item,
  });

  @override
  State<_ConversationCard> createState() => _ConversationCardState();
}

class _ConversationCardState extends State<_ConversationCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasUnread = item.badgeCount != null && item.badgeCount! > 0;
    final isCircle = item.type == _InboxItemType.circle;

    final accent = isCircle ? _TetherPalette.accent : _TetherPalette.primary;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: item.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: hasUnread
                ? LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white,
                      Colors.white,
                      accent.withOpacity(0.055),
                    ],
                  )
                : null,
            color: hasUnread ? null : Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: hasUnread
                  ? accent.withOpacity(0.20)
                  : Colors.white.withOpacity(0.85),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: hasUnread
                    ? accent.withOpacity(0.14)
                    : Colors.black.withOpacity(0.035),
                blurRadius: hasUnread ? 24 : 16,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  item.leading,
                  if (isCircle)
                    Positioned(
                      right: -3,
                      bottom: -4,
                      child: Container(
                        width: 19,
                        height: 19,
                        decoration: BoxDecoration(
                          gradient: _TetherPalette.accentGradient,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: _TetherPalette.accent.withOpacity(0.28),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(3.5),
                          child: CustomPaint(
                            painter: _TetherIconPainter(
                              color: Colors.white,
                              strokeFactor: 0.12,
                              fillOpacity: 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _TetherPalette.text,
                              fontSize: 16,
                              fontWeight:
                                  hasUnread ? FontWeight.w900 : FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (item.memberCount != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F4FA),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${item.memberCount} members',
                              style: const TextStyle(
                                color: _TetherPalette.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.isTyping ? 'typing...' : item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.isTyping
                            ? _TetherPalette.primary
                            : item.subtitleBold
                                ? _TetherPalette.text.withOpacity(0.82)
                                : _TetherPalette.muted,
                        fontSize: 14.5,
                        height: 1.2,
                        fontStyle:
                            item.isTyping ? FontStyle.italic : FontStyle.normal,
                        fontWeight:
                            item.subtitleBold ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.timeLabel.isNotEmpty)
                    Text(
                      item.timeLabel,
                      style: TextStyle(
                        color: hasUnread ? accent : _TetherPalette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  const SizedBox(height: 9),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasUnread)
                        Container(
                          width: 28,
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: isCircle
                                ? _TetherPalette.accentGradient
                                : _TetherPalette.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withOpacity(0.30),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Text(
                            item.badgeCount! > 99
                                ? '99+'
                                : '${item.badgeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      const SizedBox(width: 7),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _TetherPalette.softMuted,
                        size: 22,
                      ),
                    ],
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

class _CircleClusterAvatar extends StatelessWidget {
  final String seed;

  const _CircleClusterAvatar({required this.seed});

  Color _colorForIndex(int index) {
    const colors = [
      Color(0xFF10BFB7),
      Color(0xFF4F7DF3),
      Color(0xFF7467F4),
      Color(0xFFD66BEE),
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
    return SizedBox(
      width: 58,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 2,
            top: 5,
            child: _MiniCircle(
              label: _initialForIndex(0),
              color: _colorForIndex(0),
              size: 30,
            ),
          ),
          Positioned(
            left: 21,
            top: 0,
            child: _MiniCircle(
              label: _initialForIndex(1),
              color: _colorForIndex(1),
              size: 31,
            ),
          ),
          Positioned(
            left: 12,
            top: 22,
            child: _MiniCircle(
              label: _initialForIndex(2),
              color: _colorForIndex(2),
              size: 31,
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
  final double size;

  const _MiniCircle({
    required this.label,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.4),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.22),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MessageEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MessageEmptyState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.78),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _TetherPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _TetherPalette.primary.withOpacity(0.08),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 30,
              color: _TetherPalette.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              color: _TetherPalette.text,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _TetherPalette.muted,
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TetherIconPainter extends CustomPainter {
  final Color color;
  final double strokeFactor;
  final double fillOpacity;

  const _TetherIconPainter({
    required this.color,
    this.strokeFactor = 0.09,
    this.fillOpacity = 0.16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * strokeFactor
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color.withOpacity(fillOpacity)
      ..style = PaintingStyle.fill;

    final centerY = size.height / 2;
    final radius = size.width * 0.28;

    final left = Offset(size.width * 0.38, centerY);
    final right = Offset(size.width * 0.62, centerY);

    canvas.drawCircle(left, radius, fill);
    canvas.drawCircle(right, radius, fill);

    canvas.drawCircle(left, radius, stroke);
    canvas.drawCircle(right, radius, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}