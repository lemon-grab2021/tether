import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/circles_provider.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/links_service.dart';
import '../auth/login_screen.dart';
import '../deleted/deleted_conversations_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final LinksService _linksService = LinksService();

  bool _darkModeEnabled = false;
  int _linksCount = 0;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final circlesProvider = context.read<CirclesProvider>();
      if (circlesProvider.circles.isEmpty) {
        await circlesProvider.loadCircles();
      }
      await _loadProfileStats();
    });
  }

  Future<void> _loadProfileStats() async {
    setState(() => _isLoadingStats = true);

    try {
      final token = await _authService.getAccessToken();
      if (token == null) return;

      final links = await _linksService.getLinks(token: token);

      if (!mounted) return;
      setState(() {
        _linksCount = links.length;
      });
    } catch (_) {
      // keep UI stable if stats fail
    } finally {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleLogout() async {
    final authProvider = context.read<AuthProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await authProvider.logout();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final circlesProvider = context.watch<CirclesProvider>();
    final user = authProvider.user;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F7FB),
        body: const SafeArea(child: Center(child: Text('Not logged in'))),
      );
    }

    final displayName =
        (user.displayName != null && user.displayName!.trim().isNotEmpty)
        ? user.displayName!.trim()
        : user.username;

    final avatarUrl =
        (user.avatarUrl != null && user.avatarUrl!.trim().isNotEmpty)
        ? user.avatarUrl!.trim()
        : null;

    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final joinedDate = DateFormat('MMMM yyyy').format(user.createdAt!);
    final circlesCount = circlesProvider.circles.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await context.read<CirclesProvider>().loadCircles();
            await _loadProfileStats();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Row(
                children: [
                  const SizedBox(width: 4),
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showComingSoon('Settings'),
                    icon: const Icon(Icons.settings_outlined),
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
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
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 4,
                            ),
                          ),
                          child: ClipOval(
                            child: avatarUrl != null
                                ? Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) {
                                      return Container(
                                        color: const Color(0xFFEDE9FE),
                                        alignment: Alignment.center,
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF5B21B6),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: const Color(0xFFEDE9FE),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF5B21B6),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.link_rounded,
                                size: 16,
                                color: Color(0xFF1274E7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFE2E8F0)),
                          bottom: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  _isLoadingStats ? '—' : '$_linksCount',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Links',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 36,
                            color: const Color(0xFFE2E8F0),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '$circlesCount',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Circles',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Joined $joinedDate',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const _SectionTitle('ACCOUNT'),
              _SettingsGroup(
                children: [
                  _SettingsItem(
                    icon: Icons.lock_outline_rounded,
                    label: 'Privacy',
                    subtitle: 'Manage who can see your profile',
                    onTap: () => _showComingSoon('Privacy'),
                  ),
                  _SettingsItem(
                    icon: Icons.shield_outlined,
                    label: 'Security',
                    subtitle: 'Password and authentication',
                    onTap: () => _showComingSoon('Security'),
                  ),
                  _SettingsItem(
                    icon: Icons.smartphone_outlined,
                    label: 'Devices',
                    subtitle: 'Manage logged in devices',
                    onTap: () => _showComingSoon('Devices'),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              const _SectionTitle('PREFERENCES'),
              _SettingsGroup(
                children: [
                  _SettingsItem(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifications',
                    subtitle: 'Message and activity alerts',
                    onTap: () => _showComingSoon('Notifications'),
                  ),
                  _SettingsItem(
                    icon: Icons.palette_outlined,
                    label: 'Appearance',
                    subtitle: 'Theme and display settings',
                    onTap: () => _showComingSoon('Appearance'),
                  ),
                  _SettingsItem(
                    icon: Icons.dark_mode_outlined,
                    label: 'Dark Mode',
                    isToggle: true,
                    toggleValue: _darkModeEnabled,
                    onToggleChanged: (value) {
                      setState(() {
                        _darkModeEnabled = value;
                      });
                    },
                  ),
                  _SettingsItem(
                    icon: Icons.delete_outline_rounded,
                    label: 'Deleted conversations',
                    subtitle: 'Restore or permanently remove deleted chats',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DeletedConversationsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 18),

              const _SectionTitle('SUPPORT'),
              _SettingsGroup(
                children: [
                  _SettingsItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Help Center',
                    subtitle: 'FAQs and support',
                    onTap: () => _showComingSoon('Help Center'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFDC2626),
                  ),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE2E2),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              const Center(
                child: Text(
                  'Tether v1.0.0',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        children: List.generate(children.length, (index) {
          return Column(
            children: [
              children[index],
              if (index != children.length - 1)
                const Divider(height: 1, color: Color(0xFFEAEFF5)),
            ],
          );
        }),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isToggle;
  final bool toggleValue;
  final ValueChanged<bool>? onToggleChanged;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.isToggle = false,
    this.toggleValue = false,
    this.onToggleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isToggle ? () => onToggleChanged?.call(!toggleValue) : onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF1274E7), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isToggle)
              Switch(
                value: toggleValue,
                onChanged: onToggleChanged,
                activeColor: const Color(0xFF1274E7),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
