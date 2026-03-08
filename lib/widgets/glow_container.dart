import 'package:flutter/material.dart';

class GlowContainer extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const GlowContainer({
    super.key,
    required this.child,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🔹 Outer soft glow
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.12),
                  blurRadius: 28,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.blue.withOpacity(0.18),
                  blurRadius: 60,
                  spreadRadius: -12,
                ),
              ],
            ),
          ),
        ),

        // 🔹 Subtle gradient edge highlight
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.25),
                  Colors.transparent,
                  Colors.blue.withOpacity(0.25),
                ],
              ),
            ),
          ),
        ),

        // 🔹 Actual card
        child,
      ],
    );
  }
}
