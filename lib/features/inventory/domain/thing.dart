enum ThingVisibility {
  private,
  friends,
  neighbourhood,
  public,
}

enum ThingCondition {
  newItem,
  likeNew,
  good,
  fair,
  poor,
  unknown,
}

enum ThingAction {
  sell,
  rent,
  borrow,
  give,
}

class Thing {
  const Thing({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.subcategoryId,
    this.photoUrls = const [],
    this.attributes = const {},
    this.searchKeywords = const [],
    this.quantity = 1,
    this.condition = ThingCondition.unknown,
    this.visibility = ThingVisibility.private,
    this.enabledActions = const {},
    this.estimatedNewPrice,
    this.estimatedCurrentValue,
    this.expiryDate,
    this.openedAt,
    this.latitude,
    this.longitude,
    this.geohash,
    this.locationLabel,
  });

  final String id;
  final String ownerId;
  final String name;
  final String categoryId;
  final String? subcategoryId;
  final String? description;
  final List<String> photoUrls;
  final Map<String, dynamic> attributes;
  final List<String> searchKeywords;
  final int quantity;
  final ThingCondition condition;
  final ThingVisibility visibility;
  final Set<ThingAction> enabledActions;
  final double? estimatedNewPrice;
  final double? estimatedCurrentValue;
  final DateTime? expiryDate;
  final DateTime? openedAt;
  final double? latitude;
  final double? longitude;
  final String? geohash;
  final String? locationLabel;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'categoryId': categoryId,
      'subcategoryId': subcategoryId,
      'description': description,
      'photoUrls': photoUrls,
      'attributes': attributes,
      'searchKeywords': searchKeywords,
      'quantity': quantity,
      'condition': condition.name,
      'visibility': visibility.name,
      'enabledActions': enabledActions.map((action) => action.name).toList(),
      'estimatedNewPrice': estimatedNewPrice,
      'estimatedCurrentValue': estimatedCurrentValue,
      'expiryDate': expiryDate?.toIso8601String(),
      'openedAt': openedAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'geohash': geohash,
      'locationLabel': locationLabel,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
