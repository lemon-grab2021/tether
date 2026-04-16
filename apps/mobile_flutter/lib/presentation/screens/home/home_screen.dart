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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final circlesProvider = context.read<CirclesProvider>();
      final authProvider = context.read<AuthProvider>();
      final directConversationsProvider =
          context.read<DirectConversationsProvider>();

      circlesProvider.loadCircles();

      final currentUserId = authProvider.user?.id;
      if (currentUserId != null) {
        directConversationsProvider.loadConversations(
          currentUserId: currentUserId,
        );
      }
    });
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
    final welcomeName =
        (currentUser?.displayName != null &&
                currentUser!.displayName!.trim().isNotEmpty)
            ? currentUser.displayName!
            : (currentUser?.username ?? 'User');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Tether',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Links',
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider(
                    create: (_) => LinksProvider(),
                    child: const LinksScreen(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshHome,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome back',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    welcomeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionButton(
                          icon: Icons.add,
                          label: 'Create Circle',
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => const CreateCircleDialog(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickActionButton(
                          icon: Icons.group_add_outlined,
                          label: 'Join Circle',
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => const JoinCircleDialog(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _QuickActionButton(
                    icon: Icons.person_add_alt_1_outlined,
                    label: 'Open Links',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider(
                            create: (_) => LinksProvider(),
                            child: const LinksScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Direct Messages',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),

            if (directConversationsProvider.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (directConversationsProvider.error != null)
              _StatusCard(
                icon: Icons.error_outline,
                title: 'Could not load direct messages',
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
              _StatusCard(
                icon: Icons.chat_bubble_outline,
                title: 'No direct messages yet',
                subtitle: 'Start a conversation from Links.',
                actionLabel: 'Open Links',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider(
                        create: (_) => LinksProvider(),
                        child: const LinksScreen(),
                      ),
                    ),
                  );
                },
              )
            else
              ...directConversationsProvider.conversations.map((conversation) {
                final otherUser = conversation.otherUser;
                final displayName =
                    (otherUser.displayName != null &&
                            otherUser.displayName!.trim().isNotEmpty)
                        ? otherUser.displayName!
                        : otherUser.username;

                final preview =
                    conversation.lastMessage?.body?.trim().isNotEmpty == true
                        ? conversation.lastMessage!.body!
                        : conversation.lastMessage?.mediaUrl != null
                            ? 'Sent an attachment'
                            : 'Start your conversation';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
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
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          AppAvatar(
                            name: displayName,
                            avatarUrl: otherUser.avatarUrl,
                            radius: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              }),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Circles',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${circlesProvider.circles.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (circlesProvider.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (circlesProvider.error != null)
              _StatusCard(
                icon: Icons.error_outline,
                title: 'Could not load circles',
                subtitle: circlesProvider.error!,
                actionLabel: 'Retry',
                onAction: () => circlesProvider.loadCircles(),
              )
            else if (circlesProvider.circles.isEmpty)
              _StatusCard(
                icon: Icons.circle_outlined,
                title: 'No circles yet',
                subtitle: 'Join an existing circle or create a new one.',
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(circle: circle),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFFEDE9FE),
                            child: Text(
                              circle.name.isNotEmpty
                                  ? circle.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Color(0xFF5B21B6),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  circle.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (circle.description != null &&
                                          circle.description!.trim().isNotEmpty)
                                      ? circle.description!
                                      : 'No description',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.16),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(icon, size: 54, color: Colors.blueGrey),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}