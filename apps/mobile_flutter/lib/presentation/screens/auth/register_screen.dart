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
              primary: Color(0xFF1274E7),
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
  }) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 16,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: Color(0xFFD7E3F0),
          width: 2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: Color(0xFF1274E7),
          width: 2,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildLabel(String text, FocusNode focusNode) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: focusNode.hasFocus
            ? const Color(0xFF1274E7)
            : const Color(0xFF0F172A),
      ),
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
      backgroundColor: const Color(0xFFF8FBFF),
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
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.5,
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
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 28),

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
                                          controller: _firstNameController,
                                          focusNode: _firstNameFocus,
                                          textInputAction: TextInputAction.next,
                                          decoration: _inputDecoration(
                                            hintText: 'John',
                                            focusNode: _firstNameFocus,
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Required';
                                            }
                                            if (value.trim().length < 2) {
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
                                          controller: _lastNameController,
                                          focusNode: _lastNameFocus,
                                          textInputAction: TextInputAction.next,
                                          decoration: _inputDecoration(
                                            hintText: 'Doe',
                                            focusNode: _lastNameFocus,
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Required';
                                            }
                                            if (value.trim().length < 2) {
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
                                child: _buildLabel('Username', _usernameFocus),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _usernameController,
                                focusNode: _usernameFocus,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  hintText: 'johndoe',
                                  focusNode: _usernameFocus,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
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
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  hintText: 'you@example.com',
                                  focusNode: _emailFocus,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
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
                                child: _buildLabel('Password', _passwordFocus),
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
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: const Color(0xFF64748B),
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
                                controller: _confirmPasswordController,
                                focusNode: _confirmPasswordFocus,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.next,
                                decoration: _inputDecoration(
                                  hintText: 'Confirm your password',
                                  focusNode: _confirmPasswordFocus,
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
                                          : Icons.visibility_off_outlined,
                                      color: const Color(0xFF64748B),
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
                                    fontWeight: FontWeight.w700,
                                    color: _selectedDob != null
                                        ? const Color(0xFF1274E7)
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _pickDateOfBirth,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 18,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFFD7E3F0),
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _formatDob(_selectedDob),
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: _selectedDob == null
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.calendar_today_outlined,
                                        size: 20,
                                        color: Color(0xFF64748B),
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
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '(optional)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xFF64748B),
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
                                  fillColor: Colors.white,
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF94A3B8),
                                  ),
                                  contentPadding: const EdgeInsets.all(18),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFD7E3F0),
                                      width: 2,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1274E7),
                                      width: 2,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  counterText: '${_bioController.text.length}/200',
                                ),
                              ),

                              const SizedBox(height: 10),

                              SizedBox(
                                width: double.infinity,
                                height: 58,
                                child: ElevatedButton(
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1274E7),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        const Color(0xFF1274E7).withOpacity(0.5),
                                    elevation: 8,
                                    shadowColor:
                                        const Color(0xFF1274E7).withOpacity(0.25),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: authProvider.isLoading
                                      ? Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: const [
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
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Text(
                                          'Create account',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
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
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: const Text(
                                      'Sign in',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1274E7),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 26),

                              Column(
                                children: [
                                  const _RegisterMiniConnectionDots(),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Your trusted circle awaits',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blueGrey.shade500,
                                      fontWeight: FontWeight.w500,
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
                Container(
                  height: 3,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Color(0x551274E7),
                        Colors.transparent,
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

class _RegisterBackground extends StatelessWidget {
  const _RegisterBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120,
          right: -120,
          child: Container(
            width: 320,
            height: 320,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x141274E7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.45,
          left: -90,
          child: Container(
            width: 240,
            height: 240,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x0F38BDF8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -160,
          right: -120,
          child: Container(
            width: 360,
            height: 360,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color(0x101274E7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RegisterBrandHeader extends StatelessWidget {
  const _RegisterBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _RegisterTetherLogo(size: 52),
        SizedBox(height: 10),
        Text(
          'Tether',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -0.8,
          ),
        ),
      ],
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
        Transform.translate(
          offset: const Offset(-3, 0),
          child: _miniDot(12),
        ),
        Transform.translate(
          offset: const Offset(-6, 0),
          child: _miniDot(10),
        ),
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
          color: const Color(0x551274E7),
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
    return SizedBox(
      width: size,
      height: size,
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
      ..color = const Color(0xFF1274E7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055;

    final fillPaint = Paint()
      ..color = const Color(0xFF1274E7).withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final r = size.width * 0.23;
    final left = Offset(size.width * 0.37, size.height * 0.5);
    final right = Offset(size.width * 0.63, size.height * 0.5);

    canvas.drawCircle(left, r, strokePaint);
    canvas.drawCircle(right, r, strokePaint);

    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.5,
        size.width * 0.5,
        size.height * 0.72,
      )
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.5,
        size.width * 0.5,
        size.height * 0.28,
      );

    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}