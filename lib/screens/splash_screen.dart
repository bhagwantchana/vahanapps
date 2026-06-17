import 'dart:async';

import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/constant/functions.dart';
import 'package:fleet_monitor/constant/preferences.dart';
import 'package:fleet_monitor/constant/preferences_key.dart';
import 'package:fleet_monitor/gen/assets.gen.dart';
import 'package:fleet_monitor/screens/dashboard.dart';
import 'package:fleet_monitor/screens/login_screen.dart';
import 'package:fleet_monitor/services/biometric_auth_service.dart';
import 'package:fleet_monitor/services/force_update_service.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const String routeName = 'splash_screen';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _carController;
  late final Animation<double> _carAnimation;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _bootstrap();

    _carController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _carAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _carController, curve: Curves.easeOutCubic),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _carController.forward().then(
      (_) => _pulseController.repeat(reverse: true),
    );
  }

  Future<void> _bootstrap() async {
    // Check Play Store for a mandatory update before anything else.
    // If an update is found, a full-screen blocking UI appears and
    // the app restarts automatically after install.
    await ForceUpdateService.checkAndForceUpdate();

    await Functions.getDeviceTokenToSendNotification();
    await Future<void>.delayed(const Duration(seconds: 3));

    final isLogin = await LocalStorage.readValue(PreferencesKey.isLogin);
    final token = await LocalStorage.readValue(PreferencesKey.token);
    final biometricEnabled = await BiometricAuthService.isEnabled();
    if (!mounted) {
      return;
    }

    final hasSession =
        isLogin == 'islogin' && token != null && token.isNotEmpty;

    if (hasSession && biometricEnabled) {
      final authenticated = await BiometricAuthService.authenticate(
        reason: 'Use system biometrics to unlock VahanConnect',
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(
        authenticated ? DashboardScreen.routeName : LoginScreen.routeName,
      );
      return;
    }

    Navigator.of(context).pushReplacementNamed(
      hasSession ? DashboardScreen.routeName : LoginScreen.routeName,
    );
  }

  @override
  void dispose() {
    _carController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: CustomPaint(painter: GridPainter())),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset(Assets.images.logo.path, height: 48),
                const SizedBox(height: 60),
                SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: Listenable.merge(<Listenable>[
                      _carController,
                      _pulseController,
                    ]),
                    builder: (context, child) {
                      final carX = _carAnimation.value * (width / 2 + 50);
                      return Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Positioned(
                            left: 0,
                            right: width / 2 - carX,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    AppTheme.primaryGreen.withValues(alpha: 0.1),
                                    AppTheme.primaryGreen,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(carX, 0),
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                if (_carAnimation.isCompleted)
                                  Positioned(
                                    top: -30,
                                    child: Transform.scale(
                                      scale:
                                          0.8 + (_pulseAnimation.value * 0.4),
                                      child: Opacity(
                                        opacity:
                                            1.0 - (_pulseAnimation.value * 0.5),
                                        child: Icon(
                                          LucideIcons.radio,
                                          color: AppTheme.primaryBlue,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    LucideIcons.car,
                                    color: AppTheme.primaryBlue,
                                    size: 36,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
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

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
