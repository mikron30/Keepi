// ignore_for_file: prefer_interpolation_to_compose_strings

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

final _background = img.ColorRgb8(7, 17, 29);

img.Image _loadSource() {
  final file = File('assets/images/keepi_icon_clean.webp.b64');
  if (!file.existsSync()) {
    throw StateError('Missing assets/images/keepi_icon_clean.webp.b64');
  }

  final encoded = file.readAsStringSync().replaceAll(RegExp(r'\s+'), '');
  final decoded = img.decodeImage(base64Decode(encoded));
  if (decoded == null) {
    throw StateError('Could not decode the clean Keepi icon source.');
  }
  return decoded;
}

img.Image _render(img.Image source, int size, {double inset = 0.06}) {
  final canvas = img.Image(width: size, height: size, numChannels: 3);
  img.fill(canvas, color: _background);

  final inner = (size * (1 - (2 * inset))).round();
  final resized = img.copyResize(
    source,
    width: inner,
    height: inner,
    interpolation: img.Interpolation.cubic,
  );

  final offset = ((size - inner) / 2).round();
  img.compositeImage(canvas, resized, dstX: offset, dstY: offset);
  return canvas;
}

void _writePng(img.Image source, int size, String path, {double inset = 0.06}) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(_render(source, size, inset: inset)));

  final check = img.decodePng(file.readAsBytesSync());
  if (check == null || check.width != size || check.height != size) {
    throw StateError('Generated invalid icon: ' + path);
  }
}

void main() {
  final source = _loadSource();

  // Replace the old/corrupt Flutter runtime asset only in the native build workspace.
  _writePng(source, 512, 'assets/images/keepi_icon.png', inset: 0.0);

  const android = <String, int>{
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };

  for (final entry in android.entries) {
    _writePng(source, entry.value, entry.key, inset: 0.0);
  }

  // Android 8+ adaptive launcher layer sizes. Use the approved Keepi artwork
  // as the full background layer so Android does not place the legacy icon
  // inside an extra white/gray plate.
  const androidAdaptive = <String, int>{
    'android/app/src/main/res/mipmap-mdpi/ic_launcher_full.png': 108,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher_full.png': 162,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher_full.png': 216,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher_full.png': 324,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_full.png': 432,
  };

  for (final entry in androidAdaptive.entries) {
    _writePng(source, entry.value, entry.key, inset: 0.0);
  }

  const ios = <String, int>{
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

  const iosDir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  for (final entry in ios.entries) {
    _writePng(source, entry.value, iosDir + '/' + entry.key, inset: 0.0);
  }

  stdout.writeln('Generated Keepi Android and iOS launcher icons.');
}
