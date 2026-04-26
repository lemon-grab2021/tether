import 'package:flutter/material.dart';

/// Shared visual language for the redesigned Tether UI.
/// Place this file at: lib/presentation/widgets/tether_visual_kit.dart
///
/// This is deliberately data-agnostic. Keep your existing providers/services and
/// use these widgets only for presentation.
class TetherVisualPalette {
  static const Color background = Color(0xFFFBFAFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF6F3FF);
  static const Color text = Color(0xFF111827);
  static const Color muted = Color(0xFF64748B);
  static const Color softMuted = Color(0xFF94A3B8);
  static const Color border = Color(0xFFECEAF8);
  static const Color primary = Color(0xFF6C5CFF);
  static const Color accent = Color(0xFFD66BEE);
  static const Color blue = Color(0xFF1274E7);
  static const Color green = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C5CFF), Color(0xFF7B61FF), Color(0xFFD66BEE)],
  );

  static LinearGradient softPageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [background, Colors.white, primary.withOpacity(0.035)],
  );
}

class TetherPageBackground extends StatelessWidget {
  final Widget child;
  final bool safeArea;

  const TetherPageBackground({
    super.key,
    required this.child,
    this.safeArea = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: TetherVisualPalette.softPageGradient,
            ),
          ),
        ),
        Positioned(
          top: -115,
          right: -90,
          child: _Orb(
            size: 245,
            color: TetherVisualPalette.primary.withOpacity(0.085),
          ),
        ),
        Positioned(
          top: 280,
          left: -120,
          child: _Orb(
            size: 240,
            color: TetherVisualPalette.accent.withOpacity(0.075),
          ),
        ),
        Positioned(
          bottom: 80,
          right: -120,
          child: _Orb(
            size: 235,
            color: TetherVisualPalette.primary.withOpacity(0.06),
          ),
        ),
        child,
      ],
    );

    return safeArea ? SafeArea(child: content) : content;
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;

  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 90,
              spreadRadius: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class TetherFadeSlide extends StatelessWidget {
  final Widget child;
  final int delayMs;
  final double yOffset;

  const TetherFadeSlide({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.yOffset = 18,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + delayMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, yOffset * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class TetherTapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  const TetherTapScale({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
  });

  @override
  State<TetherTapScale> createState() => _TetherTapScaleState();
}

class _TetherTapScaleState extends State<TetherTapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class TetherCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool gradientHover;

  const TetherCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.gradientHover = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: TetherVisualPalette.border),
        boxShadow: [
          BoxShadow(
            color: TetherVisualPalette.primary.withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    return TetherTapScale(onTap: onTap, child: card);
  }
}

class TetherHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  const TetherHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        border: const Border(bottom: BorderSide(color: TetherVisualPalette.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: TetherVisualPalette.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: TetherVisualPalette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class TetherIconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;

  const TetherIconBadge({
    super.key,
    required this.icon,
    this.size = 42,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: TetherVisualPalette.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: TetherVisualPalette.primary.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.52),
    );
  }
}

class TetherHeaderAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool hasBadge;

  const TetherHeaderAction({
    super.key,
    required this.icon,
    this.onPressed,
    this.hasBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TetherVisualPalette.border),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: Icon(icon, size: 20),
            color: TetherVisualPalette.muted,
          ),
        ),
        if (hasBadge)
          Positioned(
            right: 5,
            top: 5,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: TetherVisualPalette.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class TetherSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const TetherSearchField({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
  });

  @override
  State<TetherSearchField> createState() => _TetherSearchFieldState();
}

class _TetherSearchFieldState extends State<TetherSearchField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (value) => setState(() => _focused = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: _focused ? Colors.white : const Color(0xFFF4F1FF),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _focused
                ? TetherVisualPalette.primary.withOpacity(0.45)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: TetherVisualPalette.primary.withOpacity(0.11),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: _focused ? TetherVisualPalette.primary : TetherVisualPalette.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: widget.controller,
                onChanged: (value) {
                  setState(() {});
                  widget.onChanged?.call(value);
                },
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  border: InputBorder.none,
                  hintStyle: const TextStyle(
                    color: TetherVisualPalette.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (widget.controller.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  widget.controller.clear();
                  widget.onClear?.call();
                  widget.onChanged?.call('');
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded),
                color: TetherVisualPalette.muted,
              ),
          ],
        ),
      ),
    );
  }
}

class TetherSegmentedTabs extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Map<int, int> badges;

  const TetherSegmentedTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    this.badges = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = selectedIndex == index;
          final badge = badges[index];
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 190),
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tabs[index],
                      style: TextStyle(
                        fontSize: 14,
                        color: selected ? TetherVisualPalette.text : TetherVisualPalette.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (badge != null && badge > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          gradient: TetherVisualPalette.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class TetherSectionTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool onlinePulse;

  const TetherSectionTitle({
    super.key,
    required this.text,
    this.icon,
    this.onlinePulse = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          if (onlinePulse)
            const _PulseDot()
          else if (icon != null)
            Icon(icon, size: 16, color: TetherVisualPalette.muted),
          if (onlinePulse || icon != null) const SizedBox(width: 8),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w900,
              color: onlinePulse ? TetherVisualPalette.primary : TetherVisualPalette.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: Container(
        width: 9,
        height: 9,
        decoration: const BoxDecoration(
          color: TetherVisualPalette.green,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class TetherUserAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final bool online;
  final bool showOnline;

  const TetherUserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 52,
    this.online = false,
    this.showOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: imageUrl == null || imageUrl!.trim().isEmpty
                ? TetherVisualPalette.primaryGradient
                : null,
            boxShadow: [
              BoxShadow(
                color: TetherVisualPalette.primary.withOpacity(0.15),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: CircleAvatar(
            backgroundColor: Colors.transparent,
            backgroundImage: imageUrl != null && imageUrl!.trim().isNotEmpty ? NetworkImage(imageUrl!) : null,
            child: imageUrl == null || imageUrl!.trim().isEmpty
                ? Text(
                    initial,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.34,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : null,
          ),
        ),
        if (showOnline)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: size * 0.20,
              height: size * 0.20,
              decoration: BoxDecoration(
                color: online ? TetherVisualPalette.green : TetherVisualPalette.softMuted,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class TetherGradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expanded;
  final bool loading;

  const TetherGradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expanded = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : TetherVisualPalette.primaryGradient,
        color: onPressed == null ? const Color(0xFFE8E5F8) : null,
        borderRadius: BorderRadius.circular(18),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                  color: TetherVisualPalette.primary.withOpacity(0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
      ),
    );

    return SizedBox(
      width: expanded ? double.infinity : null,
      child: TetherTapScale(onTap: loading ? null : onPressed, child: button),
    );
  }
}

class TetherSoftButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;

  const TetherSoftButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = TetherVisualPalette.primary,
  });

  @override
  Widget build(BuildContext context) {
    return TetherTapScale(
      onTap: onPressed,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class TetherEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const TetherEmptyState({
    super.key,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: TetherVisualPalette.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: TetherVisualPalette.primary.withOpacity(0.55)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: TetherVisualPalette.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TetherVisualPalette.muted,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TetherSettingsTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool toggle;
  final bool initialToggleValue;

  const TetherSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.toggle = false,
    this.initialToggleValue = false,
  });

  @override
  State<TetherSettingsTile> createState() => _TetherSettingsTileState();
}

class _TetherSettingsTileState extends State<TetherSettingsTile> {
  late bool enabled = widget.initialToggleValue;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.toggle
          ? () => setState(() => enabled = !enabled)
          : widget.onTap,
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
              child: Icon(widget.icon, color: TetherVisualPalette.primary, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: TetherVisualPalette.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.5,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: TetherVisualPalette.muted, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.toggle)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48,
                height: 28,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: enabled ? TetherVisualPalette.primaryGradient : null,
                  color: enabled ? null : const Color(0xFFE8E5F8),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded, color: TetherVisualPalette.softMuted),
          ],
        ),
      ),
    );
  }
}

class TetherSettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const TetherSettingsSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TetherSectionTitle(text: title),
        TetherCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: List.generate(children.length, (index) {
              return Column(
                children: [
                  children[index],
                  if (index != children.length - 1)
                    const Divider(height: 1, color: TetherVisualPalette.border),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
