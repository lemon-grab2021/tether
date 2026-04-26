import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _bioController = TextEditingController();

  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  final _bioFocus = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  DateTime? _selectedDob;

  @override
  void initState() {
    super.initState();

    for (final node in [
      _firstNameFocus,
      _lastNameFocus,
      _usernameFocus,
      _emailFocus,
      _passwordFocus,
      _confirmPasswordFocus,
      _bioFocus,
    ]) {
      node.addListener(_handleFocusChange);
    }

    _bioController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _bioController.dispose();

    for (final node in [
      _firstNameFocus,
      _lastNameFocus,
      _usernameFocus,
      _emailFocus,
      _passwordFocus,
      _confirmPasswordFocus,
      _bioFocus,
    ]) {
      node
        ..removeListener(_handleFocusChange)
        ..dispose();
    }

    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _RegisterStyle.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  String _formatDob(DateTime? date) {
    if (date == null) return 'dd / mm / yyyy';
    return '${date.day.toString().padLeft(2, '0')} / ${date.month.toString().padLeft(2, '0')} / ${date.year}';
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required FocusNode focusNode,
    Widget? suffixIcon,
    IconData? prefixIcon,
  }) {
    final active = focusNode.hasFocus;

    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white.withOpacity(0.92),
      hintStyle: const TextStyle(
        color: Color(0xFF98A2B3),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(
              prefixIcon,
              color: active ? _RegisterStyle.primary : _RegisterStyle.muted,
            ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(
          color: Color(0xFFE3E5EF),
          width: 1.6,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(
          color: _RegisterStyle.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(
          color: Color(0xFFDC2626),
          width: 1.6,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(
          color: Color(0xFFDC2626),
          width: 2,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
      ),
    );
  }

  Widget _buildLabel(String text, FocusNode focusNode) {
    final active = focusNode.hasFocus;

    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 180),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: active ? _RegisterStyle.primary : _RegisterStyle.ink,
      ),
      child: Text(text),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your date of birth'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final displayName =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim();

    try {
      await authProvider.register(
        email: _emailController.text.trim(),
        username: _usernameController.text.trim(),
        displayName: displayName,
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Registration failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: _RegisterStyle.background,
      body: Stack(
        children: [
          const _RegisterBackground(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 520),
                          tween: Tween(begin: 0, end: 1),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 24 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                const SizedBox(height: 8),
                                const _RegisterBrandHeader(),
                                const SizedBox(height: 18),
                                const Text(
                                  'Create your account',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: _RegisterStyle.ink,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'Join Tether and start building meaningful connections with people who matter.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.45,
                                      color: _RegisterStyle.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 26),
                                _GlassCard(
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildLabel(
                                                  'First name',
                                                  _firstNameFocus,
                                                ),
                                                const SizedBox(height: 10),
                                                TextFormField(
                                                  controller:
                                                      _firstNameController,
                                                  focusNode: _firstNameFocus,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  decoration: _inputDecoration(
                                                    hintText: 'John',
                                                    focusNode: _firstNameFocus,
                                                  ),
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.trim().isEmpty) {
                                                      return 'Required';
                                                    }
                                                    if (value.trim().length <
                                                        2) {
                                                      return 'Too short';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildLabel(
                                                  'Last name',
                                                  _lastNameFocus,
                                                ),
                                                const SizedBox(height: 10),
                                                TextFormField(
                                                  controller:
                                                      _lastNameController,
                                                  focusNode: _lastNameFocus,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  decoration: _inputDecoration(
                                                    hintText: 'Doe',
                                                    focusNode: _lastNameFocus,
                                                  ),
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.trim().isEmpty) {
                                                      return 'Required';
                                                    }
                                                    if (value.trim().length <
                                                        2) {
                                                      return 'Too short';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildLabel(
                                          'Username',
                                          _usernameFocus,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _usernameController,
                                        focusNode: _usernameFocus,
                                        textInputAction: TextInputAction.next,
                                        decoration: _inputDecoration(
                                          hintText: 'johndoe',
                                          focusNode: _usernameFocus,
                                          prefixIcon:
                                              Icons.alternate_email_rounded,
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter a username';
                                          }
                                          if (value.trim().length < 3) {
                                            return 'Username must be at least 3 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildLabel('Email', _emailFocus),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _emailController,
                                        focusNode: _emailFocus,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        decoration: _inputDecoration(
                                          hintText: 'you@example.com',
                                          focusNode: _emailFocus,
                                          prefixIcon: Icons.email_outlined,
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter your email';
                                          }
                                          if (!value.contains('@')) {
                                            return 'Please enter a valid email';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildLabel(
                                          'Password',
                                          _passwordFocus,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _passwordController,
                                        focusNode: _passwordFocus,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.next,
                                        decoration: _inputDecoration(
                                          hintText: 'Create a strong password',
                                          focusNode: _passwordFocus,
                                          prefixIcon: Icons.lock_outline_rounded,
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                      .visibility_off_outlined,
                                              color: _RegisterStyle.muted,
                                            ),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter a password';
                                          }
                                          if (value.length < 8) {
                                            return 'Password must be at least 8 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildLabel(
                                          'Confirm password',
                                          _confirmPasswordFocus,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller:
                                            _confirmPasswordController,
                                        focusNode: _confirmPasswordFocus,
                                        obscureText: _obscureConfirmPassword,
                                        textInputAction: TextInputAction.next,
                                        decoration: _inputDecoration(
                                          hintText: 'Confirm your password',
                                          focusNode: _confirmPasswordFocus,
                                          prefixIcon:
                                              Icons.verified_user_outlined,
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _obscureConfirmPassword =
                                                    !_obscureConfirmPassword;
                                              });
                                            },
                                            icon: Icon(
                                              _obscureConfirmPassword
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                      .visibility_off_outlined,
                                              color: _RegisterStyle.muted,
                                            ),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please confirm your password';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 20),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Date of Birth',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: _selectedDob != null
                                                ? _RegisterStyle.primary
                                                : _RegisterStyle.ink,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      InkWell(
                                        borderRadius: BorderRadius.circular(22),
                                        onTap: _pickDateOfBirth,
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 180),
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 18,
                                            vertical: 18,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.92),
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            border: Border.all(
                                              color: _selectedDob != null
                                                  ? _RegisterStyle.primary
                                                      .withOpacity(0.60)
                                                  : const Color(0xFFE3E5EF),
                                              width: 1.6,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons
                                                    .calendar_today_outlined,
                                                size: 20,
                                                color: _selectedDob != null
                                                    ? _RegisterStyle.primary
                                                    : _RegisterStyle.muted,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  _formatDob(_selectedDob),
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color:
                                                        _selectedDob == null
                                                            ? const Color(
                                                                0xFF98A2B3,
                                                              )
                                                            : _RegisterStyle
                                                                .ink,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: RichText(
                                          text: const TextSpan(
                                            text: 'About you ',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: _RegisterStyle.ink,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: '(optional)',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  color: _RegisterStyle.muted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _bioController,
                                        focusNode: _bioFocus,
                                        maxLines: 4,
                                        maxLength: 200,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Tell us a little about yourself...',
                                          filled: true,
                                          fillColor:
                                              Colors.white.withOpacity(0.92),
                                          hintStyle: const TextStyle(
                                            color: Color(0xFF98A2B3),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.all(18),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE3E5EF),
                                              width: 1.6,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(22),
                                            borderSide: const BorderSide(
                                              color: _RegisterStyle.primary,
                                              width: 2,
                                            ),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(22),
                                          ),
                                          counterText:
                                              '${_bioController.text.length}/200',
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      _GradientActionButton(
                                        label: 'Create account',
                                        isLoading: authProvider.isLoading,
                                        onTap: _handleRegister,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Already have an account? ',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        color: _RegisterStyle.muted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.of(context).pop(),
                                      child: const Text(
                                        'Sign in',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w900,
                                          color: _RegisterStyle.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 26),
                                Column(
                                  children: const [
                                    _RegisterMiniConnectionDots(),
                                    SizedBox(height: 10),
                                    Text(
                                      'Your trusted circle awaits',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _RegisterStyle.muted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: _RegisterStyle.primaryGradient,
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

class _RegisterStyle {
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

  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: const Color(0xFFD96BEF).withOpacity(0.28),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];

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
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.70),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.86), width: 1.4),
        boxShadow: _RegisterStyle.cardShadow,
      ),
      child: child,
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _GradientActionButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isLoading ? 0.76 : 1,
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: _RegisterStyle.primaryGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: _RegisterStyle.glowShadow,
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Creating account...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

class _RegisterBackground extends StatelessWidget {
  const _RegisterBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _DottedBackground(),
        Positioned(
          top: -120,
          right: -120,
          child: _Orb(
            size: 320,
            color: _RegisterStyle.primary.withOpacity(0.12),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.45,
          left: -100,
          child: _Orb(
            size: 250,
            color: _RegisterStyle.secondary.withOpacity(0.11),
          ),
        ),
        Positioned(
          bottom: -160,
          right: -120,
          child: _Orb(
            size: 360,
            color: _RegisterStyle.primary.withOpacity(0.10),
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
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 900),
      tween: Tween(begin: 0.94, end: 1),
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

class _DottedBackground extends StatelessWidget {
  const _DottedBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.infinite, painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x08101828)
      ..strokeWidth = 1;

    const spacing = 24.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.75, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RegisterBrandHeader extends StatelessWidget {
  const _RegisterBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _RegisterTetherLogo(size: 54),
        SizedBox(height: 10),
        _GradientText(
          'Tether',
          style: TextStyle(
            fontSize: 31,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.9,
          ),
        ),
      ],
    );
  }
}

class _GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _GradientText(this.text, {required this.style});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => _RegisterStyle.primaryGradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style),
    );
  }
}

class _RegisterMiniConnectionDots extends StatelessWidget {
  const _RegisterMiniConnectionDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _miniDot(10),
        Transform.translate(offset: const Offset(-3, 0), child: _miniDot(12)),
        Transform.translate(offset: const Offset(-6, 0), child: _miniDot(10)),
      ],
    );
  }

  Widget _miniDot(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _RegisterStyle.primary.withOpacity(0.42),
          width: 1.4,
        ),
      ),
    );
  }
}

class _RegisterTetherLogo extends StatelessWidget {
  final double size;

  const _RegisterTetherLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _RegisterStyle.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.30),
        boxShadow: _RegisterStyle.glowShadow,
      ),
      child: CustomPaint(
        painter: _RegisterTetherLogoPainter(),
      ),
    );
  }
}

class _RegisterTetherLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.fill;

    final r = size.width * 0.20;
    final left = Offset(size.width * 0.38, size.height * 0.50);
    final right = Offset(size.width * 0.62, size.height * 0.50);

    canvas.drawCircle(left, r, strokePaint);
    canvas.drawCircle(right, r, strokePaint);

    final path = Path()
      ..moveTo(size.width * 0.50, size.height * 0.32)
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.50,
        size.width * 0.50,
        size.height * 0.68,
      )
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.50,
        size.width * 0.50,
        size.height * 0.32,
      );

    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
