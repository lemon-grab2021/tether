import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/circles_provider.dart';
import '../../../providers/direct_conversations_provider.dart';
import '../../../providers/direct_messages_provider.dart';
import '../../../providers/links_provider.dart';

import '../../../data/models/circle.dart';
import '../../../data/models/direct_conversation.dart';
import '../../../data/models/link_search_result.dart';
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

    // Existing accepted links
    for (final link in linksProvider.links) {
      upsert(user: link.user, relationship: 'link');
    }

    // Incoming requests
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

    // Outgoing requests
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

    // Backend discover/search results
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
        ),
      );
    }
  }

  Widget _buildFilterChip(String label, SearchFilter filter) {
    final active = _activeFilter == filter;

    return GestureDetector(
      onTap: () => setState(() => _activeFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1274E7) : const Color(0xFFEFF4F8),
          borderRadius: BorderRadius.circular(999),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF1274E7).withOpacity(0.24),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF64748B),
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
    final circlesProvider = context.watch<CirclesProvider>();

    final currentUserId = authProvider.user?.id;

    final messageResults = _buildMessageResults(
      conversations: directProvider.conversations,
      currentUserId: currentUserId,
    );
    final peopleResults = _buildPeopleResults(
      linksProvider: linksProvider,
      currentUserId: currentUserId,
    );
    final circleResults = _buildCircleResults(circlesProvider.circles);

    final groupedMessages = _groupMessages(messageResults);

    final hasResults =
        messageResults.isNotEmpty ||
        peopleResults.isNotEmpty ||
        circleResults.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshSearch,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F7FB),
                  border: Border(bottom: BorderSide(color: Color(0xFFE5EDF5))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: _hasQuery
                              ? const Color(0xFF1274E7).withOpacity(0.35)
                              : const Color(0xFFE2E8F0),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF1274E7,
                            ).withOpacity(_hasQuery ? 0.08 : 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      // when a user presses enter/search saves the search
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        onSubmitted: (value) {
                          _commitRecentSearch(value);
                          _onSearchChanged(value);
                        },
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search people, circles, messages...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _hasQuery
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    if (_hasQuery) ...[
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('All', SearchFilter.all),
                            const SizedBox(width: 8),
                            _buildFilterChip('Messages', SearchFilter.messages),
                            const SizedBox(width: 8),
                            _buildFilterChip('People', SearchFilter.people),
                            const SizedBox(width: 8),
                            _buildFilterChip('Circles', SearchFilter.circles),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  children: [
                    if (!_hasQuery) ...[
                      const SizedBox(height: 30),
                      const _SearchIdleState(),
                      const SizedBox(height: 28),
                      if (_recentSearches.isNotEmpty) ...[
                        const Text(
                          'RECENT SEARCHES',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._recentSearches.map(
                          (search) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _RecentSearchTile(
                              label: search,
                              onTap: () {
                                _searchController.text = search;
                                _commitRecentSearch(
                                  search,
                                ); // saves search when a recent search is tapped
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
                      const SizedBox(height: 70),
                      const _NoResultsState(),
                    ] else ...[
                      if (_showMessages() && messageResults.isNotEmpty) ...[
                        const _SectionLabel(
                          icon: Icons.message_outlined,
                          title: 'MESSAGES',
                        ),
                        const SizedBox(height: 12),
                        ...groupedMessages.map(
                          (group) => Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: group.label == 'Today'
                                        ? const Color(0xFF1274E7)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...group.items.map(
                                  (result) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _MessageResultCard(
                                      result: result,
                                      query: _query,
                                      dateLabel: _messageDateTimeLabel(
                                        result.createdAt,
                                      ),
                                      onTap: () {
                                        _commitRecentSearch(_query);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ChangeNotifierProvider(
                                                  create: (_) =>
                                                      DirectMessagesProvider(),
                                                  child: DirectChatScreen(
                                                    conversation:
                                                        result.conversation,
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
                          ),
                        ),
                      ],
                      if (_showPeople() && peopleResults.isNotEmpty) ...[
                        const _SectionLabel(
                          icon: Icons.people_outline_rounded,
                          title: 'PEOPLE',
                        ),
                        const SizedBox(height: 12),
                        ...peopleResults.map(
                          (result) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PersonResultCard(
                              result: result,
                              displayName: _displayNameFromLinkUser(
                                result.user,
                              ),
                              onMessage: () {
                                _commitRecentSearch(_query);
                                _openDirectChat(result.user);
                              },
                              onAdd: () => _sendLinkRequest(result.user),
                              onAccept: () => _acceptIncomingRequest(result),
                            ),
                          ),
                        ),
                      ],
                      if (_showCircles() && circleResults.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        const _SectionLabel(
                          icon: Icons.blur_circular_rounded,
                          title: 'CIRCLES',
                        ),
                        const SizedBox(height: 12),
                        ...circleResults.map(
                          (circle) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CircleResultCard(
                              circle: circle,
                              onTap: () {
                                _commitRecentSearch(_query);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(circle: circle),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                      if (linksProvider.isLoading &&
                          _activeFilter == SearchFilter.people)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
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

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionLabel({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
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
    return Column(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: const Color(0xFF1274E7).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.search_rounded,
            size: 42,
            color: Color(0xFF1274E7),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Search messages, people, and circles',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RecentSearchTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, color: Color(0xFF64748B)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
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
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF4F8),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.search_off_rounded,
            size: 34,
            color: Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No results found',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Try searching for something else',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14.5, color: Color(0xFF64748B)),
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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                name: result.senderFallbackName,
                avatarUrl: result.senderAvatarUrl,
                radius: 24,
              ),
              const SizedBox(width: 12),
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
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1274E7).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'DM',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1274E7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Direct message · $conversationName',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _HighlightedText(text: result.snippet, query: query),
                    const SizedBox(height: 10),
                    Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
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
        trailing = _ActionButton(
          label: 'Message',
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
          onTap: onAccept,
          filled: true,
        );
        break;
      default:
        trailing = _ActionButton(label: 'Add', onTap: onAdd, filled: true);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AppAvatar(
            name: displayName,
            avatarUrl: result.user.avatarUrl,
            radius: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '@${result.user.username}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _CircleClusterAvatar(seed: circle.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      circle.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$memberCount member${memberCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              _ActionButton(label: 'Open', onTap: onTap, filled: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;

  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: filled
              ? const Color(0xFF1274E7).withOpacity(0.10)
              : const Color(0xFF11C5B7).withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: filled ? const Color(0xFF1274E7) : const Color(0xFF0F766E),
          ),
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
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
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
          color: Color(0xFF0F172A),
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
          color: Color(0xFF0F172A),
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
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: TextStyle(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w700,
            backgroundColor: const Color(0xFF1274E7).withOpacity(0.18),
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
            color: Color(0xFF0F172A),
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
