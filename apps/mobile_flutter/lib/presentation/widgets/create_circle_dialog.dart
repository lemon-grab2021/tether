import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/circles_provider.dart';

class CreateCircleDialog extends StatefulWidget {
  const CreateCircleDialog({super.key});

  @override
  State<CreateCircleDialog> createState() => _CreateCircleDialogState();
}

class _CreateCircleDialogState extends State<CreateCircleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _nameFocus = FocusNode();
  final _descriptionFocus = FocusNode();

  bool _isPrivate = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_handleFocusChange);
    _descriptionFocus.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocus
      ..removeListener(_handleFocusChange)
      ..dispose();
    _descriptionFocus
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await context.read<CirclesProvider>().createCircle(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            isPrivate: _isPrivate,
          );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Circle created successfully'),
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
            'Failed to create circle: ${e.toString().replaceAll('Exception: ', '')}',
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

  InputDecoration _inputDecoration({
    required String hintText,
    required FocusNode focusNode,
    IconData? prefixIcon,
  }) {
    final active = focusNode.hasFocus;

    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white.withOpacity(0.94),
      hintStyle: const TextStyle(
        color: Color(0xFF98A2B3),
        fontSize: 15.5,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(
              prefixIcon,
              color: active ? _CircleSheetStyle.primary : _CircleSheetStyle.muted,
            ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFE3E5EF), width: 1.6),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: _CircleSheetStyle.primary, width: 2),
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

  Widget _label(String text, {String? optional, FocusNode? focusNode}) {
    final active = focusNode?.hasFocus ?? false;

    return Align(
      alignment: Alignment.centerLeft,
      child: RichText(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: active ? _CircleSheetStyle.primary : _CircleSheetStyle.ink,
          ),
          children: [
            if (optional != null)
              TextSpan(
                text: ' $optional',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _CircleSheetStyle.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: _CircleSheetStyle.background,
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
                                icon: Icons.blur_circular_rounded,
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Create Circle',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: _CircleSheetStyle.ink,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Start a new trusted group',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: _CircleSheetStyle.muted,
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
                          const _CircleMotif(),
                          const SizedBox(height: 22),
                          _GlassPanel(
                            child: Column(
                              children: [
                                _label('Circle name', focusNode: _nameFocus),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _nameController,
                                  focusNode: _nameFocus,
                                  textInputAction: TextInputAction.next,
                                  decoration: _inputDecoration(
                                    hintText: 'Family, Close Friends, Book Club...',
                                    focusNode: _nameFocus,
                                    prefixIcon: Icons.groups_2_outlined,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter a circle name';
                                    }
                                    if (value.trim().length < 2) {
                                      return 'Circle name is too short';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                _label(
                                  'Description',
                                  optional: '(optional)',
                                  focusNode: _descriptionFocus,
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _descriptionController,
                                  focusNode: _descriptionFocus,
                                  maxLines: 3,
                                  decoration: _inputDecoration(
                                    hintText: 'What is this circle about?',
                                    focusNode: _descriptionFocus,
                                    prefixIcon: Icons.notes_rounded,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                _label('Privacy'),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _PrivacyOption(
                                        selected: _isPrivate,
                                        icon: Icons.lock_outline_rounded,
                                        label: 'Private',
                                        onTap: () => setState(() => _isPrivate = true),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _PrivacyOption(
                                        selected: !_isPrivate,
                                        icon: Icons.public_rounded,
                                        label: 'Public',
                                        onTap: () => setState(() => _isPrivate = false),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: Text(
                                      _isPrivate
                                          ? 'Only people you invite can join'
                                          : 'Anyone with access can discover and join',
                                      key: ValueKey(_isPrivate),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: _CircleSheetStyle.muted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
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
                                  label: 'Create Circle',
                                  isSubmitting: _isSubmitting,
                                  onTap: _handleCreate,
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

class _CircleSheetStyle {
  static const Color background = Color(0xFFFBFCFF);
  static const Color primary = Color(0xFF6F63F6);
  static const Color secondary = Color(0xFFD96BEF);
  static const Color teal = Color(0xFF11C5B7);
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
          child: _Orb(size: 250, color: _CircleSheetStyle.primary.withOpacity(0.12)),
        ),
        Positioned(
          bottom: -120,
          left: -100,
          child: _Orb(size: 240, color: _CircleSheetStyle.secondary.withOpacity(0.10)),
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
        gradient: _CircleSheetStyle.primaryGradient,
        borderRadius: BorderRadius.circular(19),
        boxShadow: [
          BoxShadow(
            color: _CircleSheetStyle.secondary.withOpacity(0.28),
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
      color: _CircleSheetStyle.muted,
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
        boxShadow: _CircleSheetStyle.softShadow,
      ),
      child: child,
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PrivacyOption({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 58,
        decoration: BoxDecoration(
          gradient: selected ? _CircleSheetStyle.primaryGradient : null,
          color: selected ? null : Colors.white.withOpacity(0.84),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.transparent : const Color(0xFFE3E5EF),
            width: 1.6,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _CircleSheetStyle.secondary.withOpacity(0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : _CircleSheetStyle.muted,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : _CircleSheetStyle.muted,
              ),
            ),
          ],
        ),
      ),
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
            gradient: _CircleSheetStyle.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _CircleSheetStyle.secondary.withOpacity(0.26),
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
            color: _CircleSheetStyle.ink,
          ),
        ),
      ),
    );
  }
}

class _CircleMotif extends StatelessWidget {
  const _CircleMotif();

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
        width: 92,
        height: 68,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 8,
              child: _MiniCircle(color: _CircleSheetStyle.primary.withOpacity(0.22)),
            ),
            Positioned(
              right: 8,
              child: _MiniCircle(color: _CircleSheetStyle.secondary.withOpacity(0.22)),
            ),
            _MiniCircle(
              color: _CircleSheetStyle.primary.withOpacity(0.28),
              size: 38,
            ),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _CircleSheetStyle.primary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniCircle extends StatelessWidget {
  final Color color;
  final double size;

  const _MiniCircle({required this.color, this.size = 32});

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
