import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_cubit.dart';
import 'package:fleet_monitor/cubits/auth_cubit/auth_state.dart';
import 'package:fleet_monitor/cubits/profile_cubit/profile_cubit.dart';
import 'package:fleet_monitor/gen/assets.gen.dart';
import 'package:fleet_monitor/providers/login_provider.dart';
import 'package:fleet_monitor/screens/dashboard.dart';
import 'package:fleet_monitor/services/biometric_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

enum TimePeriod { morning, afternoon, evening, night }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const String routeName = 'login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _showBiometricButton = false;
  late TimePeriod _currentTimePeriod;
  late AnimationController _appearanceController;
  late Animation<double> _logoAnimation;
  late Animation<double> _greetingAnimation;
  late Animation<double> _formAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _currentTimePeriod = _getTimePeriod();
    _appearanceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _logoAnimation = CurvedAnimation(
      parent: _appearanceController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _greetingAnimation = CurvedAnimation(
      parent: _appearanceController,
      curve: const Interval(0.2, 0.6, curve: Curves.easeOut),
    );
    _formAnimation = CurvedAnimation(
      parent: _appearanceController,
      curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _appearanceController,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOutBack),
          ),
        );

    _prepareBiometricState();
    _appearanceController.forward();
  }

  @override
  void dispose() {
    _appearanceController.dispose();
    super.dispose();
  }

  TimePeriod _getTimePeriod() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return TimePeriod.morning;
    if (hour >= 12 && hour < 17) return TimePeriod.afternoon;
    if (hour >= 17 && hour < 20) return TimePeriod.evening;
    return TimePeriod.night;
  }

  String _getGreeting() {
    switch (_currentTimePeriod) {
      case TimePeriod.morning:
        return 'Good Morning';
      case TimePeriod.afternoon:
        return 'Good Afternoon';
      case TimePeriod.evening:
        return 'Good Evening';
      case TimePeriod.night:
        return 'Ready for the night shift?';
    }
  }

  List<Color> _getBackgroundColors() {
    switch (_currentTimePeriod) {
      case TimePeriod.morning:
        return [const Color(0xFFFFB75E), const Color(0xFFED8F03)];
      case TimePeriod.afternoon:
        return [const Color(0xFF2193b0), const Color(0xFF6dd5ed)];
      case TimePeriod.evening:
        return [const Color(0xFFe96443), const Color(0xFF904e95)];
      case TimePeriod.night:
        return [
          const Color(0xFF0F2027),
          const Color(0xFF203A43),
          const Color(0xFF2C5364),
        ];
    }
  }

  Future<void> _prepareBiometricState() async {
    final token = await LocalStorage.readValue(PreferencesKey.token) ?? '';
    final enabled = await BiometricAuthService.isEnabled();
    final supported = await BiometricAuthService.isSupported();
    if (!mounted) {
      return;
    }
    setState(() {
      _showBiometricButton = token.trim().isNotEmpty && enabled && supported;
    });
  }

  Future<void> _promptBiometricEnrollment() async {
    final alreadyEnabled = await BiometricAuthService.isEnabled();
    if (alreadyEnabled) {
      setState(() => _showBiometricButton = true);
      return;
    }

    final supported = await BiometricAuthService.isSupported();
    if (!mounted || !supported) {
      return;
    }

    final enable = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enable biometric login?'),
          content: const Text(
            'Use your phone\'s Face ID / fingerprint to unlock Fleet Monitor next time.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );

    if (enable != true || !mounted) {
      return;
    }

    final authenticated = await BiometricAuthService.authenticate(
      reason: 'Confirm your identity to enable biometric login',
    );
    if (!mounted) {
      return;
    }

    if (authenticated) {
      await BiometricAuthService.setEnabled(true);
      setState(() => _showBiometricButton = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Biometric login enabled')));
    }
  }

  Future<void> _unlockWithBiometrics() async {
    final authenticated = await BiometricAuthService.authenticate(
      reason: 'Unlock Fleet Monitor with system biometrics',
    );
    if (!mounted || !authenticated) {
      return;
    }

    await context.read<ProfileCubit>().fetchProfile();
    if (!mounted) {
      return;
    }
    Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.pushReplacementNamed(context, DashboardScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LoginProvider>(context);

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) async {
        if (state is AuthLoggedInState) {
          await _promptBiometricEnrollment();
          await context.read<ProfileCubit>().fetchProfile();
          if (!context.mounted) {
            return;
          }
          Navigator.popUntil(context, (route) => route.isFirst);
          Navigator.pushReplacementNamed(context, DashboardScreen.routeName);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Dynamic Background Gradient
            AnimatedContainer(
              duration: const Duration(seconds: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _getBackgroundColors(),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            // Atmospheric Effects (Stars or Clouds)
            Positioned.fill(
              child: _currentTimePeriod == TimePeriod.night
                  ? const _StarField()
                  : const _CloudField(),
            ),

            // Main Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = constraints.maxWidth > 420
                          ? 420.0
                          : constraints.maxWidth;

                      return SizedBox(
                        width: cardWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            FadeTransition(
                              opacity: _logoAnimation,
                              child: Hero(
                                tag: 'app_logo',
                                child: Image.asset(
                                  Assets.images.mylogo.path,
                                  height: 80,
                                  width: 80,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            FadeTransition(
                              opacity: _greetingAnimation,
                              child: Column(
                                children: [
                                  Text(
                                    _getGreeting(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Stay connected to every vehicle',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 36),
                            FadeTransition(
                              opacity: _formAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Form(
                                  key: provider.formKey,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(28),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 12,
                                        sigmaY: 12,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(28),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.18,
                                            ),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: <Widget>[
                                            TextFormField(
                                              controller:
                                                  provider.emailController,
                                              validator: provider.validateEmail,
                                              textInputAction:
                                                  TextInputAction.next,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                              decoration: InputDecoration(
                                                labelText: 'Username or Email',
                                                labelStyle: const TextStyle(
                                                  color: Colors.white70,
                                                ),
                                                filled: true,
                                                fillColor: Colors.white
                                                    .withOpacity(0.1),
                                                prefixIcon: const Icon(
                                                  LucideIcons.user,
                                                  color: Colors.white70,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: BorderSide.none,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                            TextFormField(
                                              controller:
                                                  provider.passwordController,
                                              validator:
                                                  provider.validatePassword,
                                              obscureText: true,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                              decoration: InputDecoration(
                                                labelText: 'Password',
                                                labelStyle: const TextStyle(
                                                  color: Colors.white70,
                                                ),
                                                filled: true,
                                                fillColor: Colors.white
                                                    .withOpacity(0.1),
                                                prefixIcon: const Icon(
                                                  LucideIcons.lock,
                                                  color: Colors.white70,
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: BorderSide.none,
                                                ),
                                              ),
                                            ),
                                            if (provider
                                                .error
                                                .isNotEmpty) ...<Widget>[
                                              const SizedBox(height: 16),
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.red
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: AppColors.red
                                                        .withOpacity(0.5),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: <Widget>[
                                                    const Icon(
                                                      Icons.error_outline,
                                                      color: Colors.white,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        provider.error,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 28),
                                            _AnimatedLoginButton(
                                              onPressed: provider.isLoading
                                                  ? null
                                                  : provider.logIn,
                                              isLoading: provider.isLoading,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_showBiometricButton) ...<Widget>[
                              const SizedBox(height: 24),
                              Center(
                                child: InkWell(
                                  onTap: _unlockWithBiometrics,
                                  borderRadius: BorderRadius.circular(30),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Icon(
                                          LucideIcons.scanLine,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Unlock with Biometrics',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedLoginButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const _AnimatedLoginButton({this.onPressed, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          colors: onPressed == null
              ? [Colors.grey, Colors.grey.shade700]
              : [const Color(0xFF7BC043), const Color(0xFF67A836)],
        ),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'SIGN IN',
                    style: TextStyle(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(LucideIcons.arrowRight, size: 18, color: Colors.white),
                ],
              ),
      ),
    );
  }
}

class _StarField extends StatefulWidget {
  const _StarField();

  @override
  State<_StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<_StarField>
    with SingleTickerProviderStateMixin {
  late List<_Star> stars;
  _ShootingStar? shootingStar;
  late AnimationController _controller;
  final math.Random random = math.Random();

  @override
  void initState() {
    super.initState();
    stars = List.generate(120, (i) {
      return _Star(
        offset: math.Point(random.nextDouble(), random.nextDouble()),
        size: random.nextDouble() * 1.5 + 0.5,
        velocity: random.nextDouble() * 0.05 + 0.01,
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _controller.addListener(_updateShootingStar);
  }

  void _updateShootingStar() {
    if (shootingStar == null && random.nextDouble() < 0.005) {
      setState(() {
        shootingStar = _ShootingStar(
          start: math.Point(
            random.nextDouble() * 0.8,
            random.nextDouble() * 0.4,
          ),
          angle: random.nextDouble() * math.pi / 4 + math.pi / 8,
          length: 0.2 + random.nextDouble() * 0.3,
        );
      });
    }

    if (shootingStar != null) {
      setState(() {
        shootingStar!.progress += 0.02;
        if (shootingStar!.progress > 1.0) {
          shootingStar = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _StarPainter(stars, shootingStar, _controller.value),
        );
      },
    );
  }
}

class _Star {
  final math.Point<double> offset;
  final double size;
  final double velocity;

  _Star({required this.offset, required this.size, required this.velocity});
}

class _ShootingStar {
  final math.Point<double> start;
  final double angle;
  final double length;
  double progress = 0.0;

  _ShootingStar({
    required this.start,
    required this.angle,
    required this.length,
  });
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final _ShootingStar? shootingStar;
  final double animationValue;

  _StarPainter(this.stars, this.shootingStar, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    // Background Stars with Parallax
    for (var star in stars) {
      final x =
          (star.offset.x * size.width +
              animationValue * star.velocity * size.width) %
          size.width;
      final y = star.offset.y * size.height;

      final opacity =
          (math.sin(animationValue * 5 * math.pi + star.offset.x * 20) + 1) / 2;
      final paint = Paint()..color = Colors.white.withOpacity(opacity * 0.7);

      canvas.drawCircle(Offset(x, y), star.size, paint);
    }

    // Shooting Star
    if (shootingStar != null) {
      final startX = shootingStar!.start.x * size.width;
      final startY = shootingStar!.start.y * size.height;
      final endX =
          startX +
          math.cos(shootingStar!.angle) *
              shootingStar!.length *
              size.width *
              shootingStar!.progress;
      final endY =
          startY +
          math.sin(shootingStar!.angle) *
              shootingStar!.length *
              size.height *
              shootingStar!.progress;

      final paint = Paint()
        ..shader =
            LinearGradient(
              colors: [Colors.white.withOpacity(0.0), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(
              Rect.fromPoints(Offset(startX, startY), Offset(endX, endY)),
            )
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(
          startX + (endX - startX) * math.max(0, shootingStar!.progress - 0.2),
          startY + (endY - startY) * math.max(0, shootingStar!.progress - 0.2),
        ),
        Offset(endX, endY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CloudField extends StatefulWidget {
  const _CloudField();

  @override
  State<_CloudField> createState() => _CloudFieldState();
}

class _CloudFieldState extends State<_CloudField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(painter: _CloudPainter(_controller.value));
      },
    );
  }
}

class _CloudPainter extends CustomPainter {
  final double animationValue;

  _CloudPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    void drawSoftCloud(double x, double y, double scale, double opacity) {
      final paint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withOpacity(opacity),
                Colors.white.withOpacity(0.0),
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(x, y), radius: 60 * scale),
            );

      canvas.drawCircle(Offset(x, y), 60 * scale, paint);
      canvas.drawCircle(
        Offset(x + 40 * scale, y + 10 * scale),
        45 * scale,
        paint,
      );
      canvas.drawCircle(
        Offset(x - 40 * scale, y + 10 * scale),
        45 * scale,
        paint,
      );
    }

    // Layer 1 (Far, Slower, Smaller)
    final xPosFar =
        (animationValue * size.width * 0.8) % (size.width + 400) - 200;
    drawSoftCloud(xPosFar, size.height * 0.15, 0.7, 0.15);
    drawSoftCloud(
      (xPosFar + size.width * 0.6) % (size.width + 400) - 200,
      size.height * 0.35,
      0.5,
      0.1,
    );

    // Layer 2 (Near, Faster, Larger)
    final xPosNear =
        (animationValue * size.width * 1.5) % (size.width + 400) - 200;
    drawSoftCloud(xPosNear, size.height * 0.25, 1.2, 0.25);
    drawSoftCloud(
      (xPosNear + size.width * 0.7) % (size.width + 400) - 200,
      size.height * 0.45,
      0.9,
      0.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
