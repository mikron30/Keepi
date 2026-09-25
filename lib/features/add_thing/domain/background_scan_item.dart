class BackgroundScanItem {
  const BackgroundScanItem({
    required this.id,
    required this.index,
    required this.status,
    required this.hint,
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
    required this.cropUrl,
    required this.cropStoragePath,
    required this.sourceUrl,
    required this.sourceStoragePath,
  });

  final String id;
  final int index;
  final String status;
  final String hint;
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
  final String cropUrl;
  final String cropStoragePath;
  final String sourceUrl;
  final String sourceStoragePath;

  factory BackgroundScanItem.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    final recognition =
        Map<String, dynamic>.from(data['recognition'] as Map? ?? const {});

    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return BackgroundScanItem(
      id: id,
      index: readInt(data['index']),
      status: (data['status'] ?? '').toString(),
      hint: (data['hint'] ?? '').toString(),
      name: (recognition['name'] ?? 'Thing').toString(),
      categoryId: (recognition['categoryId'] ?? 'other').toString(),
      subcategory: (recognition['subcategory'] ?? '').toString(),
      brand: (recognition['brand'] ?? '').toString(),
      model: (recognition['model'] ?? '').toString(),
      condition: (recognition['condition'] ?? 'unknown').toString(),
      description: (recognition['description'] ?? '').toString(),
      estimatedNewPriceIls:
          readInt(recognition['estimatedNewPriceIls']),
      estimatedCurrentValueIls:
          readInt(recognition['estimatedCurrentValueIls']),
      confidence: readInt(recognition['confidence']),
      searchKeywords:
          (recognition['searchKeywords'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toList(),
      cropUrl: (data['cropUrl'] ?? '').toString(),
      cropStoragePath: (data['cropStoragePath'] ?? '').toString(),
      sourceUrl: (data['sourceUrl'] ?? '').toString(),
      sourceStoragePath: (data['sourceStoragePath'] ?? '').toString(),
    );
  }
}
