import 'dart:async';
import 'package:fleet_monitor/constant/app_theme.dart';
import 'package:fleet_monitor/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  static const String routeName = "splash_screen";
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _carController;
  late Animation<double> _carAnimation;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
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

    _carController.forward().then((_) {
      _pulseController.repeat(reverse: true);
      Timer(const Duration(seconds: 2), () {
        Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
      });
    });
  }

  @override
  void dispose() {
    _carController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background grid pattern placeholder
          Positioned.fill(child: CustomPaint(painter: GridPainter())),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo placeholder
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.map,
                      color: AppTheme.primaryBlue,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FleetMonitor360',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primaryBlue,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Global Fleet Intelligence',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.primaryGreen,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                // Animation Area
                SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([
                      _carController,
                      _pulseController,
                    ]),
                    builder: (context, child) {
                      final carX = _carAnimation.value * (w / 2 + 50);

                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // GPS tracking line behind car
                          Positioned(
                            left: 0,
                            right: w / 2 - carX,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primaryGreen.withOpacity(0.1),
                                    AppTheme.primaryGreen,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Car icon
                          Transform.translate(
                            offset: Offset(carX, 0),
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
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
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryBlue.withOpacity(
                                          0.2,
                                        ),
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
    var paint = Paint()
      ..color = Colors.grey.withOpacity(0.05)
      ..strokeWidth = 1.0;

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
