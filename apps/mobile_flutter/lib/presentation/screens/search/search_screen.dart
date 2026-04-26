import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/deleted_conversations_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/circles_provider.dart';
import '../../../providers/direct_conversations_provider.dart';
import '../../../providers/direct_messages_provider.dart';
import '../../../providers/links_provider.dart';

import '../../../data/models/circle.dart';
import '../../../data/models/direct_conversation.dart';
import '../../../data/models/link_user.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/direct_messages_service.dart';

import '../chat/chat_screen.dart';
import '../chat/direct_chat_screen.dart';
import '../../widgets/app_avatar.dart';

enum SearchFilter { all, messages, people, circles }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AuthService _authService = AuthService();
  final DirectMessagesService _directMessagesService = DirectMessagesService();

  Timer? _debounce;
  SearchFilter _activeFilter = SearchFilter.all;

  final List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final circlesProvider = context.read<CirclesProvider>();
      final directConversationsProvider = context
          .read<DirectConversationsProvider>();
      final linksProvider = context.read<LinksProvider>();
      final currentUserId = authProvider.user?.id;

      if (currentUserId != null &&
          directConversationsProvider.conversations.isEmpty) {
        await directConversationsProvider.loadConversations(
          currentUserId: currentUserId,
        );
      }

      if (circlesProvider.circles.isEmpty) {
        await circlesProvider.loadCircles();
      }

      if (linksProvider.links.isEmpty) {
        await linksProvider.loadLinks();
      }

      await linksProvider.loadRequests();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String get _query => _searchController.text.trim();

  bool get _hasQuery => _query.isNotEmpty;

  void _commitRecentSearch(String value) {
    final term = value.trim();
    if (term.isEmpty) return;

    setState(() {
      _recentSearches.removeWhere(
        (item) => item.toLowerCase() == term.toLowerCase(),
      );
      _recentSearches.insert(0, term);

      if (_recentSearches.length > 8) {
        _recentSearches.removeRange(8, _recentSearches.length);
      }
    });
  }

  void _onSearchChanged(String value) {
    setState(() {});

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      if (!mounted) return;

      final linksProvider = context.read<LinksProvider>();
      final q = value.trim();

      if (q.isEmpty) {
        setState(() => _activeFilter = SearchFilter.all);
        await linksProvider.searchUsers('');
        return;
      }

      await linksProvider.searchUsers(q);
    });
  }

  Future<void> _refreshSearch() async {
    final authProvider = context.read<AuthProvider>();
    final directProvider = context.read<DirectConversationsProvider>();
    final circlesProvider = context.read<CirclesProvider>();
    final linksProvider = context.read<LinksProvider>();

    final currentUserId = authProvider.user?.id;
    if (currentUserId != null) {
      await directProvider.loadConversations(currentUserId: currentUserId);
    }

    await circlesProvider.loadCircles();
    await linksProvider.loadLinks();
    await linksProvider.loadRequests();

    if (_query.isNotEmpty) {
      await linksProvider.searchUsers(_query);
    }
  }

  Future<void> _openDirectChat(LinkUser user) async {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user?.id;
    final token = await _authService.getAccessToken();

    if (currentUserId == null || token == null) return;

    final conversation = await _directMessagesService.createOrGetConversation(
      token: token,
      otherUserId: user.id,
      currentUserId: currentUserId,
    );

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
  }

  Future<void> _openConversationFromSearch(
    DirectConversation conversation,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final directProvider = context.read<DirectConversationsProvider>();
    final currentUserId = authProvider.user?.id;

    if (currentUserId == null) return;

    try {
      await directProvider.loadConversations(currentUserId: currentUserId);

      DirectConversation selectedConversation = conversation;

      try {
        selectedConversation = directProvider.conversations.firstWhere(
          (c) => c.id == conversation.id,
        );
      } catch (_) {
        selectedConversation = conversation;
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => DirectMessagesProvider(),
            child: DirectChatScreen(conversation: selectedConversation),
          ),
        ),
      );

      if (!mounted) return;

      await directProvider.loadConversations(currentUserId: currentUserId);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to open conversation: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _displayNameFromLinkUser(LinkUser user) {
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    return user.username;
  }

  String _displayNameFromConversation(DirectConversation conversation) {
    final otherUser = conversation.otherUser;
    if (otherUser.displayName != null &&
        otherUser.displayName!.trim().isNotEmpty) {
      return otherUser.displayName!.trim();
    }
    return otherUser.username;
  }

  List<_MessageSearchResult> _buildMessageResults({
    required List<DirectConversation> conversations,
    required int? currentUserId,
  }) {
    if (_query.isEmpty) return [];

    final q = _query.toLowerCase();

    final results = conversations
        .where((conversation) {
          final name = _displayNameFromConversation(conversation).toLowerCase();
          final username = conversation.otherUser.username.toLowerCase();
          final body = (conversation.lastMessage?.body ?? '').toLowerCase();

          return name.contains(q) || username.contains(q) || body.contains(q);
        })
        .map((conversation) {
          final otherUser = conversation.otherUser;
          final isMyLastMessage =
              currentUserId != null &&
              conversation.lastMessage?.senderId == currentUserId;

          return _MessageSearchResult(
            conversation: conversation,
            senderName: isMyLastMessage
                ? 'You'
                : _displayNameFromConversation(conversation),
            senderAvatarUrl: isMyLastMessage ? null : otherUser.avatarUrl,
            senderFallbackName: isMyLastMessage
                ? 'You'
                : _displayNameFromConversation(conversation),
            snippet: conversation.lastMessage?.body?.trim().isNotEmpty == true
                ? conversation.lastMessage!.body!
                : conversation.lastMessage?.mediaUrl != null
                    ? 'Sent an attachment'
                    : 'No messages yet',
            createdAt:
                conversation.lastMessage?.createdAt ??
                conversation.lastMessageAt,
          );
        })
        .toList();

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  List<_PersonSearchResult> _buildPeopleResults({
    required LinksProvider linksProvider,
    required int? currentUserId,
  }) {
    if (_query.isEmpty) return [];

    final q = _query.toLowerCase();
    final Map<int, _PersonSearchResult> merged = {};

    void upsert({
      required LinkUser user,
      required String relationship,
      int? requestId,
    }) {
      if (currentUserId != null && user.id == currentUserId) return;

      merged[user.id] = _PersonSearchResult(
        user: user,
        relationship: relationship,
        requestId: requestId,
      );
    }

    for (final link in linksProvider.links) {
      upsert(user: link.user, relationship: 'link');
    }

    for (final request in linksProvider.incomingRequests) {
      final sender = request.sender;
      if (sender != null) {
        upsert(
          user: sender,
          relationship: 'incoming_pending',
          requestId: request.id,
        );
      }
    }

    for (final request in linksProvider.outgoingRequests) {
      final receiver = request.receiver;
      if (receiver != null) {
        upsert(
          user: receiver,
          relationship: 'outgoing_pending',
          requestId: request.id,
        );
      }
    }

    for (final result in linksProvider.searchResults) {
      upsert(
        user: result.user,
        relationship: result.relationship,
        requestId: result.requestId,
      );
    }

    final people = merged.values.where((result) {
      final display = _displayNameFromLinkUser(result.user).toLowerCase();
      final username = result.user.username.toLowerCase();

      return display.contains(q) || username.contains(q);
    }).toList();

    people.sort((a, b) {
      final aName = _displayNameFromLinkUser(a.user).toLowerCase();
      final bName = _displayNameFromLinkUser(b.user).toLowerCase();
      return aName.compareTo(bName);
    });

    return people;
  }

  List<Circle> _buildCircleResults(List<Circle> circles) {
    if (_query.isEmpty) return [];

    final q = _query.toLowerCase();
    return circles.where((circle) {
      final name = circle.name.toLowerCase();
      final description = (circle.description ?? '').toLowerCase();
      return name.contains(q) || description.contains(q);
    }).toList();
  }

  bool _showMessages() =>
      _activeFilter == SearchFilter.all ||
      _activeFilter == SearchFilter.messages;

  bool _showPeople() =>
      _activeFilter == SearchFilter.all || _activeFilter == SearchFilter.people;

  bool _showCircles() =>
      _activeFilter == SearchFilter.all ||
      _activeFilter == SearchFilter.circles;

  String _messageDateLabel(DateTime value) {
    final localValue = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(localValue.year, localValue.month, localValue.day);

    if (target == today) return 'Today';
    if (target == yesterday) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(localValue);
  }

  String _messageDateTimeLabel(DateTime value) {
    final localValue = value.toLocal();
    final dateLabel = _messageDateLabel(localValue);
    final timeLabel = DateFormat('h:mm a').format(localValue);
    return '$dateLabel at $timeLabel';
  }

  List<_GroupedMessageResults> _groupMessages(
    List<_MessageSearchResult> results,
  ) {
    final Map<String, List<_MessageSearchResult>> grouped = {};

    for (final result in results) {
      final key = _messageDateLabel(result.createdAt);
      grouped.putIfAbsent(key, () => []).add(result);
    }

    final keys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'Today') return -1;
        if (b == 'Today') return 1;
        if (a == 'Yesterday') return -1;
        if (b == 'Yesterday') return 1;

        final aDate = grouped[a]!.first.createdAt;
        final bDate = grouped[b]!.first.createdAt;
        return bDate.compareTo(aDate);
      });

    return keys
        .map((key) => _GroupedMessageResults(label: key, items: grouped[key]!))
        .toList();
  }

  Future<void> _sendLinkRequest(LinkUser user) async {
    final provider = context.read<LinksProvider>();

    try {
      await provider.sendLinkRequest(user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link request sent successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      await provider.loadRequests();
      if (_query.isNotEmpty) {
        await provider.searchUsers(_query);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to send link request: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _acceptIncomingRequest(_PersonSearchResult result) async {
    if (result.requestId == null) return;

    final provider = context.read<LinksProvider>();

    try {
      await provider.respondToRequest(result.requestId!, 'accept');
      await provider.loadLinks();
      await provider.loadRequests();

      if (_query.isNotEmpty) {
        await provider.searchUsers(_query);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to accept request: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildFilterChip(String label, SearchFilter filter) {
    final active = _activeFilter == filter;

    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          gradient: active ? _TetherSearchStyle.primaryGradient : null,
          color: active ? null : const Color(0xFFF1F3FA),
          borderRadius: BorderRadius.circular(999),
          boxShadow: active ? _TetherSearchStyle.glowShadow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : const Color(0xFF667085),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final directProvider = context.watch<DirectConversationsProvider>();
    final linksProvider = context.watch<LinksProvider>();
    final deletedProvider = context.watch<DeletedConversationsProvider>();
    final circlesProvider = context.watch<CirclesProvider>();

    final currentUserId = authProvider.user?.id;

    final messageResults = _buildMessageResults(
      conversations: directProvider.conversations
          .where((c) => !deletedProvider.isDirectConversationDeleted(c.id))
          .toList(),
      currentUserId: currentUserId,
    );

    final peopleResults = _buildPeopleResults(
      linksProvider: linksProvider,
      currentUserId: currentUserId,
    );

    final circleResults = _buildCircleResults(
      circlesProvider.circles
          .where((c) => !deletedProvider.isCircleDeleted(c.id))
          .toList(),
    );

    final groupedMessages = _groupMessages(messageResults);

    final hasResults =
        messageResults.isNotEmpty ||
        peopleResults.isNotEmpty ||
        circleResults.isNotEmpty;

    return Scaffold(
      backgroundColor: _TetherSearchStyle.background,
      body: Stack(
        children: [
          const _SearchBackgroundOrbs(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshSearch,
              color: _TetherSearchStyle.primary,
              child: Column(
                children: [
                  _SearchHeader(
                    controller: _searchController,
                    hasQuery: _hasQuery,
                    onChanged: _onSearchChanged,
                    onSubmitted: (value) {
                      _commitRecentSearch(value);
                      _onSearchChanged(value);
                    },
                    onClear: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                    chips: _hasQuery
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('All', SearchFilter.all),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  'Messages',
                                  SearchFilter.messages,
                                ),
                                const SizedBox(width: 8),
                                _buildFilterChip('People', SearchFilter.people),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  'Circles',
                                  SearchFilter.circles,
                                ),
                              ],
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: ListView(
                        key: ValueKey(
                          '${_query}_${_activeFilter.name}_${hasResults}_body',
                        ),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 112),
                        children: [
                          if (!_hasQuery) ...[
                            const SizedBox(height: 28),
                            const _SearchIdleState(),
                            const SizedBox(height: 30),
                            if (_recentSearches.isNotEmpty) ...[
                              const _SectionLabel(
                                icon: Icons.history_rounded,
                                title: 'RECENT SEARCHES',
                                accent: false,
                              ),
                              const SizedBox(height: 12),
                              ..._recentSearches.map(
                                (search) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _RecentSearchTile(
                                    label: search,
                                    onTap: () {
                                      _searchController.text = search;
                                      _commitRecentSearch(search);
                                      _onSearchChanged(search);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ] else if (!hasResults &&
                              !linksProvider.isLoading &&
                              !directProvider.isLoading &&
                              !circlesProvider.isLoading) ...[
                            const SizedBox(height: 68),
                            const _NoResultsState(),
                          ] else ...[
                            if (_showMessages() &&
                                messageResults.isNotEmpty) ...[
                              const _SectionLabel(
                                icon: Icons.chat_bubble_outline_rounded,
                                title: 'MESSAGES',
                                accent: true,
                              ),
                              const SizedBox(height: 12),
                              ...groupedMessages.map(
                                (group) => Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 2,
                                          bottom: 10,
                                        ),
                                        child: Text(
                                          group.label,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: group.label == 'Today'
                                                ? _TetherSearchStyle.primary
                                                : const Color(0xFF667085),
                                          ),
                                        ),
                                      ),
                                      ...group.items.map(
                                        (result) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: _AnimatedResultEntry(
                                            child: _MessageResultCard(
                                              result: result,
                                              query: _query,
                                              dateLabel: _messageDateTimeLabel(
                                                result.createdAt,
                                              ),
                                              onTap: () async {
                                                _commitRecentSearch(_query);
                                                await _openConversationFromSearch(
                                                  result.conversation,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (_showPeople() && peopleResults.isNotEmpty) ...[
                              const _SectionLabel(
                                icon: Icons.people_outline_rounded,
                                title: 'PEOPLE',
                                accent: true,
                              ),
                              const SizedBox(height: 12),
                              ...peopleResults.map(
                                (result) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _AnimatedResultEntry(
                                    child: _PersonResultCard(
                                      result: result,
                                      displayName: _displayNameFromLinkUser(
                                        result.user,
                                      ),
                                      onMessage: () {
                                        _commitRecentSearch(_query);
                                        _openDirectChat(result.user);
                                      },
                                      onAdd: () =>
                                          _sendLinkRequest(result.user),
                                      onAccept: () =>
                                          _acceptIncomingRequest(result),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (_showCircles() &&
                                circleResults.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              const _SectionLabel(
                                icon: Icons.blur_circular_rounded,
                                title: 'CIRCLES',
                                accent: true,
                              ),
                              const SizedBox(height: 12),
                              ...circleResults.map(
                                (circle) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _AnimatedResultEntry(
                                    child: _CircleResultCard(
                                      circle: circle,
                                      onTap: () {
                                        _commitRecentSearch(_query);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ChatScreen(circle: circle),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (linksProvider.isLoading &&
                                _activeFilter == SearchFilter.people)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          ],
                        ],
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
}

class _MessageSearchResult {
  final DirectConversation conversation;
  final String senderName;
  final String? senderAvatarUrl;
  final String senderFallbackName;
  final String snippet;
  final DateTime createdAt;

  const _MessageSearchResult({
    required this.conversation,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.senderFallbackName,
    required this.snippet,
    required this.createdAt,
  });
}

class _PersonSearchResult {
  final LinkUser user;
  final String relationship;
  final int? requestId;

  const _PersonSearchResult({
    required this.user,
    required this.relationship,
    this.requestId,
  });
}

class _GroupedMessageResults {
  final String label;
  final List<_MessageSearchResult> items;

  const _GroupedMessageResults({required this.label, required this.items});
}

class _TetherSearchStyle {
  static const Color background = Color(0xFFFBFCFF);
  static const Color primary = Color(0xFF6F63F6);
  static const Color secondary = Color(0xFFD96BEF);
  static const Color teal = Color(0xFF11C5B7);
  static const Color ink = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6F63F6), Color(0xFFD96BEF)],
  );

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF6F63F6).withOpacity(0.07),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: const Color(0xFFD96BEF).withOpacity(0.28),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
}

class _SearchBackgroundOrbs extends StatelessWidget {
  const _SearchBackgroundOrbs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: _Orb(
              size: 210,
              color: _TetherSearchStyle.primary.withOpacity(0.10),
            ),
          ),
          Positioned(
            top: 260,
            left: -120,
            child: _Orb(
              size: 230,
              color: _TetherSearchStyle.secondary.withOpacity(0.09),
            ),
          ),
          Positioned(
            right: -90,
            bottom: 70,
            child: _Orb(
              size: 210,
              color: _TetherSearchStyle.primary.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;

  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 900),
      tween: Tween(begin: 0.92, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final Widget? chips;

  const _SearchHeader({
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        border: const Border(bottom: BorderSide(color: Color(0xFFE9EAF5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Search',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: _TetherSearchStyle.ink,
            ),
          ),
          const SizedBox(height: 18),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FB),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: hasQuery
                    ? _TetherSearchStyle.primary.withOpacity(0.45)
                    : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: hasQuery
                  ? [
                      BoxShadow(
                        color: _TetherSearchStyle.primary.withOpacity(0.14),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search people, circles, messages...',
                hintStyle: const TextStyle(color: Color(0xFF667085)),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _TetherSearchStyle.primary,
                ),
                suffixIcon: hasQuery
                    ? IconButton(
                        onPressed: onClear,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF667085),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: chips == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: chips!,
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool accent;

  const _SectionLabel({
    required this.icon,
    required this.title,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: accent ? _TetherSearchStyle.primary : _TetherSearchStyle.muted,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w900,
            color:
                accent ? _TetherSearchStyle.primary : _TetherSearchStyle.muted,
          ),
        ),
      ],
    );
  }
}

class _SearchIdleState extends StatelessWidget {
  const _SearchIdleState();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 550),
      tween: Tween(begin: 0.92, end: 1),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Column(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _TetherSearchStyle.primary.withOpacity(0.18),
                  _TetherSearchStyle.secondary.withOpacity(0.16),
                ],
              ),
              boxShadow: _TetherSearchStyle.glowShadow,
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 46,
              color: _TetherSearchStyle.primary,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Search messages, people, and circles',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              color: _TetherSearchStyle.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RecentSearchTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _LiftCard(
      borderRadius: 20,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _TetherSearchStyle.primary.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: _TetherSearchStyle.primary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: _TetherSearchStyle.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: Color(0xFF98A2B3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF1F3FA),
                _TetherSearchStyle.secondary.withOpacity(0.10),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.search_off_rounded,
            size: 38,
            color: Color(0xFF98A2B3),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'No results found',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: _TetherSearchStyle.ink,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Try a different name, username, circle, or message keyword.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.5, color: _TetherSearchStyle.muted),
        ),
      ],
    );
  }
}

class _MessageResultCard extends StatelessWidget {
  final _MessageSearchResult result;
  final String query;
  final String dateLabel;
  final VoidCallback onTap;

  const _MessageResultCard({
    required this.result,
    required this.query,
    required this.dateLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final otherUser = result.conversation.otherUser;
    final conversationName =
        (otherUser.displayName != null &&
            otherUser.displayName!.trim().isNotEmpty)
        ? otherUser.displayName!
        : otherUser.username;

    return _LiftCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                name: result.senderFallbackName,
                avatarUrl: result.senderAvatarUrl,
                radius: 25,
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
                            result.senderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _TetherSearchStyle.ink,
                            ),
                          ),
                        ),
                        const _MiniTag(label: 'DM'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Direct message · $conversationName',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _TetherSearchStyle.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _HighlightedText(text: result.snippet, query: query),
                    const SizedBox(height: 10),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _TetherSearchStyle.muted,
                        fontWeight: FontWeight.w600,
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

class _PersonResultCard extends StatelessWidget {
  final _PersonSearchResult result;
  final String displayName;
  final VoidCallback onMessage;
  final VoidCallback onAdd;
  final VoidCallback onAccept;

  const _PersonResultCard({
    required this.result,
    required this.displayName,
    required this.onMessage,
    required this.onAdd,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final relationship = result.relationship.toLowerCase().trim();

    Widget trailing;
    switch (relationship) {
      case 'link':
      case 'linked':
      case 'contact':
        trailing = _ActionButton(
          label: 'Message',
          icon: Icons.chat_bubble_outline_rounded,
          onTap: onMessage,
          filled: true,
        );
        break;
      case 'outgoing_pending':
        trailing = const _StatusBadge(text: 'Pending');
        break;
      case 'incoming_pending':
        trailing = _ActionButton(
          label: 'Accept',
          icon: Icons.check_rounded,
          onTap: onAccept,
          filled: true,
        );
        break;
      default:
        trailing = _ActionButton(
          label: 'Add',
          icon: Icons.person_add_alt_1_rounded,
          onTap: onAdd,
          filled: true,
        );
    }

    return _LiftCard(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            AppAvatar(
              name: displayName,
              avatarUrl: result.user.avatarUrl,
              radius: 25,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _TetherSearchStyle.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${result.user.username}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: _TetherSearchStyle.muted,
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
  }
}

class _CircleResultCard extends StatelessWidget {
  final Circle circle;
  final VoidCallback onTap;

  const _CircleResultCard({required this.circle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final memberCount =
        circle.messageCount?.members ?? circle.members?.length ?? 0;

    return _LiftCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              _CircleClusterAvatar(seed: circle.name),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      circle.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _TetherSearchStyle.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$memberCount member${memberCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: _TetherSearchStyle.muted,
                      ),
                    ),
                  ],
                ),
              ),
              _ActionButton(
                label: 'Open',
                icon: Icons.arrow_forward_rounded,
                onTap: onTap,
                filled: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiftCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;

  const _LiftCard({required this.child, this.borderRadius = 24});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.96),
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: const Color(0xFFE7E9F5)),
          boxShadow: _TetherSearchStyle.cardShadow,
        ),
        child: child,
      ),
    );
  }
}

class _AnimatedResultEntry extends StatelessWidget {
  final Widget child;

  const _AnimatedResultEntry({required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 320),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: filled ? _TetherSearchStyle.primaryGradient : null,
          color: filled ? null : _TetherSearchStyle.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          boxShadow: filled ? _TetherSearchStyle.glowShadow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: filled ? Colors.white : _TetherSearchStyle.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: filled ? Colors.white : _TetherSearchStyle.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;

  const _StatusBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: _TetherSearchStyle.muted,
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String label;

  const _MiniTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _TetherSearchStyle.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: _TetherSearchStyle.primary,
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;

  const _HighlightedText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14.5,
          height: 1.45,
          color: _TetherSearchStyle.ink,
        ),
      );
    }

    final matches = RegExp(
      RegExp.escape(query),
      caseSensitive: false,
    ).allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14.5,
          height: 1.45,
          color: _TetherSearchStyle.ink,
        ),
      );
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: const TextStyle(
              color: _TetherSearchStyle.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            color: _TetherSearchStyle.ink,
            fontWeight: FontWeight.w900,
            backgroundColor: _TetherSearchStyle.secondary.withOpacity(0.22),
          ),
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: const TextStyle(
            color: _TetherSearchStyle.ink,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 14.5, height: 1.45),
        children: spans,
      ),
    );
  }
}

class _CircleClusterAvatar extends StatelessWidget {
  final String seed;

  const _CircleClusterAvatar({required this.seed});

  Color _colorForIndex(int index) {
    const colors = [
      _TetherSearchStyle.teal,
      Color(0xFF4F7DF3),
      _TetherSearchStyle.primary,
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
          Positioned(
            right: 0,
            bottom: 1,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                gradient: _TetherSearchStyle.primaryGradient,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.blur_circular_rounded,
                color: Colors.white,
                size: 10,
              ),
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
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}
