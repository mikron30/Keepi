import 'package:cloud_firestore/cloud_firestore.dart';

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
  personalUse,
  sell,
  rent,
  borrow,
  give,
  exchange,
}

class Thing {
  const Thing({
    required this.id,
    required this.ownerId,
    this.ownerDisplayName = 'Keepi user',
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
    this.currentHolderUserId,
    this.currentHolderName,
    this.loanedAt,
    this.dueAt,
  });

  final String id;
  final String ownerId;
  final String ownerDisplayName;
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
  final String? currentHolderUserId;
  final String? currentHolderName;
  final DateTime? loanedAt;
  final DateTime? dueAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Thing.fromMap(String id, Map<String, dynamic> data) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    ThingCondition parseCondition(dynamic value) {
      final text = value?.toString() ?? 'unknown';
      return ThingCondition.values.firstWhere(
        (item) => item.name == text,
        orElse: () => ThingCondition.unknown,
      );
    }

    ThingVisibility parseVisibility(dynamic value) {
      final text = value?.toString() ?? 'private';
      return ThingVisibility.values.firstWhere(
        (item) => item.name == text,
        orElse: () => ThingVisibility.private,
      );
    }

    final actionNames = (data['enabledActions'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toSet();

    return Thing(
      id: id,
      ownerId: (data['ownerId'] ?? '').toString(),
      ownerDisplayName: (data['ownerDisplayName'] ?? 'Keepi user').toString(),
      name: (data['name'] ?? 'Unnamed Thing').toString(),
      categoryId: (data['categoryId'] ?? 'other').toString(),
      subcategoryId: data['subcategoryId']?.toString(),
      description: data['description']?.toString(),
      photoUrls: (data['photoUrls'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      attributes: Map<String, dynamic>.from(
        data['attributes'] as Map? ?? const <String, dynamic>{},
      ),
      searchKeywords: (data['searchKeywords'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      condition: parseCondition(data['condition']),
      visibility: parseVisibility(data['visibility']),
      enabledActions: ThingAction.values
          .where((action) => actionNames.contains(action.name))
          .toSet(),
      estimatedNewPrice: (data['estimatedNewPrice'] as num?)?.toDouble(),
      estimatedCurrentValue:
          (data['estimatedCurrentValue'] as num?)?.toDouble(),
      expiryDate: data['expiryDate'] == null
          ? null
          : parseDate(data['expiryDate']),
      openedAt:
          data['openedAt'] == null ? null : parseDate(data['openedAt']),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      geohash: data['geohash']?.toString(),
      locationLabel: data['locationLabel']?.toString(),
      currentHolderUserId: data['currentHolderUserId']?.toString(),
      currentHolderName: data['currentHolderName']?.toString(),
      loanedAt:
          data['loanedAt'] == null ? null : parseDate(data['loanedAt']),
      dueAt: data['dueAt'] == null ? null : parseDate(data['dueAt']),
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
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
      'currentHolderUserId': currentHolderUserId,
      'currentHolderName': currentHolderName,
      'loanedAt': loanedAt?.toIso8601String(),
      'dueAt': dueAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
