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
import '../../widgets/app_avatar.dart';

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

  LinksTab _activeTab =
      LinksTab.links; // current tab in use by default is links

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<LinksProvider>();
      provider.loadLinks();
      provider.loadRequests();
    });

    // periodic refresh every 5 seconds
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

    final conversation = await _directMessagesService.createOrGetConversation(
      token: token!,
      otherUserId: user.id,
      currentUserId: currentUserId,
    );

    // Refresh Home Screens dm list immediately after creating a new conversation
    if (context.mounted) {
      // ignore: use_build_context_synchronously
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
    return AppAvatar(
      name: _displayName(user),
      avatarUrl: user.avatarUrl,
      radius: 24,
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

  Widget _buildTabButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
    int? badge,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                ),
              ),
              if (badge != null && badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1274E7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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

      if (_searchController.text.trim().isNotEmpty) {
        await provider.searchUsers(_searchController.text.trim());
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

  Widget _buildLinksTab(LinksProvider provider) {
    final filteredLinks = provider.links.where((link) {
      final user = link.user;
      final query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) return true;

      return _displayName(user).toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query);
    }).toList();

    if (provider.isLoading && provider.links.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filteredLinks.isEmpty) {
      return _EmptyState(
        icon: const _ConnectedCirclesIllustration(),
        title: 'No links found',
        description: _searchController.text.trim().isNotEmpty
            ? 'Try a different search term.'
            : 'Accepted connections will appear here and can be messaged directly.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List.generate(filteredLinks.length, (index) {
          final link = filteredLinks[index];
          final user = link.user;

          return Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.vertical(
                  top: index == 0 ? const Radius.circular(22) : Radius.zero,
                  bottom: index == filteredLinks.length - 1
                      ? const Radius.circular(22)
                      : Radius.zero,
                ),
                onTap: () => _openDirectChat(user),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      _buildAvatar(user),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayName(user),
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${user.username}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1274E7).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => _openDirectChat(user),
                          icon: const Icon(
                            Icons.message_rounded,
                            size: 18,
                            color: Color(0xFF1274E7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (index != filteredLinks.length - 1)
                const Divider(height: 1, color: Color(0xFFEAEFF5)),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildRequestsTab(LinksProvider provider) {
    if (provider.isLoading &&
        provider.incomingRequests.isEmpty &&
        provider.outgoingRequests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.incomingRequests.isEmpty &&
        provider.outgoingRequests.isEmpty) {
      return const _EmptyState(
        icon: _ConnectedCirclesIllustration(),
        title: 'No pending requests',
        description:
            'When someone sends you a link request, it will appear here.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (provider.incomingRequests.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 10),
            child: Text(
              'Incoming Requests',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          ...provider.incomingRequests.map((request) {
            final sender = request.sender!;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildAvatar(sender),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName(sender),
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${sender.username}',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: Color(0xFF64748B),
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
                          child: OutlinedButton.icon(
                            onPressed: () => provider.respondToRequest(
                              request.id,
                              'decline',
                            ),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Decline'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                provider.respondToRequest(request.id, 'accept'),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1274E7),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
        if (provider.outgoingRequests.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 2, top: 6, bottom: 10),
            child: Text(
              'Sent Requests',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: List.generate(provider.outgoingRequests.length, (
                index,
              ) {
                final request = provider.outgoingRequests[index];
                final receiver = request.receiver!;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          _buildAvatar(receiver),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _displayName(receiver),
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@${receiver.username}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: Color(0xFF64748B),
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
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (index != provider.outgoingRequests.length - 1)
                      const Divider(height: 1, color: Color(0xFFEAEFF5)),
                  ],
                );
              }),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDiscoverTab(LinksProvider provider) {
    if (_searchController.text.trim().isEmpty) {
      return const _EmptyState(
        icon: _ConnectedCirclesIllustration(),
        title: 'Discover people',
        description: 'Search by username or display name to build your tether.',
      );
    }

    if (provider.isLoading && provider.searchResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.searchResults.isEmpty) {
      return const _EmptyState(
        icon: _ConnectedCirclesIllustration(),
        title: 'No people found',
        description: 'Try a different search term.',
      );
    }

    return Column(
      children: provider.searchResults.map((result) {
        final user = result.user;

        Widget trailing;

        final relationship = result.relationship.toLowerCase().trim();
        
        switch (relationship) {
          case 'link':
          case 'linked':
          case 'contact':
            trailing = ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1274E7),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _openDirectChat(user),
              child: const Text('Message'),
            );
            break;
          case 'outgoing_pending':
            trailing = const _Badge(text: 'Pending');
            break;
          case 'incoming_pending':
            trailing = ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1274E7),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: result.requestId == null
                  ? null
                  : () async {
                      await provider.respondToRequest(
                        result.requestId!,
                        'accept',
                      );
                    },
              child: const Text('Accept'),
            );
            break;
          default:
            trailing = ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1274E7),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _sendLinkRequest(user),
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
                _buildAvatar(user),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LinksProvider>();
    final incomingCount = provider.incomingRequests.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (Navigator.canPop(context))
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            color: const Color(0xFF0F172A),
                          )
                        else
                          const SizedBox(width: 8),
                        const _LinksIcon(size: 28),
                        const SizedBox(width: 8),
                        const Text(
                          'Links',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          // child: const Icon(
                          //   Icons.person_add_alt_1_rounded,
                          //   color: Color(0xFF1274E7),
                          // ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF4F8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                          hintText: 'Search links...',
                          prefixIcon: Icon(Icons.search_rounded),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF4F8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          _buildTabButton(
                            label: 'Links',
                            active: _activeTab == LinksTab.links,
                            onTap: () {
                              setState(() {
                                _activeTab = LinksTab.links;
                              });
                            },
                          ),
                          _buildTabButton(
                            label: 'Requests',
                            badge: incomingCount,
                            active: _activeTab == LinksTab.requests,
                            onTap: () {
                              setState(() {
                                _activeTab = LinksTab.requests;
                              });
                            },
                          ),
                          _buildTabButton(
                            label: 'Discover',
                            active: _activeTab == LinksTab.discover,
                            onTap: () {
                              setState(() {
                                _activeTab = LinksTab.discover;
                              });

                              if (_searchController.text.trim().isNotEmpty) {
                                provider.searchUsers(
                                  _searchController.text.trim(),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    if (_activeTab == LinksTab.links) _buildLinksTab(provider),
                    if (_activeTab == LinksTab.requests)
                      _buildRequestsTab(provider),
                    if (_activeTab == LinksTab.discover)
                      _buildDiscoverTab(provider),
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

class _LinksIcon extends StatelessWidget {
  final double size;

  const _LinksIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LinksIconPainter()),
    );
  }
}

class _LinksIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = const Color(0xFF1274E7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF1274E7).withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final leftCenter = Offset(size.width * 0.35, size.height * 0.5);
    final rightCenter = Offset(size.width * 0.65, size.height * 0.5);
    final radius = size.width * 0.22;

    canvas.drawCircle(leftCenter, radius, fillPaint);
    canvas.drawCircle(rightCenter, radius, fillPaint);
    canvas.drawCircle(leftCenter, radius, strokePaint);
    canvas.drawCircle(rightCenter, radius, strokePaint);

    canvas.drawLine(
      Offset(leftCenter.dx + radius * 0.7, leftCenter.dy),
      Offset(rightCenter.dx - radius * 0.7, rightCenter.dy),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ConnectedCirclesIllustration extends StatelessWidget {
  const _ConnectedCirclesIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(painter: _ConnectedCirclesIllustrationPainter()),
    );
  }
}

class _ConnectedCirclesIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = const Color(0xFF1274E7).withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fillPaint = Paint()
      ..color = const Color(0xFF1274E7).withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final left = Offset(size.width * 0.38, size.height * 0.5);
    final right = Offset(size.width * 0.62, size.height * 0.5);
    final radius = size.width * 0.22;

    canvas.drawCircle(left, radius, fillPaint);
    canvas.drawCircle(right, radius, fillPaint);
    canvas.drawCircle(left, radius, strokePaint);
    canvas.drawCircle(right, radius, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyState extends StatelessWidget {
  final Widget icon;
  final String title;
  final String description;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          icon,
          const SizedBox(height: 18),
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
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.35,
              color: Color(0xFF64748B),
            ),
          ),
        ],
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
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}
