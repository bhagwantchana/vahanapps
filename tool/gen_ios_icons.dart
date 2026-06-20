// One-off generator: rebuilds the iOS AppIcon set from the real VahanConnect
// logo (the 512x512 Play Store icon) so iOS stops showing the default Flutter
// icon. iOS app icons must NOT have an alpha channel, so each size is flattened
// onto a white background. Run from the fleet_monitor/ root:
//   dart run tool/gen_ios_icons.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  const srcPath = 'android/app/src/main/ic_launcher-playstore.png';
  const outDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

  final bytes = File(srcPath).readAsBytesSync();
  final src = img.decodePng(bytes);
  if (src == null) {
    stderr.writeln('ERROR: could not decode $srcPath');
    exit(1);
  }

  // filename -> pixel size (matches the existing Contents.json entries)
  const icons = <String, int>{
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };

  icons.forEach((name, size) {
    final resized = img.copyResize(
      src,
      width: size,
      height: size,
      interpolation: img.Interpolation.cubic,
    );
    // Flatten onto white (drop the alpha channel for iOS).
    final out = img.Image(width: size, height: size, numChannels: 3);
    img.fill(out, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(out, resized);
    File('$outDir/$name').writeAsBytesSync(img.encodePng(out));
    stdout.writeln('wrote $name (${size}x$size)');
  });

  stdout.writeln('done — ${icons.length} iOS icons regenerated');
}
