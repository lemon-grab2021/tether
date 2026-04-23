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

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F7FB),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deleted',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              '${items.length} conversation${items.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoCircleIcon(),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-delete enabled',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Deleted conversations are permanently removed after 30 days. You can restore them anytime before then.',
                        style: TextStyle(
                          fontSize: 14.5,
                          height: 1.35,
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
          if (items.isEmpty)
            _DeletedEmptyState(
              onBack: () => Navigator.pop(context),
            )
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
    );
  }
}

class _InfoCircleIcon extends StatelessWidget {
  const _InfoCircleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: Color(0xFFEAF4FF),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.schedule_rounded,
        color: Color(0xFF1274E7),
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

  Future<void> _runAnimatedRemoval(Future<void> Function() action,
      {required bool restore}) async {
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

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 240),
      opacity: _isAnimatingOut ? 0 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 240),
        scale: _isAnimatingOut ? 0.96 : 1,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 240),
          offset: _isAnimatingOut
              ? (_isRestoreAnimation
                  ? const Offset(0.18, 0)
                  : const Offset(0, -0.04))
              : Offset.zero,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
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
              children: [
                Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
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
                            Stack(
                              children: [
                                ColorFiltered(
                                  colorFilter: const ColorFilter.mode(
                                    Colors.grey,
                                    BlendMode.saturation,
                                  ),
                                  child: AppAvatar(
                                    name: item.name,
                                    avatarUrl: item.avatarUrl,
                                    radius: 24,
                                  ),
                                ),
                                Positioned.fill(
                                  child: Center(
                                    child: Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.75),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            _DeletedCircleAvatar(item: item),
                          const SizedBox(width: 12),
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
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    if (item.type == DeletedConversationType.circle)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Text(
                                          '${item.members.length}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF94A3B8),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isUrgent
                                  ? const Color(0xFFFFE4E8)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isUrgent) ...[
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 14,
                                    color: Color(0xFFD92D20),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  '${item.daysRemaining}d left',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isUrgent
                                        ? const Color(0xFFD92D20)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          widget.deletedDateText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                await _runAnimatedRemoval(() async {
                                  provider.restoreConversation(item.deletedId);
                                }, restore: true);

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Conversation restored'),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEAF4FF),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.restore_rounded,
                                      color: Color(0xFF1274E7),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Restore',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1274E7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
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
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEEF1),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFD92D20),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFD92D20),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

class _DeletedCircleAvatar extends StatelessWidget {
  final DeletedConversationEntry item;

  const _DeletedCircleAvatar({
    required this.item,
  });

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
            top: 2,
            child: _MiniMemberCircle(
              label: _labelAt(0),
              color: const Color(0xFF11C5B7),
            ),
          ),
          Positioned(
            left: 18,
            top: 0,
            child: _MiniMemberCircle(
              label: _labelAt(1),
              color: const Color(0xFF4F7DF3),
            ),
          ),
          Positioned(
            left: 9,
            top: 18,
            child: _MiniMemberCircle(
              label: _labelAt(2),
              color: const Color(0xFF6E63F6),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.blur_circular_rounded,
                size: 10,
                color: Color(0xFF1274E7),
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.blur_circular_rounded,
                  size: 38,
                  color: Color(0xFF94A3B8),
                ),
              ),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEAF4FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: Color(0xFF1274E7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'All clear',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No deleted conversations. Your important connections are safe and sound.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.35,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: onBack,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEAF4FF),
              foregroundColor: const Color(0xFF1274E7),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text(
              'Back to Messages',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}