import 'package:flutter/material.dart';

class TetherChatPalette {
  static const Color background = Color(0xFFFBFAFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF111827);
  static const Color muted = Color(0xFF64748B);
  static const Color softMuted = Color(0xFF94A3B8);
  static const Color border = Color(0xFFECEAF8);
  static const Color primary = Color(0xFF6C5CFF);
  static const Color accent = Color(0xFFD66BEE);
  static const Color green = Color(0xFF22C55E);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6C5CFF),
      Color(0xFF7B61FF),
      Color(0xFFD66BEE),
    ],
  );
}

class TetherChatBackground extends StatelessWidget {
  final Widget child;

  const TetherChatBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  TetherChatPalette.background,
                  Colors.white,
                  TetherChatPalette.primary.withOpacity(0.035),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -120,
          right: -95,
          child: _Orb(
            size: 260,
            color: TetherChatPalette.primary.withOpacity(0.08),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -120,
          child: _Orb(
            size: 250,
            color: TetherChatPalette.accent.withOpacity(0.08),
          ),
        ),
        child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;

  const _Orb({
    required this.size,
    required this.color,
  });

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

class TetherHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const TetherHeaderIconButton({
    super.key,
    required this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      margin: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.86),
        shape: BoxShape.circle,
        border: Border.all(color: TetherChatPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        splashRadius: 21,
        onPressed: onPressed,
        icon: Icon(icon, size: 21),
        color: TetherChatPalette.muted,
      ),
    );
  }
}

class TetherChatBubble extends StatelessWidget {
  final bool isMe;
  final String? text;
  final String? mediaUrl;
  final bool isDeleted;
  final String metaText;
  final VoidCallback? onLongPress;

  final bool showSender;
  final String? senderName;
  final String? senderAvatarUrl;
  final bool showAvatar;
  final bool showTail;

  const TetherChatBubble({
    super.key,
    required this.isMe,
    required this.metaText,
    this.text,
    this.mediaUrl,
    this.isDeleted = false,
    this.onLongPress,
    this.showSender = false,
    this.senderName,
    this.senderAvatarUrl,
    this.showAvatar = false,
    this.showTail = true,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = text != null && text!.trim().isNotEmpty;
    final hasMedia = mediaUrl != null && mediaUrl!.trim().isNotEmpty;
    final maxWidth = MediaQuery.of(context).size.width > 720
        ? 420.0
        : MediaQuery.of(context).size.width * 0.74;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            SizedBox(
              width: 42,
              child: showAvatar
                  ? _BubbleAvatar(
                      name: senderName ?? '?',
                      avatarUrl: senderAvatarUrl,
                      radius: 18,
                    )
                  : const SizedBox.shrink(),
            ),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSender && !isMe) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 5),
                    child: Text(
                      senderName ?? 'Unknown',
                      style: const TextStyle(
                        color: TetherChatPalette.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
                GestureDetector(
                  onLongPress: onLongPress,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    padding: EdgeInsets.all(hasMedia && !hasText ? 8 : 14),
                    decoration: BoxDecoration(
                      gradient:
                          isMe && !isDeleted ? TetherChatPalette.primaryGradient : null,
                      color: isDeleted
                          ? (isMe
                              ? TetherChatPalette.primary.withOpacity(0.65)
                              : Colors.white.withOpacity(0.86))
                          : (isMe ? null : Colors.white.withOpacity(0.94)),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(24),
                        topRight: const Radius.circular(24),
                        bottomLeft: Radius.circular(
                          isMe ? 24 : (showTail ? 8 : 24),
                        ),
                        bottomRight: Radius.circular(
                          isMe ? (showTail ? 8 : 24) : 24,
                        ),
                      ),
                      border: isMe
                          ? null
                          : Border.all(color: TetherChatPalette.border),
                      boxShadow: [
                        BoxShadow(
                          color: (isMe
                                  ? TetherChatPalette.primary
                                  : Colors.black)
                              .withOpacity(isMe ? 0.18 : 0.045),
                          blurRadius: isMe ? 22 : 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (isDeleted)
                          Text(
                            'Message deleted',
                            style: TextStyle(
                              color: isMe ? Colors.white70 : TetherChatPalette.muted,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else ...[
                          if (hasMedia)
                            TetherMediaPreview(
                              mediaUrl: mediaUrl!,
                              isMe: isMe,
                            ),
                          if (hasText && hasMedia) const SizedBox(height: 8),
                          if (hasText)
                            Text(
                              text!.trim(),
                              style: TextStyle(
                                color: isMe ? Colors.white : TetherChatPalette.text,
                                fontSize: 15.5,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: Text(
                    metaText,
                    style: const TextStyle(
                      color: TetherChatPalette.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
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

class TetherMediaPreview extends StatelessWidget {
  final String mediaUrl;
  final bool isMe;

  const TetherMediaPreview({
    super.key,
    required this.mediaUrl,
    required this.isMe,
  });

  bool get _isImage {
    final lower = mediaUrl.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  bool get _isVideo {
    final lower = mediaUrl.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mov');
  }

  @override
  Widget build(BuildContext context) {
    if (_isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          mediaUrl,
          width: 270,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(
            icon: Icons.lock_outline_rounded,
            label: 'Media unavailable',
          ),
        ),
      );
    }

    if (_isVideo) {
      return _fallback(
        icon: Icons.play_circle_fill_rounded,
        label: 'Video attachment',
      );
    }

    return _fallback(
      icon: Icons.insert_drive_file_rounded,
      label: 'Attachment',
    );
  }

  Widget _fallback({required IconData icon, required String label}) {
    return Container(
      width: 245,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.16) : const Color(0xFFF4F1FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe
              ? Colors.white.withOpacity(0.16)
              : TetherChatPalette.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isMe ? Colors.white : TetherChatPalette.primary,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: isMe ? Colors.white : TetherChatPalette.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TetherComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final bool canSend;
  final bool isUploading;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;
  final String hintText;

  const TetherComposer({
    super.key,
    required this.controller,
    required this.hasText,
    required this.canSend,
    required this.isUploading,
    required this.onAttach,
    required this.onSend,
    required this.onChanged,
    this.hintText = 'Message',
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          border: const Border(
            top: BorderSide(color: TetherChatPalette.border),
          ),
          boxShadow: [
            BoxShadow(
              color: TetherChatPalette.primary.withOpacity(0.06),
              blurRadius: 22,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: TetherChatPalette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.035),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: isUploading ? null : onAttach,
                icon: isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.attach_file_rounded),
                color: TetherChatPalette.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F1FF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: TetherChatPalette.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) {
                          if (canSend && hasText) onSend();
                        },
                        onChanged: onChanged,
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: const TextStyle(
                            color: TetherChatPalette.softMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.mood_outlined),
                      color: TetherChatPalette.muted,
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: hasText ? TetherChatPalette.primaryGradient : null,
                color: hasText ? null : const Color(0xFFE8E5F8),
                shape: BoxShape.circle,
                boxShadow: hasText
                    ? [
                        BoxShadow(
                          color: TetherChatPalette.primary.withOpacity(0.26),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: IconButton(
                onPressed: canSend && hasText ? onSend : null,
                icon: Icon(
                  hasText ? Icons.send_rounded : Icons.mic_none_rounded,
                  color: hasText ? Colors.white : TetherChatPalette.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TetherTypingPill extends StatelessWidget {
  final String label;
  final bool visible;

  const TetherTypingPill({
    super.key,
    required this.label,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: !visible
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.94),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: TetherChatPalette.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.035),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TetherTypingDots(),
                      if (label.isNotEmpty) ...[
                        const SizedBox(width: 9),
                        Text(
                          label,
                          style: const TextStyle(
                            color: TetherChatPalette.muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class TetherTypingDots extends StatefulWidget {
  const TetherTypingDots({super.key});

  @override
  State<TetherTypingDots> createState() => _TetherTypingDotsState();
}

class _TetherTypingDotsState extends State<TetherTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _dot(double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = (_controller.value - delay).clamp(0.0, 1.0);
        final opacity = (value <= 0.5) ? value * 2 : (1 - value) * 2;

        return Opacity(
          opacity: opacity.clamp(0.25, 1.0),
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: TetherChatPalette.primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(0.0),
        const SizedBox(width: 5),
        _dot(0.2),
        const SizedBox(width: 5),
        _dot(0.4),
      ],
    );
  }
}

class _BubbleAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double radius;

  const _BubbleAvatar({
    required this.name,
    required this.avatarUrl,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEDE9FE),
      backgroundImage: avatarUrl != null && avatarUrl!.trim().isNotEmpty
          ? NetworkImage(avatarUrl!)
          : null,
      child: avatarUrl == null || avatarUrl!.trim().isEmpty
          ? Text(
              initial,
              style: TextStyle(
                color: TetherChatPalette.primary,
                fontWeight: FontWeight.w900,
                fontSize: radius * 0.82,
              ),
            )
          : null,
    );
  }
}
