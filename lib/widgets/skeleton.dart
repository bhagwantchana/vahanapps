import 'package:flutter/material.dart';

/// Shimmering placeholder block used while data is loading. Replaces the
/// generic `CircularProgressIndicator()` with a layout-aware skeleton that
/// hints at the shape of the content that's about to appear — feels much
/// more premium on slow networks and stops the screen from "jumping" when
/// real data lands.
///
/// Zero dependencies — uses an `AnimationController` to slide a soft
/// highlight across a fixed-size container, so we don't have to pull in
/// the `shimmer` package just for this.
class SkeletonBlock extends StatefulWidget {
  const SkeletonBlock({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = 8,
    this.baseColor,
    this.highlightColor,
  });

  final double width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? const Color(0xFFEDF0F4);
    final highlight = widget.highlightColor ?? const Color(0xFFF8F9FB);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment(-1.0 + (2.0 * t), 0),
                  end: Alignment(1.0 + (2.0 * t), 0),
                  colors: <Color>[base, highlight, base],
                  stops: const <double>[0.35, 0.5, 0.65],
                ).createShader(rect);
              },
              child: Container(color: base),
            ),
          ),
        );
      },
    );
  }
}

/// Pre-built skeleton card matching the vehicle-list row layout (icon
/// circle + 2 text lines + status badge). Shown while `VehicleCubit` is
/// still loading the first page of results.
class SkeletonVehicleRow extends StatelessWidget {
  const SkeletonVehicleRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDF0F4)),
      ),
      child: Row(
        children: const <Widget>[
          SkeletonBlock(width: 44, height: 44, borderRadius: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBlock(width: 160, height: 13),
                SizedBox(height: 8),
                SkeletonBlock(width: 110, height: 11),
                SizedBox(height: 6),
                SkeletonBlock(width: 200, height: 10),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonBlock(width: 56, height: 22, borderRadius: 11),
        ],
      ),
    );
  }
}

/// Compact skeleton for dashboard summary cards (KPI tiles). Use a Wrap
/// of 4 of these to mimic the standard fleet-stats row.
class SkeletonStatTile extends StatelessWidget {
  const SkeletonStatTile({super.key, this.width = 120, this.height = 88});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDF0F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const <Widget>[
          SkeletonBlock(width: 28, height: 28, borderRadius: 14),
          SkeletonBlock(width: 80, height: 18),
          SkeletonBlock(width: 50, height: 11),
        ],
      ),
    );
  }
}
