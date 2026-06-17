import 'package:fleet_monitor/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// AppBar / drawer brand mark. The PNG logo is a single light-mode asset,
/// so in dark mode we wrap it in a small white pill — that way the logo
/// keeps its colours and stays legible against a dark AppBar instead of
/// blending into the surface.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 32});

  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logo = Image.asset(Assets.images.logo.path, height: height);
    if (!isDark) return logo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: logo,
    );
  }
}
