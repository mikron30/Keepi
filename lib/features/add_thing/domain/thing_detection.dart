class ThingDetection {
  const ThingDetection({
    required this.hint,
    required this.xMin,
    required this.yMin,
    required this.xMax,
    required this.yMax,
    required this.confidence,
  });

  final String hint;

  /// Normalized coordinates in the 0..1000 range.
  final int xMin;
  final int yMin;
  final int xMax;
  final int yMax;
  final int confidence;

  factory ThingDetection.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    int normalized(dynamic value) => toInt(value).clamp(0, 1000);

    // Gemini vision commonly represents a box as
    // [yMin, xMin, yMax, xMax] in a normalized 0..1000 coordinate system.
    // Keep supporting the older explicit fields as a fallback.
    final rawBox = json['box2d'];
    if (rawBox is List && rawBox.length >= 4) {
      final yMin = normalized(rawBox[0]);
      final xMin = normalized(rawBox[1]);
      final yMax = normalized(rawBox[2]);
      final xMax = normalized(rawBox[3]);

      return ThingDetection(
        hint: (json['hint'] ?? 'item').toString().trim(),
        xMin: xMin,
        yMin: yMin,
        xMax: xMax,
        yMax: yMax,
        confidence: toInt(json['confidence']).clamp(0, 100),
      );
    }

    return ThingDetection(
      hint: (json['hint'] ?? 'item').toString().trim(),
      xMin: normalized(json['xMin']),
      yMin: normalized(json['yMin']),
      xMax: normalized(json['xMax']),
      yMax: normalized(json['yMax']),
      confidence: toInt(json['confidence']).clamp(0, 100),
    );
  }

  bool get hasValidBox => xMax > xMin && yMax > yMin;

  int get width => xMax - xMin;
  int get height => yMax - yMin;

  double get normalizedArea => (width * height) / 1000000;
}
