class ThingRecognition {
  const ThingRecognition({
    required this.name,
    required this.categoryId,
    required this.subcategory,
    required this.brand,
    required this.model,
    required this.condition,
    required this.description,
    required this.estimatedNewPriceIls,
    required this.estimatedCurrentValueIls,
    required this.confidence,
    required this.searchKeywords,
  });

  final String name;
  final String categoryId;
  final String subcategory;
  final String brand;
  final String model;
  final String condition;
  final String description;
  final int estimatedNewPriceIls;
  final int estimatedCurrentValueIls;
  final int confidence;
  final List<String> searchKeywords;

  factory ThingRecognition.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return ThingRecognition(
      name: (json['name'] ?? '').toString().trim(),
      categoryId: (json['categoryId'] ?? 'other').toString().trim(),
      subcategory: (json['subcategory'] ?? '').toString().trim(),
      brand: (json['brand'] ?? '').toString().trim(),
      model: (json['model'] ?? '').toString().trim(),
      condition: (json['condition'] ?? 'unknown').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      estimatedNewPriceIls: toInt(json['estimatedNewPriceIls']),
      estimatedCurrentValueIls: toInt(json['estimatedCurrentValueIls']),
      confidence: toInt(json['confidence']).clamp(0, 100),
      searchKeywords: (json['searchKeywords'] as List<dynamic>? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(),
    );
  }
}
