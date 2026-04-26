import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/circles_provider.dart';

class JoinCircleDialog extends StatefulWidget {
  const JoinCircleDialog({super.key});

  @override
  State<JoinCircleDialog> createState() => _JoinCircleDialogState();
}

class _JoinCircleDialogState extends State<JoinCircleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  final _inviteCodeFocus = FocusNode();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _inviteCodeFocus.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _inviteCodeFocus
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await context.read<CirclesProvider>().joinCircle(
            _inviteCodeController.text.trim(),
          );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Joined circle successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to join circle: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _inputDecoration() {
    final active = _inviteCodeFocus.hasFocus;

    return InputDecoration(
      hintText: 'TET-XXXX-XXXX',
      filled: true,
      fillColor: Colors.white.withOpacity(0.94),
      hintStyle: const TextStyle(
        color: Color(0xFF98A2B3),
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      prefixIcon: Icon(
        Icons.key_rounded,
        color: active ? _JoinSheetStyle.primary : _JoinSheetStyle.muted,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFE3E5EF), width: 1.6),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: _JoinSheetStyle.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.6),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: _JoinSheetStyle.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          child: Stack(
            children: [
              const Positioned.fill(child: _SheetOrbs()),
              SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 420),
                    tween: Tween(begin: 0, end: 1),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const _DragHandle(),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _GradientIconBox(
                                icon: Icons.group_add_rounded,
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Join Circle',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: _JoinSheetStyle.ink,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Enter your invite code',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: _JoinSheetStyle.muted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _CloseButton(
                                disabled: _isSubmitting,
                                onTap: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          const _JoinMotif(),
                          const SizedBox(height: 22),
                          _GlassPanel(
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 180),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: _inviteCodeFocus.hasFocus
                                          ? _JoinSheetStyle.primary
                                          : _JoinSheetStyle.ink,
                                    ),
                                    child: const Text('Invite code'),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _inviteCodeController,
                                  focusNode: _inviteCodeFocus,
                                  textCapitalization: TextCapitalization.characters,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) {
                                    if (!_isSubmitting) _handleJoin();
                                  },
                                  decoration: _inputDecoration(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter an invite code';
                                    }
                                    if (value.trim().length < 6) {
                                      return 'Invite code looks too short';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F0FF),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: _JoinSheetStyle.primary.withOpacity(0.12),
                                    ),
                                  ),
                                  child: const Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        size: 20,
                                        color: _JoinSheetStyle.primary,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Ask the circle creator for an invite code to join their trusted group.',
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            height: 1.4,
                                            color: _JoinSheetStyle.muted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: _SecondaryButton(
                                  label: 'Cancel',
                                  disabled: _isSubmitting,
                                  onTap: () => Navigator.pop(context),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PrimaryButton(
                                  label: 'Join Circle',
                                  isSubmitting: _isSubmitting,
                                  onTap: _handleJoin,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _JoinSheetStyle {
  static const Color background = Color(0xFFFBFCFF);
  static const Color primary = Color(0xFF6F63F6);
  static const Color secondary = Color(0xFFD96BEF);
  static const Color ink = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6F63F6), Color(0xFFD96BEF)],
  );

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF6F63F6).withOpacity(0.09),
          blurRadius: 26,
          offset: const Offset(0, 14),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
}

class _SheetOrbs extends StatelessWidget {
  const _SheetOrbs();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -110,
          right: -110,
          child: _Orb(size: 250, color: _JoinSheetStyle.primary.withOpacity(0.12)),
        ),
        Positioned(
          bottom: -120,
          left: -100,
          child: _Orb(size: 240, color: _JoinSheetStyle.secondary.withOpacity(0.10)),
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

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0xFFD0D5DD),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _GradientIconBox extends StatelessWidget {
  final IconData icon;

  const _GradientIconBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: _JoinSheetStyle.primaryGradient,
        borderRadius: BorderRadius.circular(19),
        boxShadow: [
          BoxShadow(
            color: _JoinSheetStyle.secondary.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 26),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final bool disabled;
  final VoidCallback onTap;

  const _CloseButton({required this.disabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: disabled ? null : onTap,
      icon: const Icon(Icons.close_rounded),
      color: _JoinSheetStyle.muted,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.72),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;

  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.70),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.88), width: 1.2),
        boxShadow: _JoinSheetStyle.softShadow,
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool isSubmitting;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.isSubmitting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSubmitting ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isSubmitting ? 0.78 : 1,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: _JoinSheetStyle.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _JoinSheetStyle.secondary.withOpacity(0.26),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final bool disabled;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.label,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: disabled ? null : onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFF0F2FA),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _JoinSheetStyle.ink,
          ),
        ),
      ),
    );
  }
}

class _JoinMotif extends StatelessWidget {
  const _JoinMotif();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      tween: Tween(begin: 0.88, end: 1),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: SizedBox(
        width: 94,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 10,
              child: _JoinCircle(color: _JoinSheetStyle.primary.withOpacity(0.22)),
            ),
            Positioned(
              right: 10,
              child: _JoinCircle(color: _JoinSheetStyle.secondary.withOpacity(0.22)),
            ),
            _JoinCircle(color: _JoinSheetStyle.primary.withOpacity(0.28), size: 40),
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                gradient: _JoinSheetStyle.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinCircle extends StatelessWidget {
  final Color color;
  final double size;

  const _JoinCircle({required this.color, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}
