import 'dart:typed_data';

import 'thing_recognition.dart';

class ScannedThingCandidate {
  const ScannedThingCandidate({
    required this.recognition,
    required this.cropBytes,
    required this.itemIndex,
    required this.totalItems,
  });

  final ThingRecognition recognition;
  final Uint8List cropBytes;
  final int itemIndex;
  final int totalItems;

  ScannedThingCandidate copyWith({
    ThingRecognition? recognition,
    Uint8List? cropBytes,
    int? itemIndex,
    int? totalItems,
  }) {
    return ScannedThingCandidate(
      recognition: recognition ?? this.recognition,
      cropBytes: cropBytes ?? this.cropBytes,
      itemIndex: itemIndex ?? this.itemIndex,
      totalItems: totalItems ?? this.totalItems,
    );
  }
}
