import 'dart:typed_data';

import 'thing_recognition.dart';

class ScannedThingCandidate {
  const ScannedThingCandidate({
    required this.recognition,
    required this.tileBytes,
    required this.tileIndex,
    required this.totalTiles,
  });

  final ThingRecognition recognition;
  final Uint8List tileBytes;
  final int tileIndex;
  final int totalTiles;

  ScannedThingCandidate copyWith({
    ThingRecognition? recognition,
    Uint8List? tileBytes,
    int? tileIndex,
    int? totalTiles,
  }) {
    return ScannedThingCandidate(
      recognition: recognition ?? this.recognition,
      tileBytes: tileBytes ?? this.tileBytes,
      tileIndex: tileIndex ?? this.tileIndex,
      totalTiles: totalTiles ?? this.totalTiles,
    );
  }
}
