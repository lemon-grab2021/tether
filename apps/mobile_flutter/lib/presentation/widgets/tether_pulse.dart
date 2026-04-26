import 'package:flutter/material.dart';

enum TetherPulseState {
  strong,
  needsReply,
  quiet,
  dormant,
  newTether,
}

// simple bond logic, will improve in future work
class TetherPulseHelper {
  static TetherPulseState fromActivity({
    required DateTime? lastActivityAt,
    required bool hasUnread,
    required bool isNew,
    DateTime? createdAt,
    Duration newTetherWindow = const Duration(hours: 24),
  }) {
    final now = DateTime.now();

    final isRecentlyCreated =
        createdAt != null && now.difference(createdAt).abs() <= newTetherWindow;

    if (isNew || isRecentlyCreated || lastActivityAt == null) {
      return TetherPulseState.newTether;
    }

    if (hasUnread) {
      return TetherPulseState.needsReply;
    }

    final hoursSince = now.difference(lastActivityAt).inHours;

    if (hoursSince < 24) {
      return TetherPulseState.strong;
    }

    if (hoursSince < 24 * 7) {
      return TetherPulseState.quiet;
    }

    return TetherPulseState.dormant;
  }
}

class TetherPulsePill extends StatelessWidget {
  final TetherPulseState state;

  const TetherPulsePill({
    super.key,
    required this.state,
  });

  _PulseConfig get _config {
    switch (state) {
      case TetherPulseState.strong:
        return const _PulseConfig(
          label: 'Strong bond',
          textColor: Color(0xFF008A6E),
          dotColor: Color(0xFF11C5B7),
          bgStart: Color(0x3311C5B7),
          bgEnd: Color(0x2210B981),
          animate: true,
        );

      case TetherPulseState.needsReply:
        return const _PulseConfig(
          label: 'Needs reply',
          textColor: Color(0xFF6C5CFF),
          dotColor: Color(0xFF6C5CFF),
          bgStart: Color(0x226C5CFF),
          bgEnd: Color(0x22D66BEE),
          animate: true,
        );

      case TetherPulseState.quiet:
        return const _PulseConfig(
          label: 'Quiet',
          textColor: Color(0xFF64748B),
          dotColor: Color(0xFF94A3B8),
          bgStart: Color(0xFFEFF4F8),
          bgEnd: Color(0xFFF6F8FB),
          animate: false,
        );

      case TetherPulseState.dormant:
        return const _PulseConfig(
          label: 'Reconnect',
          textColor: Color(0xFF94A3B8),
          dotColor: Color(0xFFCBD5E1),
          bgStart: Color(0xFFF1F5F9),
          bgEnd: Color(0xFFF8FAFC),
          animate: false,
        );

      case TetherPulseState.newTether:
        return const _PulseConfig(
          label: 'New tether',
          textColor: Color(0xFF5B5DF0),
          dotColor: Color(0xFF6C5CFF),
          bgStart: Color(0x226C5CFF),
          bgEnd: Color(0x227B61FF),
          animate: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [config.bgStart, config.bgEnd],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(
            color: config.dotColor,
            animate: config.animate,
          ),
          const SizedBox(width: 6),
          Text(
            config.label.toUpperCase(),
            style: TextStyle(
              color: config.textColor,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.45,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  final bool animate;

  const _PulseDot({
    required this.color,
    required this.animate,
  });

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      );
    }

    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = _controller.value;

          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 7 + (value * 7),
                height: 7 + (value * 7),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity((1 - value) * 0.28),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.35),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PulseConfig {
  final String label;
  final Color textColor;
  final Color dotColor;
  final Color bgStart;
  final Color bgEnd;
  final bool animate;

  const _PulseConfig({
    required this.label,
    required this.textColor,
    required this.dotColor,
    required this.bgStart,
    required this.bgEnd,
    required this.animate,
  });
}