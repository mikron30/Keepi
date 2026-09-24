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

    final left = normalized(json['xMin']);
    final top = normalized(json['yMin']);
    final right = normalized(json['xMax']);
    final bottom = normalized(json['yMax']);

    return ThingDetection(
      hint: (json['hint'] ?? 'item').toString().trim(),
      xMin: left,
      yMin: top,
      xMax: right,
      yMax: bottom,
      confidence: toInt(json['confidence']).clamp(0, 100),
    );
  }

  bool get hasValidBox => xMax > xMin && yMax > yMin;
}
