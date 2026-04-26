import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../app_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(_handleFocusChange);
    _passwordFocus.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailFocus
      ..removeListener(_handleFocusChange)
      ..dispose();
    _passwordFocus
      ..removeListener(_handleFocusChange)
      ..dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();

    try {
      await authProvider.login(
        usernameOrEmail: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AppShell()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required FocusNode focusNode,
    Widget? suffixIcon,
    IconData? prefixIcon,
  }) {
    final isFocused = focusNode.hasFocus;

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
              color: isFocused
                  ? _LoginStyle.primary
                  : const Color(0xFF667085),
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
          color: _LoginStyle.primary,
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
        color: active ? _LoginStyle.primary : _LoginStyle.ink,
      ),
      child: Text(text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: _LoginStyle.background,
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 24,
                      ),
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
                                const _BrandHeader(),
                                const SizedBox(height: 22),
                                const _ConnectionIllustration(),
                                const SizedBox(height: 22),
                                const Text(
                                  'Welcome back',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    color: _LoginStyle.ink,
                                    letterSpacing: -0.7,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'Reconnect with your trusted circles and the people who matter most.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.45,
                                      color: _LoginStyle.muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                _GlassCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel(
                                        'Email or username',
                                        _emailFocus,
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _usernameController,
                                        focusNode: _emailFocus,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        decoration: _inputDecoration(
                                          hintText: 'you@example.com',
                                          focusNode: _emailFocus,
                                          prefixIcon:
                                              Icons.alternate_email_rounded,
                                        ),
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter your email or username';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 22),
                                      _buildLabel('Password', _passwordFocus),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _passwordController,
                                        focusNode: _passwordFocus,
                                        obscureText: _obscurePassword,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) {
                                          if (!authProvider.isLoading) {
                                            _handleLogin();
                                          }
                                        },
                                        decoration: _inputDecoration(
                                          hintText: 'Enter your password',
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
                                              color: const Color(0xFF667085),
                                            ),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter your password';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Forgot password coming soon',
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Forgot password?',
                                            style: TextStyle(
                                              color: _LoginStyle.primary,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _GradientActionButton(
                                        label: 'Sign in',
                                        loadingLabel: 'Signing in...',
                                        isLoading: authProvider.isLoading,
                                        onTap: _handleLogin,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: const [
                                    Expanded(
                                      child: Divider(
                                        color: Color(0xFFE4E7EC),
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 14),
                                      child: Text(
                                        'New to Tether?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF98A2B3),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Color(0xFFE4E7EC),
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                SizedBox(
                                  width: double.infinity,
                                  height: 58,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const RegisterScreen(),
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _LoginStyle.ink,
                                      backgroundColor:
                                          Colors.white.withOpacity(0.92),
                                      side: const BorderSide(
                                        color: Color(0xFFE3E5EF),
                                        width: 1.6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                    ),
                                    child: const Text(
                                      'Create an account',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 30),
                                Column(
                                  children: const [
                                    _MiniConnectionDots(),
                                    SizedBox(height: 12),
                                    Text(
                                      'Private conversations with the people who matter.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.45,
                                        color: _LoginStyle.muted,
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
                    gradient: _LoginStyle.primaryGradient,
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

class _LoginStyle {
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
        boxShadow: _LoginStyle.cardShadow,
      ),
      child: child,
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  final String label;
  final String loadingLabel;
  final bool isLoading;
  final VoidCallback onTap;

  const _GradientActionButton({
    required this.label,
    required this.loadingLabel,
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
            gradient: _LoginStyle.primaryGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: _LoginStyle.glowShadow,
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
                      'Signing in...',
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

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _TetherLogo(size: 58),
        SizedBox(height: 10),
        _GradientText(
          'Tether',
          style: TextStyle(
            fontSize: 34,
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
      shaderCallback: (bounds) => _LoginStyle.primaryGradient.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      blendMode: BlendMode.srcIn,
      child: Text(text, style: style),
    );
  }
}

class _ConnectionIllustration extends StatelessWidget {
  const _ConnectionIllustration();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 900),
      tween: Tween(begin: 0.90, end: 1),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: SizedBox(
        width: 190,
        height: 95,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 24,
              child: _RingCircle(
                size: 64,
                color: _LoginStyle.primary.withOpacity(0.24),
              ),
            ),
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _LoginStyle.secondary.withOpacity(0.26),
                    _LoginStyle.primary.withOpacity(0.16),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: _LoginStyle.primary.withOpacity(0.22),
                  width: 2,
                ),
              ),
            ),
            Positioned(
              right: 24,
              child: _RingCircle(
                size: 64,
                color: _LoginStyle.secondary.withOpacity(0.22),
              ),
            ),
            const Positioned(
              left: 36,
              top: 14,
              child: _FloatingDot(size: 8, color: _LoginStyle.primary),
            ),
            const Positioned(
              right: 43,
              bottom: 15,
              child: _FloatingDot(size: 7, color: _LoginStyle.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _RingCircle({required this.size, required this.color});

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

class _FloatingDot extends StatelessWidget {
  final double size;
  final Color color;

  const _FloatingDot({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1100),
      tween: Tween(begin: 0.78, end: 1),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.32),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _MiniConnectionDots extends StatelessWidget {
  const _MiniConnectionDots();

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
          color: _LoginStyle.primary.withOpacity(0.42),
          width: 1.4,
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

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
            color: _LoginStyle.primary.withOpacity(0.12),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.30,
          left: -95,
          child: _Orb(
            size: 230,
            color: _LoginStyle.secondary.withOpacity(0.11),
          ),
        ),
        Positioned(
          bottom: -150,
          right: -115,
          child: _Orb(
            size: 355,
            color: _LoginStyle.primary.withOpacity(0.10),
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

class _TetherLogo extends StatelessWidget {
  final double size;

  const _TetherLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: _LoginStyle.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.30),
        boxShadow: _LoginStyle.glowShadow,
      ),
      child: CustomPaint(painter: _TetherLogoPainter()),
    );
  }
}

class _TetherLogoPainter extends CustomPainter {
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
