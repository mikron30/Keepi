// ignore_for_file: prefer_interpolation_to_compose_strings

import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

final navy = img.ColorRgb8(7, 17, 29);

img.Image _opaqueCanvas(int size) {
  final canvas = img.Image(width: size, height: size, numChannels: 3);
  img.fill(canvas, color: navy);
  return canvas;
}

void _writeStandard(img.Image source, int size, String path) {
  final canvas = _opaqueCanvas(size);
  final resized = img.copyResize(
    source,
    width: size,
    height: size,
    interpolation: img.Interpolation.cubic,
  );
  img.compositeImage(canvas, resized);
  File(path).writeAsBytesSync(img.encodePng(canvas));
}

void _writeMaskable(img.Image source, int size, String path) {
  final canvas = _opaqueCanvas(size);
  final inner = (size * 0.78).round();
  final resized = img.copyResize(
    source,
    width: inner,
    height: inner,
    interpolation: img.Interpolation.cubic,
  );
  final offset = ((size - inner) / 2).round();
  img.compositeImage(canvas, resized, dstX: offset, dstY: offset);
  File(path).writeAsBytesSync(img.encodePng(canvas));
}

void _verify(String path, int expectedSize) {
  final bytes = File(path).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Generated icon cannot be decoded: ' + path);
  }
  if (decoded.width != expectedSize || decoded.height != expectedSize) {
    throw StateError(
      'Generated icon has wrong size: ' + path + ' (' +
      decoded.width.toString() + 'x' + decoded.height.toString() +
      ', expected ' + expectedSize.toString() + 'x' + expectedSize.toString() + ')',
    );
  }
}

void main() {
  final sourceFile = File('assets/images/keepi_icon_clean.webp.b64');
  if (!sourceFile.existsSync()) {
    throw StateError('Missing assets/images/keepi_icon_clean.webp.b64');
  }

  final encoded = sourceFile.readAsStringSync().replaceAll(RegExp(r'\\s+'), '');
  final sourceBytes = base64Decode(encoded);
  final source = img.decodeImage(sourceBytes);
  if (source == null) {
    throw StateError('Could not decode clean approved Keepi icon.');
  }

  if (source.width != source.height) {
    throw StateError(
      'Approved Keepi icon must be square, got ' +
      source.width.toString() + 'x' + source.height.toString() + '.',
    );
  }

  final iconsDir = Directory('build/web/icons');
  iconsDir.createSync(recursive: true);

  final outputs = <(int, bool, String)>[
    (192, false, 'build/web/icons/Icon-192.png'),
    (512, false, 'build/web/icons/Icon-512.png'),
    (192, true, 'build/web/icons/Icon-maskable-192.png'),
    (512, true, 'build/web/icons/Icon-maskable-512.png'),
  ];

  for (final (size, maskable, path) in outputs) {
    if (maskable) {
      _writeMaskable(source, size, path);
    } else {
      _writeStandard(source, size, path);
    }
    _verify(path, size);
  }

  stdout.writeln(
    'Keepi PWA icons generated with package:image '
    '(no System.Drawing): standard + maskable 192/512.',
  );
}
