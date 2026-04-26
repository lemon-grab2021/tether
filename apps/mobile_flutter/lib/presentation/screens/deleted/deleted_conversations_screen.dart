import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/deleted_conversations_provider.dart';
import '../../widgets/app_avatar.dart';
import '../../widgets/delete_conversation_sheet.dart';

class DeletedConversationsScreen extends StatefulWidget {
  const DeletedConversationsScreen({super.key});

  @override
  State<DeletedConversationsScreen> createState() =>
      _DeletedConversationsScreenState();
}

class _DeletedConversationsScreenState extends State<DeletedConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DeletedConversationsProvider>().purgeExpired();
    });
  }

  String _deletedDateText(DateTime value) {
    final days = DateTime.now().difference(value).inDays;
    if (days <= 0) return 'Deleted today';
    if (days == 1) return 'Deleted yesterday';
    return 'Deleted $days days ago';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeletedConversationsProvider>();
    final items = provider.items;
    final urgentCount = items.where((item) => item.daysRemaining <= 7).length;

    return Scaffold(
      backgroundColor: _DeletedStyle.background,
      body: Stack(
        children: [
          const _DeletedBackgroundOrbs(),
          SafeArea(
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _DeletedHeader(
                    itemCount: items.length,
                    urgentCount: urgentCount,
                    onBack: () => Navigator.pop(context),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        const _AutoDeleteNoticeCard(),
                        const SizedBox(height: 16),
                        if (items.isEmpty)
                          _DeletedEmptyState(onBack: () => Navigator.pop(context))
                        else
                          ...items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _DeletedConversationCard(
                                item: item,
                                deletedDateText: _deletedDateText(item.deletedAt),
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
        ],
      ),
    );
  }
}

class _DeletedStyle {
  static const Color background = Color(0xFFFBFCFF);
  static const Color primary = Color(0xFF6F63F6);
  static const Color secondary = Color(0xFFD96BEF);
  static const Color teal = Color(0xFF11C5B7);
  static const Color ink = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color danger = Color(0xFFD92D20);

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

class _DeletedBackgroundOrbs extends StatelessWidget {
  const _DeletedBackgroundOrbs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -90,
            child: _Orb(
              size: 220,
              color: _DeletedStyle.primary.withOpacity(0.12),
            ),
          ),
          Positioned(
            top: 250,
            left: -120,
            child: _Orb(
              size: 240,
              color: _DeletedStyle.secondary.withOpacity(0.09),
            ),
          ),
          Positioned(
            right: -95,
            bottom: 65,
            child: _Orb(
              size: 220,
              color: _DeletedStyle.primary.withOpacity(0.11),
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

class _DeletedHeader extends StatelessWidget {
  final int itemCount;
  final int urgentCount;
  final VoidCallback onBack;

  const _DeletedHeader({
    required this.itemCount,
    required this.urgentCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        border: const Border(bottom: BorderSide(color: Color(0xFFE9EAF5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: _DeletedStyle.ink,
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: _DeletedStyle.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _DeletedStyle.glowShadow,
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deleted',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: _DeletedStyle.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$itemCount conversation${itemCount == 1 ? '' : 's'} awaiting action',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _DeletedStyle.muted,
                  ),
                ),
              ],
            ),
          ),
          if (urgentCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 15,
                    color: _DeletedStyle.danger,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$urgentCount urgent',
                    style: const TextStyle(
                      color: _DeletedStyle.danger,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AutoDeleteNoticeCard extends StatelessWidget {
  const _AutoDeleteNoticeCard();

  @override
  Widget build(BuildContext context) {
    return _LiftCard(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 650),
              tween: Tween(begin: 0.92, end: 1),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _DeletedStyle.primary.withOpacity(0.16),
                      _DeletedStyle.secondary.withOpacity(0.16),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: _DeletedStyle.primary,
                ),
              ),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-delete enabled',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _DeletedStyle.ink,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Deleted conversations are permanently removed after 30 days. Restore anything important before the countdown expires.',
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.35,
                      color: _DeletedStyle.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeletedConversationCard extends StatefulWidget {
  final DeletedConversationEntry item;
  final String deletedDateText;

  const _DeletedConversationCard({
    required this.item,
    required this.deletedDateText,
  });

  @override
  State<_DeletedConversationCard> createState() =>
      _DeletedConversationCardState();
}

class _DeletedConversationCardState extends State<_DeletedConversationCard> {
  bool _isAnimatingOut = false;
  bool _isRestoreAnimation = false;

  Future<void> _runAnimatedRemoval(
    Future<void> Function() action, {
    required bool restore,
  }) async {
    setState(() {
      _isAnimatingOut = true;
      _isRestoreAnimation = restore;
    });

    await Future.delayed(const Duration(milliseconds: 260));
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DeletedConversationsProvider>();
    final item = widget.item;
    final isUrgent = item.daysRemaining <= 7;
    final progress = (item.daysRemaining / 30).clamp(0.0, 1.0);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 240),
      opacity: _isAnimatingOut ? 0 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        scale: _isAnimatingOut ? 0.96 : 1,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          offset: _isAnimatingOut
              ? (_isRestoreAnimation
                  ? const Offset(0.18, 0)
                  : const Offset(0, -0.04))
              : Offset.zero,
          child: _LiftCard(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: progress,
                    backgroundColor: const Color(0xFFF1F3FA),
                    color: isUrgent
                        ? _DeletedStyle.danger
                        : _DeletedStyle.primary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.type == DeletedConversationType.direct)
                            _DeletedDirectAvatar(item: item)
                          else
                            _DeletedCircleAvatar(item: item),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: _DeletedStyle.ink,
                                        ),
                                      ),
                                    ),
                                    if (item.type ==
                                        DeletedConversationType.circle)
                                      Container(
                                        margin: const EdgeInsets.only(left: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _DeletedStyle.primary
                                              .withOpacity(0.10),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '${item.members.length}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _DeletedStyle.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  item.preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    color: _DeletedStyle.muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _DaysLeftBadge(
                            daysRemaining: item.daysRemaining,
                            isUrgent: isUrgent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            size: 16,
                            color: Color(0xFF98A2B3),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              widget.deletedDateText,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF98A2B3),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _RestoreButton(
                              onTap: () async {
                                await _runAnimatedRemoval(() async {
                                  provider.restoreConversation(item.deletedId);
                                }, restore: true);

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Conversation restored'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          _PermanentDeleteButton(
                            onTap: () async {
                              final confirmed =
                                  await showPermanentDeleteConversationSheet(
                                context,
                                title: item.name,
                              );

                              if (!confirmed || !mounted) return;

                              await _runAnimatedRemoval(() async {
                                provider.permanentlyDeleteConversation(
                                  item.deletedId,
                                );
                              }, restore: false);

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Conversation permanently deleted'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeletedDirectAvatar extends StatelessWidget {
  final DeletedConversationEntry item;

  const _DeletedDirectAvatar({required this.item});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Colors.grey,
            BlendMode.saturation,
          ),
          child: AppAvatar(
            name: item.name,
            avatarUrl: item.avatarUrl,
            radius: 25,
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.78),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 13,
                color: _DeletedStyle.muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DaysLeftBadge extends StatelessWidget {
  final int daysRemaining;
  final bool isUrgent;

  const _DaysLeftBadge({
    required this.daysRemaining,
    required this.isUrgent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isUrgent ? const Color(0xFFFFEEF1) : const Color(0xFFF1F3FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUrgent) ...[
            const Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: _DeletedStyle.danger,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            '${daysRemaining}d left',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isUrgent ? _DeletedStyle.danger : _DeletedStyle.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestoreButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RestoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: _DeletedStyle.primaryGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _DeletedStyle.glowShadow,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restore_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Restore',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermanentDeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PermanentDeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEF1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: _DeletedStyle.danger),
            SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _DeletedStyle.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeletedCircleAvatar extends StatelessWidget {
  final DeletedConversationEntry item;

  const _DeletedCircleAvatar({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 3,
            child: _MiniMemberCircle(
              label: _labelAt(0),
              color: _DeletedStyle.teal,
            ),
          ),
          Positioned(
            left: 19,
            top: 0,
            child: _MiniMemberCircle(
              label: _labelAt(1),
              color: const Color(0xFF4F7DF3),
            ),
          ),
          Positioned(
            left: 9,
            top: 19,
            child: _MiniMemberCircle(
              label: _labelAt(2),
              color: _DeletedStyle.primary,
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                gradient: _DeletedStyle.primaryGradient,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.blur_circular_rounded,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _labelAt(int index) {
    if (item.members.isNotEmpty && index < item.members.length) {
      final name = item.members[index].name.trim();
      if (name.isNotEmpty) return name[0].toUpperCase();
    }

    final seed = item.name.replaceAll(' ', '');
    if (seed.isEmpty) return '?';
    return seed[index % seed.length].toUpperCase();
  }
}

class _MiniMemberCircle extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniMemberCircle({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        Colors.grey,
        BlendMode.saturation,
      ),
      child: Container(
        width: 29,
        height: 29,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.20),
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
      ),
    );
  }
}

class _DeletedEmptyState extends StatelessWidget {
  final VoidCallback onBack;

  const _DeletedEmptyState({
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 650),
            tween: Tween(begin: 0.92, end: 1),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _DeletedStyle.primary.withOpacity(0.12),
                        _DeletedStyle.secondary.withOpacity(0.12),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.blur_circular_rounded,
                    size: 42,
                    color: _DeletedStyle.primary,
                  ),
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: _DeletedStyle.teal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'All clear',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _DeletedStyle.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              'No deleted conversations. Your important connections are safe and sound.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.35,
                color: _DeletedStyle.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                gradient: _DeletedStyle.primaryGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: _DeletedStyle.glowShadow,
              ),
              child: const Text(
                'Back to Messages',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiftCard extends StatelessWidget {
  final Widget child;

  const _LiftCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.96),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE7E9F5)),
          boxShadow: _DeletedStyle.cardShadow,
        ),
        child: child,
      ),
    );
  }
}
