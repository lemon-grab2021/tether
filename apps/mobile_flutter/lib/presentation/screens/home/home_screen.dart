import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/circles_provider.dart';
import '../../../providers/links_provider.dart';
import '../../../providers/direct_conversations_provider.dart';
import '../../../providers/direct_messages_provider.dart';
import '../chat/chat_screen.dart';
import '../profile/profile_screen.dart';
import 'links_screen.dart';
import '../chat/direct_chat_screen.dart';
import '../../widgets/create_circle_dialog.dart';
import '../../widgets/join_circle_dialog.dart';
import '../../widgets/app_avatar.dart';
import 'dart:async';

// Brand colors for Tether
class TetherColors {
  static const Color primary = Color(0xFF2563EB); // Blue 600
  static const Color primaryLight = Color(0xFF3B82F6); // Blue 500
  static const Color primaryDark = Color(0xFF1D4ED8); // Blue 700
  static const Color accent = Color(0xFF0EA5E9); // Sky 500
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color unreadBadge = Color(0xFFEF4444); // Red 500
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final circlesProvider = context.read<CirclesProvider>();
      final directConversationsProvider =
          context.read<DirectConversationsProvider>();

      circlesProvider.loadCircles();

      // periodic refresh every 5 seconds
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;

        final authProvider = context.read<AuthProvider>();
        final currentUserId = authProvider.user?.id;

        context.read<CirclesProvider>().refreshCirclesSilently();

        if (currentUserId != null) {
          context
              .read<DirectConversationsProvider>()
              .refreshConversationsSilently(
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

  Future<void> _refreshHome() async {
    final circlesProvider = context.read<CirclesProvider>();
    final authProvider = context.read<AuthProvider>();
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final circlesProvider = context.watch<CirclesProvider>();
    final directConversationsProvider =
        context.watch<DirectConversationsProvider>();

    final currentUser = authProvider.user;
    final welcomeName = (currentUser?.displayName != null &&
            currentUser!.displayName!.trim().isNotEmpty)
        ? currentUser.displayName!
        : (currentUser?.username ?? 'User');

    return Scaffold(
      backgroundColor: TetherColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshHome,
          color: TetherColors.primary,
          child: CustomScrollView(
            slivers: [
              // Custom App Bar
              SliverToBoxAdapter(
                child: _TetherAppBar(
                  onLinksPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider(
                          create: (_) => LinksProvider(),
                          child: const LinksScreen(),
                        ),
                      ),
                    );
                    if (!mounted) return;
                    final currentUserId = context.read<AuthProvider>().user?.id;
                    if (currentUserId != null) {
                      await context
                          .read<DirectConversationsProvider>()
                          .loadConversations(
                            currentUserId: currentUserId,
                          );
                    }
                  },
                  onProfilePressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Welcome Panel
                    _WelcomePanel(
                      userName: welcomeName,
                      onCreateCircle: () {
                        showDialog(
                          context: context,
                          builder: (_) => const CreateCircleDialog(),
                        );
                      },
                      onJoinCircle: () {
                        showDialog(
                          context: context,
                          builder: (_) => const JoinCircleDialog(),
                        );
                      },
                      onOpenLinks: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider(
                              create: (_) => LinksProvider(),
                              child: const LinksScreen(),
                            ),
                          ),
                        );

                        if (!mounted) return;
                        final currentUserId =
                            context.read<AuthProvider>().user?.id;
                        if (currentUserId != null) {
                          await context
                              .read<DirectConversationsProvider>()
                              .loadConversations(
                                currentUserId: currentUserId,
                              );
                        }
                      },
                    ),

                    const SizedBox(height: 28),

                    // Direct Messages Section
                    _SectionHeader(
                      title: 'Direct Messages',
                      icon: Icons.chat_bubble_rounded,
                    ),
                    const SizedBox(height: 14),

                    if (!directConversationsProvider.hasLoadedOnce ||
                        (directConversationsProvider.isLoading &&
                            directConversationsProvider.conversations.isEmpty))
                      const _LoadingIndicator()
                    else if (directConversationsProvider.error != null)
                      _EmptyStateCard(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load messages',
                        subtitle: directConversationsProvider.error!,
                        actionLabel: 'Retry',
                        onAction: () {
                          final currentUserId = authProvider.user?.id;
                          if (currentUserId != null) {
                            directConversationsProvider.loadConversations(
                              currentUserId: currentUserId,
                            );
                          }
                        },
                      )
                    else if (directConversationsProvider.conversations.isEmpty)
                      _EmptyStateCard(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'No messages yet',
                        subtitle:
                            'Start a conversation from your Links to stay connected.',
                        actionLabel: 'Open Links',
                        onAction: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider(
                                create: (_) => LinksProvider(),
                                child: const LinksScreen(),
                              ),
                            ),
                          );
                          if (!mounted) return;
                          final currentUserId =
                              context.read<AuthProvider>().user?.id;
                          if (currentUserId != null) {
                            await context
                                .read<DirectConversationsProvider>()
                                .loadConversations(
                                  currentUserId: currentUserId,
                                );
                          }
                        },
                      )
                    else
                      ...directConversationsProvider.conversations
                          .map((conversation) {
                        final otherUser = conversation.otherUser;
                        final displayName = (otherUser.displayName != null &&
                                otherUser.displayName!.trim().isNotEmpty)
                            ? otherUser.displayName!
                            : otherUser.username;

                        final preview = conversation.lastMessage?.body
                                    ?.trim()
                                    .isNotEmpty ==
                                true
                            ? conversation.lastMessage!.body!
                            : conversation.lastMessage?.mediaUrl != null
                                ? 'Sent an attachment'
                                : 'Start your conversation';

                        final hasUnread = conversation.unreadCount > 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DirectMessageCard(
                            name: displayName,
                            avatarUrl: otherUser.avatarUrl,
                            preview: preview,
                            hasUnread: hasUnread,
                            unreadCount: conversation.unreadCount,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChangeNotifierProvider(
                                    create: (_) => DirectMessagesProvider(),
                                    child: DirectChatScreen(
                                        conversation: conversation),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }),

                    const SizedBox(height: 28),

                    // Circles Section
                    _SectionHeader(
                      title: 'Circles',
                      icon: Icons.blur_circular_rounded,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: TetherColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${circlesProvider.circles.length}',
                          style: const TextStyle(
                            color: TetherColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (circlesProvider.isLoading)
                      const _LoadingIndicator()
                    else if (circlesProvider.error != null)
                      _EmptyStateCard(
                        icon: Icons.error_outline_rounded,
                        title: 'Could not load circles',
                        subtitle: circlesProvider.error!,
                        actionLabel: 'Retry',
                        onAction: () => circlesProvider.loadCircles(),
                      )
                    else if (circlesProvider.circles.isEmpty)
                      _EmptyStateCard(
                        icon: Icons.blur_circular_rounded,
                        title: 'No circles yet',
                        subtitle:
                            'Create your own circle or join an existing one to connect with groups.',
                        actionLabel: 'Create Circle',
                        onAction: () {
                          showDialog(
                            context: context,
                            builder: (_) => const CreateCircleDialog(),
                          );
                        },
                      )
                    else
                      ...circlesProvider.circles.map((circle) {
                        final memberCount = circle.messageCount?.members ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CircleCard(
                            name: circle.name,
                            description: circle.description,
                            memberCount: memberCount,
                            isPrivate: circle.isPrivate,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(circle: circle),
                                ),
                              );
                            },
                          ),
                        );
                      }),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom App Bar with Tether branding
class _TetherAppBar extends StatelessWidget {
  final VoidCallback onLinksPressed;
  final VoidCallback onProfilePressed;

  const _TetherAppBar({
    required this.onLinksPressed,
    required this.onProfilePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          // Tether Logo/Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [TetherColors.primary, TetherColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: _TetherIcon(size: 24, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Tether',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: TetherColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          // Links Button
          _AppBarIconButton(
            icon: Icons.people_rounded,
            tooltip: 'Links',
            onPressed: onLinksPressed,
          ),
          const SizedBox(width: 8),
          // Profile Button
          _AppBarIconButton(
            icon: Icons.person_rounded,
            tooltip: 'Profile',
            onPressed: onProfilePressed,
          ),
        ],
      ),
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _AppBarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TetherColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TetherColors.border, width: 1),
          ),
          child: Icon(
            icon,
            color: TetherColors.textSecondary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// Welcome Panel with quick actions
class _WelcomePanel extends StatelessWidget {
  final String userName;
  final VoidCallback onCreateCircle;
  final VoidCallback onJoinCircle;
  final VoidCallback onOpenLinks;

  const _WelcomePanel({
    required this.userName,
    required this.onCreateCircle,
    required this.onJoinCircle,
    required this.onOpenLinks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TetherColors.primary, TetherColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: TetherColors.primary.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const _TetherIcon(size: 48, color: Colors.white24),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _QuickActionChip(
                  icon: Icons.add_rounded,
                  label: 'Create',
                  onTap: onCreateCircle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionChip(
                  icon: Icons.group_add_rounded,
                  label: 'Join',
                  onTap: onJoinCircle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionChip(
                  icon: Icons.link_rounded,
                  label: 'Links',
                  onTap: onOpenLinks,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Section Header
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: TetherColors.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: TetherColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// Direct Message Card
class _DirectMessageCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String preview;
  final bool hasUnread;
  final int unreadCount;
  final VoidCallback onTap;

  const _DirectMessageCard({
    required this.name,
    this.avatarUrl,
    required this.preview,
    this.hasUnread = false,
    this.unreadCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TetherColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: hasUnread
                  ? TetherColors.primary.withOpacity(0.3)
                  : TetherColors.border,
              width: hasUnread ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with online indicator style
              Stack(
                children: [
                  AppAvatar(
                    name: name,
                    avatarUrl: avatarUrl,
                    radius: 26,
                    backgroundColor: TetherColors.primary.withOpacity(0.1),
                    textColor: TetherColors.primary,
                  ),
                  if (hasUnread)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: TetherColors.unreadBadge,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 16,
                        color: TetherColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread
                            ? TetherColors.textPrimary
                            : TetherColors.textSecondary,
                        fontWeight:
                            hasUnread ? FontWeight.w500 : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (hasUnread && unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: TetherColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: TetherColors.textMuted,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Circle Card with connected circles motif
class _CircleCard extends StatelessWidget {
  final String name;
  final String? description;
  final int memberCount;
  final bool isPrivate;
  final VoidCallback onTap;

  const _CircleCard({
    required this.name,
    this.description,
    required this.memberCount,
    required this.isPrivate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TetherColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: TetherColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Connected circles icon
              _ConnectedCirclesAvatar(name: name),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: TetherColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPrivate) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: TetherColors.textMuted,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people_rounded,
                          size: 14,
                          color: TetherColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                          style: const TextStyle(
                            color: TetherColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (description != null &&
                            description!.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                              color: TetherColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: TetherColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.chevron_right_rounded,
                color: TetherColors.textMuted,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Connected circles visual motif for circles avatar
class _ConnectedCirclesAvatar extends StatelessWidget {
  final String name;

  const _ConnectedCirclesAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 52,
      height: 52,
      child: Stack(
        children: [
          // Background circle
          Positioned(
            left: 0,
            top: 6,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: TetherColors.accent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Foreground circle with initial
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    TetherColors.primary.withOpacity(0.15),
                    TetherColors.primaryLight.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: TetherColors.primary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: TetherColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Tether connected circles icon/logo
class _TetherIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _TetherIcon({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TetherIconPainter(color: color),
      ),
    );
  }
}

class _TetherIconPainter extends CustomPainter {
  final Color color;

  _TetherIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final center1 = Offset(size.width * 0.35, size.height * 0.4);
    final center2 = Offset(size.width * 0.65, size.height * 0.6);
    final radius = size.width * 0.25;

    // Draw connecting line
    canvas.drawLine(center1, center2, paint);

    // Draw circles
    canvas.drawCircle(center1, radius, fillPaint);
    canvas.drawCircle(center1, radius, paint);
    canvas.drawCircle(center2, radius, fillPaint);
    canvas.drawCircle(center2, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Loading Indicator
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: const Center(
        child: CircularProgressIndicator(
          color: TetherColors.primary,
          strokeWidth: 3,
        ),
      ),
    );
  }
}

// Empty State Card
class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: TetherColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TetherColors.border, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: TetherColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: TetherColors.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: TetherColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: TetherColors.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: TetherColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
