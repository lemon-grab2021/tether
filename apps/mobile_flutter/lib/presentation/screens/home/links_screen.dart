import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tether/providers/direct_conversations_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/links_provider.dart';
import '../../../providers/direct_messages_provider.dart';
import '../../../data/models/link_user.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/direct_messages_service.dart';
import '../chat/direct_chat_screen.dart';
import '../../widgets/app_avatar.dart';
import 'dart:async';


class LinksScreen extends StatefulWidget {
  const LinksScreen({super.key});

  @override
  State<LinksScreen> createState() => _LinksScreenState();
  
}

class _LinksScreenState extends State<LinksScreen> {
  final _searchController = TextEditingController();
  final _directMessagesService = DirectMessagesService();
  final _authService = AuthService();
  
  Timer? _refreshTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LinksProvider>();
      provider.loadLinks();
      provider.loadRequests();
    });

    // periodic refresh every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5),  (_) {
      if (!mounted) return;
      final provider = context.read<LinksProvider>();
      provider.loadLinks();
      provider.loadRequests();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openDirectChat(LinkUser user) async {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user!.id;
    final token = await _authService.getAccessToken();

    final conversation = await _directMessagesService.createOrGetConversation(
      token: token!,
      otherUserId: user.id,
      currentUserId: currentUserId,
    );

    // Refresh Home Screens dm list immediately after creating a new conversation 
    if (context.mounted){ 
      // ignore: use_build_context_synchronously
      await context.read<DirectConversationsProvider>().loadConversations(
        currentUserId: currentUserId,
      );
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => DirectMessagesProvider(),
          child: DirectChatScreen(conversation: conversation),
        ),
      ),
    );

    // Refresh again after returning to the chat screen so the latest messages show up
    if (!mounted) return;
    await context.read<DirectConversationsProvider>().loadConversations(
      currentUserId: currentUserId,
    );

  }

  
  String _displayName(LinkUser user) {
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!;
    }
    return user.username;
  }

  Widget _buildAvatar(LinkUser user) {
    final name = _displayName(user);
    return AppAvatar(
      name: name,
      avatarUrl: user.avatarUrl,
      radius: 24,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LinksProvider>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          title: const Text(
            'Links',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Links'),
              Tab(text: 'Requests'),
              Tab(text: 'Discover'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: provider.loadLinks,
              child: provider.links.isEmpty
                  ? const _EmptyState(
                      icon: Icons.people_outline,
                      title: 'No Links yet',
                      subtitle:
                          'Accepted connections will appear here and can be messaged directly.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: provider.links.length,
                      itemBuilder: (context, index) {
                        final link = provider.links[index];
                        final user = link.user;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
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
                                _buildAvatar(user),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _displayName(user),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '@${user.username}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _openDirectChat(user),
                                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                                  label: const Text('Message'),
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
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

            RefreshIndicator(
              onRefresh: provider.loadRequests,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Incoming Requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (provider.incomingRequests.isEmpty)
                    const _MiniInfoCard(
                      text: 'No incoming requests right now.',
                    )
                  else
                    ...provider.incomingRequests.map((request) {
                      final sender = request.sender!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _buildAvatar(sender),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _displayName(sender),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '@${sender.username}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => provider.respondToRequest(
                                        request.id,
                                        'decline',
                                      ),
                                      child: const Text('Decline'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () => provider.respondToRequest(
                                        request.id,
                                        'accept',
                                      ),
                                      child: const Text('Accept'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                  const Text(
                    'Outgoing Requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (provider.outgoingRequests.isEmpty)
                    const _MiniInfoCard(
                      text: 'No outgoing requests.',
                    )
                  else
                    ...provider.outgoingRequests.map((request) {
                      final receiver = request.receiver!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              _buildAvatar(receiver),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _displayName(receiver),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '@${receiver.username}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF4F4F5),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Pending',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),

            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by username or display name',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: provider.searchUsers,
                  ),
                ),
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : provider.searchResults.isEmpty
                          ? const _EmptyState(
                              icon: Icons.person_search_outlined,
                              title: 'Connect with others',
                              subtitle:
                                  'Search by username or display name to build your tether.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: provider.searchResults.length,
                              itemBuilder: (context, index) {
                                final result = provider.searchResults[index];
                                final user = result.user;

                                Widget trailing;
                                switch (result.relationship) {
                                  case 'link':
                                    trailing = ElevatedButton(
                                      onPressed: () => _openDirectChat(user),
                                      child: const Text('Message'),
                                    );
                                    break;
                                  case 'outgoing_pending':
                                    trailing = const _Badge(text: 'Pending');
                                    break;
                                  case 'incoming_pending':
                                    trailing = ElevatedButton(
                                      onPressed: result.requestId == null
                                          ? null
                                          : () => provider.respondToRequest(
                                                result.requestId!,
                                                'accept',
                                              ),
                                      child: const Text('Accept'),
                                    );
                                    break;
                                  default:
                                    trailing = ElevatedButton(
                                      onPressed: () async {
                                        await provider.sendLinkRequest(user.id);
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Link request sent successfully',
                                            ),
                                          ),
                                        );
                                        provider.searchUsers(_searchController.text);
                                        provider.loadRequests();
                                      },
                                      child: const Text('Add'),
                                    );
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildAvatar(user),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _displayName(user),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '@${user.username}',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        trailing,
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 62, color: Colors.blueGrey),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInfoCard extends StatelessWidget {
  final String text;

  const _MiniInfoCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey[700]),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}