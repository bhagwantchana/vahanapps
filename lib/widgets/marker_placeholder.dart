import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Marker bitmap used until a vehicle's real icon finishes downloading.
///
/// Both maps used to fall back to `assets/images/map.png` — a green folded-map
/// illustration with a pin and an X on it — so on every cold start each vehicle
/// briefly appeared as a *picture of a map*. The server icons are 72-102 KB and
/// ship without cache headers, so that fallback was on screen for most of the
/// load on a school's connection.
///
/// This draws a directional chevron in the vehicle's status colour instead: it
/// reads as a vehicle heading somewhere, points the right way (markers rotate
/// with bearing), and needs no network and no asset.
Future<Uint8List> buildPlaceholderVehiclePng({
  required Color color,
  int sizePx = 128,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = sizePx.toDouble();
  final centre = Offset(size / 2, size / 2);

  // Disc so the shape stays readable against busy map tiles.
  canvas.drawCircle(
    centre,
    size * 0.40,
    Paint()..color = color,
  );
  canvas.drawCircle(
    centre,
    size * 0.40,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.055
      ..color = Colors.white,
  );

  // Chevron pointing "up" — the marker itself is rotated to the heading, so up
  // is always the direction of travel.
  final chevron = Path()
    ..moveTo(centre.dx, centre.dy - size * 0.20)
    ..lineTo(centre.dx + size * 0.155, centre.dy + size * 0.175)
    ..lineTo(centre.dx, centre.dy + size * 0.075)
    ..lineTo(centre.dx - size * 0.155, centre.dy + size * 0.175)
    ..close();
  canvas.drawPath(
    chevron,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill,
  );

  final image = await recorder.endRecording().toImage(sizePx, sizePx);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
