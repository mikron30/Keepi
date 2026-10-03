// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final sourceFile = File('assets/images/keepi_icon_clean.webp.b64');
  if (!sourceFile.existsSync()) {
    throw StateError('Missing Keepi icon source.');
  }

  final bytes = base64Decode(
    sourceFile.readAsStringSync().replaceAll(RegExp(r'\s+'), ''),
  );
  final source = img.decodeImage(bytes);
  if (source == null) {
    throw StateError('Could not decode Keepi icon.');
  }

  final outDir = Directory('release/google_play/assets')
    ..createSync(recursive: true);

  final appIcon = img.copyResize(
    source,
    width: 512,
    height: 512,
    interpolation: img.Interpolation.cubic,
  );
  File('${outDir.path}/app_icon_512.png')
      .writeAsBytesSync(img.encodePng(appIcon));

  final feature = img.Image(width: 1024, height: 500, numChannels: 3);
  img.fill(feature, color: img.ColorRgb8(7, 17, 29));

  // Warm brand accents.
  img.fillRect(
    feature,
    x1: 0,
    y1: 0,
    x2: 26,
    y2: 499,
    color: img.ColorRgb8(255, 99, 77),
  );
  img.fillRect(
    feature,
    x1: 38,
    y1: 0,
    x2: 48,
    y2: 499,
    color: img.ColorRgb8(255, 171, 74),
  );

  final hero = img.copyResize(
    source,
    width: 390,
    height: 390,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(feature, hero, dstX: 560, dstY: 55);

  // Simple branded geometry on the text side; no fabricated app screenshots.
  img.fillRect(
    feature,
    x1: 110,
    y1: 150,
    x2: 460,
    y2: 178,
    color: img.ColorRgb8(255, 99, 77),
  );
  img.fillRect(
    feature,
    x1: 110,
    y1: 206,
    x2: 390,
    y2: 226,
    color: img.ColorRgb8(244, 247, 251),
  );
  img.fillRect(
    feature,
    x1: 110,
    y1: 252,
    x2: 330,
    y2: 272,
    color: img.ColorRgb8(174, 185, 198),
  );

  File('${outDir.path}/feature_graphic_1024x500.png')
      .writeAsBytesSync(img.encodePng(feature));

  print('Generated Google Play assets:');
  print('  ${outDir.path}/app_icon_512.png');
  print('  ${outDir.path}/feature_graphic_1024x500.png');
}
