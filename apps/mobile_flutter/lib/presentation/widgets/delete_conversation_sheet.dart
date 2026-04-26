import 'package:flutter/material.dart';

Future<bool> showDeleteConversationSheet(
  BuildContext context, {
  required String title,
  bool isCircle = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DeleteConversationSheet(
      title: title,
      isCircle: isCircle,
    ),
  );

  return result ?? false;
}

Future<bool> showPermanentDeleteConversationSheet(
  BuildContext context, {
  required String title,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PermanentDeleteConversationSheet(title: title),
  );

  return result ?? false;
}

class _DeleteConversationSheet extends StatelessWidget {
  final String title;
  final bool isCircle;

  const _DeleteConversationSheet({
    required this.title,
    required this.isCircle,
  });

  @override
  Widget build(BuildContext context) {
    return _DangerSheetShell(
      child: _DangerSheetContent(
        icon: Icons.delete_outline_rounded,
        title: 'Delete conversation?',
        description: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
              color: _DeleteSheetStyle.muted,
              fontWeight: FontWeight.w500,
            ),
            children: [
              const TextSpan(text: 'Your conversation with '),
              TextSpan(
                text: title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _DeleteSheetStyle.ink,
                ),
              ),
              const TextSpan(
                text:
                    ' will be moved to Deleted and permanently removed after 30 days.',
              ),
            ],
          ),
        ),
        badge: isCircle
            ? const _SmallCircleBadge(icon: Icons.blur_circular_rounded)
            : null,
        primaryLabel: 'Delete Conversation',
        primaryIcon: Icons.delete_outline_rounded,
        onPrimary: () => Navigator.pop(context, true),
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(context, false),
      ),
    );
  }
}

class _PermanentDeleteConversationSheet extends StatelessWidget {
  final String title;

  const _PermanentDeleteConversationSheet({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return _DangerSheetShell(
      child: _DangerSheetContent(
        icon: Icons.delete_forever_rounded,
        title: 'Delete permanently?',
        description: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 16,
              height: 1.45,
              color: _DeleteSheetStyle.muted,
              fontWeight: FontWeight.w500,
            ),
            children: [
              const TextSpan(text: 'This will permanently delete '),
              TextSpan(
                text: title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _DeleteSheetStyle.ink,
                ),
              ),
              const TextSpan(text: '. This action cannot be undone.'),
            ],
          ),
        ),
        primaryLabel: 'Delete Permanently',
        primaryIcon: Icons.delete_forever_rounded,
        onPrimary: () => Navigator.pop(context, true),
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(context, false),
      ),
    );
  }
}

class _DeleteSheetStyle {
  static const Color background = Color(0xFFFBFCFF);
  static const Color danger = Color(0xFFD92D20);
  static const Color dangerSoft = Color(0xFFFFE4E8);
  static const Color ink = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color primary = Color(0xFF6F63F6);
  static const Color secondary = Color(0xFFD96BEF);

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD92D20), Color(0xFFFF6B6B)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6F63F6), Color(0xFFD96BEF)],
  );

  static List<BoxShadow> get sheetShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 32,
          offset: const Offset(0, -8),
        ),
      ];

  static List<BoxShadow> get dangerShadow => [
        BoxShadow(
          color: danger.withOpacity(0.22),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ];
}

class _DangerSheetShell extends StatelessWidget {
  final Widget child;

  const _DangerSheetShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _DeleteSheetStyle.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        boxShadow: _DeleteSheetStyle.sheetShadow,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        child: Stack(
          children: [
            const Positioned.fill(child: _DangerOrbs()),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 420),
                  tween: Tween(begin: 0, end: 1),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, animatedChild) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - value)),
                        child: animatedChild,
                      ),
                    );
                  },
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerOrbs extends StatelessWidget {
  const _DangerOrbs();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -110,
          child: _Orb(
            size: 250,
            color: _DeleteSheetStyle.danger.withOpacity(0.08),
          ),
        ),
        Positioned(
          bottom: -130,
          left: -110,
          child: _Orb(
            size: 260,
            color: _DeleteSheetStyle.secondary.withOpacity(0.09),
          ),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;

  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _DangerSheetContent extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget description;
  final Widget? badge;
  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  const _DangerSheetContent({
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.primaryIcon,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _DragHandle(),
        const SizedBox(height: 22),
        Stack(
          clipBehavior: Clip.none,
          children: [
            const _DangerPulseRing(size: 94),
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                gradient: _DeleteSheetStyle.dangerGradient,
                shape: BoxShape.circle,
                boxShadow: _DeleteSheetStyle.dangerShadow,
              ),
              child: Icon(icon, size: 36, color: Colors.white),
            ),
            if (badge != null) Positioned(right: -2, bottom: -2, child: badge!),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: _DeleteSheetStyle.ink,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: description,
        ),
        const SizedBox(height: 24),
        _NoticeBox(
          icon: Icons.schedule_rounded,
          text: primaryLabel.contains('Permanently')
              ? 'Permanent deletion removes this item immediately.'
              : 'You can restore it from Deleted before the 30-day retention window ends.',
        ),
        const SizedBox(height: 24),
        _DangerActionButton(
          label: primaryLabel,
          icon: primaryIcon,
          onTap: onPrimary,
        ),
        const SizedBox(height: 10),
        _CancelActionButton(
          label: secondaryLabel,
          onTap: onSecondary,
        ),
      ],
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0xFFD0D5DD),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _DangerPulseRing extends StatelessWidget {
  final double size;

  const _DangerPulseRing({required this.size});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 750),
      tween: Tween(begin: 0.80, end: 1),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _DeleteSheetStyle.dangerSoft.withOpacity(0.82),
        ),
      ),
    );
  }
}

class _SmallCircleBadge extends StatelessWidget {
  final IconData icon;

  const _SmallCircleBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: _DeleteSheetStyle.accentGradient,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
}

class _NoticeBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _NoticeBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _DeleteSheetStyle.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: _DeleteSheetStyle.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DangerActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: _DeleteSheetStyle.dangerGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: _DeleteSheetStyle.dangerShadow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CancelActionButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF0F2FA),
          foregroundColor: _DeleteSheetStyle.ink,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
