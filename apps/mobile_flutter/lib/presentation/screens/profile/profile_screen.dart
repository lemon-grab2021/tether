import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/circles_provider.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/links_service.dart';
import '../auth/login_screen.dart';
import '../deleted/deleted_conversations_screen.dart';
import '../../widgets/tether_visual_kit.dart';

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
    if (!mounted) return;
    setState(() => _isLoadingStats = true);

    try {
      final token = await _authService.getAccessToken();
      if (token == null) return;

      final links = await _linksService.getLinks(token: token);

      if (!mounted) return;
      setState(() => _linksCount = links.length);
    } catch (_) {
      // Keep the page stable if stats fail.
    } finally {
      if (mounted) setState(() => _isLoadingStats = false);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
              backgroundColor: TetherVisualPalette.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
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

  Future<void> _refresh() async {
    await context.read<CirclesProvider>().loadCircles();
    await _loadProfileStats();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final circlesProvider = context.watch<CirclesProvider>();
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(
        backgroundColor: TetherVisualPalette.background,
        body: TetherPageBackground(
          child: SafeArea(child: Center(child: Text('Not logged in'))),
        ),
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

    final joinedDate = user.createdAt == null
        ? 'Recently'
        : DateFormat('MMMM yyyy').format(user.createdAt!);
    final circlesCount = circlesProvider.circles.length;

    return Scaffold(
      backgroundColor: TetherVisualPalette.background,
      body: TetherPageBackground(
        child: SafeArea(
          child: Column(
            children: [
              TetherHeader(
                title: 'Profile',
                subtitle: 'Manage your Tether account',
                leading: const TetherIconBadge(icon: Icons.person_rounded),
                actions: [
                  TetherHeaderAction(
                    icon: Icons.settings_outlined,
                    onPressed: () => _showComingSoon('Settings'),
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
                      TetherFadeSlide(
                        child: TetherCard(
                          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: TetherVisualPalette.primaryGradient,
                                      boxShadow: [
                                        BoxShadow(
                                          color: TetherVisualPalette.primary
                                              .withOpacity(0.24),
                                          blurRadius: 34,
                                          offset: const Offset(0, 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 102,
                                    height: 102,
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: TetherUserAvatar(
                                      name: displayName,
                                      imageUrl: avatarUrl,
                                      size: 94,
                                    ),
                                  ),
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        gradient:
                                            TetherVisualPalette.primaryGradient,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Text(
                                displayName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  color: TetherVisualPalette.text,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '@${user.username}',
                                style: const TextStyle(
                                  color: TetherVisualPalette.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                user.email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: TetherVisualPalette.muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F4FF),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _ProfileStat(
                                        label: 'Links',
                                        value: _isLoadingStats
                                            ? '—'
                                            : '$_linksCount',
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 42,
                                      color: TetherVisualPalette.border,
                                    ),
                                    Expanded(
                                      child: _ProfileStat(
                                        label: 'Circles',
                                        value: '$circlesCount',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: TetherVisualPalette.muted,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Joined $joinedDate',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: TetherVisualPalette.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      TetherFadeSlide(
                        delayMs: 40,
                        child: TetherSettingsSection(
                          title: 'Account',
                          children: [
                            TetherSettingsTile(
                              icon: Icons.lock_outline_rounded,
                              title: 'Privacy',
                              subtitle: 'Manage who can see your profile',
                              onTap: () => _showComingSoon('Privacy'),
                            ),
                            TetherSettingsTile(
                              icon: Icons.shield_outlined,
                              title: 'Security',
                              subtitle: 'Password and authentication',
                              onTap: () => _showComingSoon('Security'),
                            ),
                            TetherSettingsTile(
                              icon: Icons.smartphone_outlined,
                              title: 'Devices',
                              subtitle: 'Manage logged in devices',
                              onTap: () => _showComingSoon('Devices'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      TetherFadeSlide(
                        delayMs: 80,
                        child: TetherSettingsSection(
                          title: 'Preferences',
                          children: [
                            TetherSettingsTile(
                              icon: Icons.notifications_none_rounded,
                              title: 'Notifications',
                              subtitle: 'Message and activity alerts',
                              onTap: () => _showComingSoon('Notifications'),
                            ),
                            TetherSettingsTile(
                              icon: Icons.palette_outlined,
                              title: 'Appearance',
                              subtitle: 'Theme and display settings',
                              onTap: () => _showComingSoon('Appearance'),
                            ),
                            _DarkModeTile(
                              value: _darkModeEnabled,
                              onChanged: (value) {
                                setState(() => _darkModeEnabled = value);
                              },
                            ),
                            TetherSettingsTile(
                              icon: Icons.delete_outline_rounded,
                              title: 'Deleted conversations',
                              subtitle:
                                  'Restore or permanently remove deleted chats',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DeletedConversationsScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      TetherFadeSlide(
                        delayMs: 120,
                        child: TetherSettingsSection(
                          title: 'Support',
                          children: [
                            TetherSettingsTile(
                              icon: Icons.help_outline_rounded,
                              title: 'Help Center',
                              subtitle: 'FAQs and support',
                              onTap: () => _showComingSoon('Help Center'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TetherFadeSlide(
                        delayMs: 160,
                        child: TetherSoftButton(
                          label: 'Log Out',
                          icon: Icons.logout_rounded,
                          color: TetherVisualPalette.danger,
                          onPressed: _handleLogout,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          'Tether v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: TetherVisualPalette.softMuted,
                            fontWeight: FontWeight.w600,
                          ),
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

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: TetherVisualPalette.text,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: TetherVisualPalette.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DarkModeTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DarkModeTile({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    TetherVisualPalette.primary.withOpacity(0.12),
                    TetherVisualPalette.accent.withOpacity(0.12),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.dark_mode_outlined,
                color: TetherVisualPalette.primary,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Text(
                'Dark Mode',
                style: TextStyle(
                  color: TetherVisualPalette.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 28,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: value ? TetherVisualPalette.primaryGradient : null,
                color: value ? null : const Color(0xFFE8E5F8),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
