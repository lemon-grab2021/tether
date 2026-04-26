import 'dart:async';
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
import '../../widgets/tether_visual_kit.dart';

enum LinksTab { links, requests, discover }

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
  Timer? _searchDebounce;

  LinksTab _activeTab = LinksTab.links;

  int get _selectedTabIndex => LinksTab.values.indexOf(_activeTab);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LinksProvider>();
      provider.loadLinks();
      provider.loadRequests();
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final provider = context.read<LinksProvider>();
      provider.loadLinks();
      provider.loadRequests();

      if (_activeTab == LinksTab.discover &&
          _searchController.text.trim().isNotEmpty) {
        provider.searchUsers(_searchController.text.trim());
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final provider = context.read<LinksProvider>();
    await provider.loadLinks();
    await provider.loadRequests();

    if (_activeTab == LinksTab.discover &&
        _searchController.text.trim().isNotEmpty) {
      await provider.searchUsers(_searchController.text.trim());
    }
  }

  Future<void> _openDirectChat(LinkUser user) async {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user!.id;
    final token = await _authService.getAccessToken();

    if (token == null) {
      if (!mounted) return;
      _showSnack('You need to sign in again.', isError: true);
      return;
    }

    try {
      final conversation = await _directMessagesService.createOrGetConversation(
        token: token,
        otherUserId: user.id,
        currentUserId: currentUserId,
      );

      if (context.mounted) {
        await context.read<DirectConversationsProvider>().loadConversations(
          currentUserId: currentUserId,
        );
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

      if (!mounted) return;
      await context.read<DirectConversationsProvider>().loadConversations(
        currentUserId: currentUserId,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'Could not open conversation: ${e.toString().replaceAll('Exception: ', '')}',
        isError: true,
      );
    }
  }

  String _displayName(LinkUser user) {
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    return user.username;
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            isError ? TetherVisualPalette.danger : TetherVisualPalette.green,
      ),
    );
  }

  void _onSearchChanged(String value) {
    setState(() {});

    if (_activeTab != LinksTab.discover) return;

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      context.read<LinksProvider>().searchUsers(value.trim());
    });
  }

  Future<void> _sendLinkRequest(LinkUser user) async {
    final provider = context.read<LinksProvider>();

    try {
      await provider.sendLinkRequest(user.id);

      if (!mounted) return;
      _showSnack('Link request sent successfully');

      await provider.loadRequests();

      if (_searchController.text.trim().isNotEmpty) {
        await provider.searchUsers(_searchController.text.trim());
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'Failed to send link request: ${e.toString().replaceAll('Exception: ', '')}',
        isError: true,
      );
    }
  }

  Future<void> _respondToRequest(
    LinksProvider provider,
    int requestId,
    String action,
  ) async {
    try {
      await provider.respondToRequest(requestId, action);
      await provider.loadLinks();
      await provider.loadRequests();

      if (_activeTab == LinksTab.discover &&
          _searchController.text.trim().isNotEmpty) {
        await provider.searchUsers(_searchController.text.trim());
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        'Failed to update request: ${e.toString().replaceAll('Exception: ', '')}',
        isError: true,
      );
    }
  }

  void _changeTab(int index, LinksProvider provider) {
    final tab = LinksTab.values[index];
    setState(() => _activeTab = tab);

    if (tab == LinksTab.discover && _searchController.text.trim().isNotEmpty) {
      provider.searchUsers(_searchController.text.trim());
    }
  }

  Widget _loadingBlock() {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildLinksTab(LinksProvider provider) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredLinks = provider.links.where((link) {
      final user = link.user;
      if (query.isEmpty) return true;
      return _displayName(user).toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query);
    }).toList();

    if (provider.isLoading && provider.links.isEmpty) {
      return _loadingBlock();
    }

    if (filteredLinks.isEmpty) {
      return TetherEmptyState(
        icon: Icons.link_off_rounded,
        title: 'No links found',
        subtitle: query.isNotEmpty
            ? 'Try a different search term.'
            : 'Accepted connections will appear here and can be messaged directly.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TetherSectionTitle(
          text: query.isEmpty ? 'All Links' : 'Search Results',
          icon: Icons.link_rounded,
        ),
        TetherFadeSlide(
          child: TetherCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: List.generate(filteredLinks.length, (index) {
                final user = filteredLinks[index].user;
                return Column(
                  children: [
                    _LinkTile(
                      name: _displayName(user),
                      username: user.username,
                      avatarUrl: user.avatarUrl,
                      online: false,
                      onTap: () => _openDirectChat(user),
                    ),
                    if (index != filteredLinks.length - 1)
                      const Divider(
                        height: 1,
                        color: TetherVisualPalette.border,
                      ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsTab(LinksProvider provider) {
    if (provider.isLoading &&
        provider.incomingRequests.isEmpty &&
        provider.outgoingRequests.isEmpty) {
      return _loadingBlock();
    }

    if (provider.incomingRequests.isEmpty && provider.outgoingRequests.isEmpty) {
      return const TetherEmptyState(
        icon: Icons.mark_email_unread_outlined,
        title: 'No pending requests',
        subtitle: 'When someone sends you a link request, it will appear here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (provider.incomingRequests.isNotEmpty) ...[
          const TetherSectionTitle(
            text: 'Incoming Requests',
            icon: Icons.move_to_inbox_rounded,
          ),
          ...List.generate(provider.incomingRequests.length, (index) {
            final request = provider.incomingRequests[index];
            final sender = request.sender!;
            return TetherFadeSlide(
              delayMs: index * 30,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TetherCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          TetherUserAvatar(
                            name: _displayName(sender),
                            imageUrl: sender.avatarUrl,
                            size: 54,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayName(sender),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: TetherVisualPalette.text,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '@${sender.username}',
                                  style: const TextStyle(
                                    color: TetherVisualPalette.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: TetherSoftButton(
                              label: 'Decline',
                              icon: Icons.close_rounded,
                              color: TetherVisualPalette.muted,
                              onPressed: () => _respondToRequest(
                                provider,
                                request.id,
                                'decline',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TetherGradientButton(
                              label: 'Accept',
                              icon: Icons.check_rounded,
                              onPressed: () => _respondToRequest(
                                provider,
                                request.id,
                                'accept',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
        if (provider.outgoingRequests.isNotEmpty) ...[
          const SizedBox(height: 8),
          const TetherSectionTitle(
            text: 'Sent Requests',
            icon: Icons.outbox_rounded,
          ),
          TetherFadeSlide(
            child: TetherCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: List.generate(provider.outgoingRequests.length, (
                  index,
                ) {
                  final request = provider.outgoingRequests[index];
                  final receiver = request.receiver!;
                  return Column(
                    children: [
                      _PendingRequestTile(
                        name: _displayName(receiver),
                        username: receiver.username,
                        avatarUrl: receiver.avatarUrl,
                      ),
                      if (index != provider.outgoingRequests.length - 1)
                        const Divider(
                          height: 1,
                          color: TetherVisualPalette.border,
                        ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDiscoverTab(LinksProvider provider) {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      return const TetherEmptyState(
        icon: Icons.travel_explore_rounded,
        title: 'Discover people',
        subtitle: 'Search by username or display name to build your tether.',
      );
    }

    if (provider.isLoading && provider.searchResults.isEmpty) {
      return _loadingBlock();
    }

    if (provider.searchResults.isEmpty) {
      return const TetherEmptyState(
        icon: Icons.person_search_rounded,
        title: 'No people found',
        subtitle: 'Try a different search term.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TetherSectionTitle(
          text: 'People You May Know',
          icon: Icons.auto_awesome_rounded,
        ),
        ...List.generate(provider.searchResults.length, (index) {
          final result = provider.searchResults[index];
          final user = result.user;
          final relationship = result.relationship.toLowerCase().trim();

          Widget action;
          switch (relationship) {
            case 'link':
            case 'linked':
            case 'contact':
              action = SizedBox(
                width: 118,
                child: TetherSoftButton(
                  label: 'Message',
                  icon: Icons.chat_bubble_outline_rounded,
                  onPressed: () => _openDirectChat(user),
                ),
              );
              break;
            case 'outgoing_pending':
              action = const _StatusPill(text: 'Pending');
              break;
            case 'incoming_pending':
              action = SizedBox(
                width: 106,
                child: TetherGradientButton(
                  label: 'Accept',
                  expanded: true,
                  onPressed: result.requestId == null
                      ? null
                      : () => _respondToRequest(
                            provider,
                            result.requestId!,
                            'accept',
                          ),
                ),
              );
              break;
            default:
              action = SizedBox(
                width: 92,
                child: TetherGradientButton(
                  label: 'Add',
                  icon: Icons.person_add_alt_1_rounded,
                  expanded: true,
                  onPressed: () => _sendLinkRequest(user),
                ),
              );
          }

          return TetherFadeSlide(
            delayMs: index * 30,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TetherCard(
                child: Row(
                  children: [
                    TetherUserAvatar(
                      name: _displayName(user),
                      imageUrl: user.avatarUrl,
                      size: 54,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName(user),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: TetherVisualPalette.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${user.username}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: TetherVisualPalette.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    action,
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LinksProvider>();
    final incomingCount = provider.incomingRequests.length;

    return Scaffold(
      backgroundColor: TetherVisualPalette.background,
      body: TetherPageBackground(
        child: SafeArea(
          child: Column(
            children: [
              TetherHeader(
                title: 'Links',
                subtitle: 'Manage your trusted connections',
                leading: const TetherIconBadge(icon: Icons.link_rounded),
                actions: [
                  TetherHeaderAction(
                    icon: Icons.refresh_rounded,
                    onPressed: _refresh,
                  ),
                ],
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                    children: [
                      TetherSearchField(
                        controller: _searchController,
                        hintText: _activeTab == LinksTab.discover
                            ? 'Search people...'
                            : 'Search links...',
                        onChanged: _onSearchChanged,
                        onClear: () {
                          setState(() {});
                          if (_activeTab == LinksTab.discover) {
                            context.read<LinksProvider>().searchUsers('');
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      TetherSegmentedTabs(
                        tabs: const ['Links', 'Requests', 'Discover'],
                        selectedIndex: _selectedTabIndex,
                        badges: {1: incomingCount},
                        onChanged: (index) => _changeTab(index, provider),
                      ),
                      const SizedBox(height: 20),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: KeyedSubtree(
                          key: ValueKey(_activeTab),
                          child: switch (_activeTab) {
                            LinksTab.links => _buildLinksTab(provider),
                            LinksTab.requests => _buildRequestsTab(provider),
                            LinksTab.discover => _buildDiscoverTab(provider),
                          },
                        ),
                      ),
                    ],
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

class _LinkTile extends StatelessWidget {
  final String name;
  final String username;
  final String? avatarUrl;
  final bool online;
  final VoidCallback onTap;

  const _LinkTile({
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.online,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            TetherUserAvatar(
              name: name,
              imageUrl: avatarUrl,
              size: 52,
              online: online,
              showOnline: true,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15.5,
                      color: TetherVisualPalette.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@$username',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TetherVisualPalette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: TetherVisualPalette.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 20,
                color: TetherVisualPalette.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingRequestTile extends StatelessWidget {
  final String name;
  final String username;
  final String? avatarUrl;

  const _PendingRequestTile({
    required this.name,
    required this.username,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          TetherUserAvatar(name: name, imageUrl: avatarUrl, size: 52),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                    color: TetherVisualPalette.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '@$username',
                  style: const TextStyle(
                    color: TetherVisualPalette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const _StatusPill(text: 'Pending'),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;

  const _StatusPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: TetherVisualPalette.primary,
          fontWeight: FontWeight.w900,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
