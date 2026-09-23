class NeedRequest {
  const NeedRequest({
    required this.id,
    required this.ownerId,
    required this.query,
    required this.createdAt,
    required this.active,
    this.categoryId,
    this.maxDistanceKm,
    this.maxPrice,
    this.neededFrom,
    this.neededUntil,
    this.latitude,
    this.longitude,
    this.geohash,
  });

  final String id;
  final String ownerId;
  final String query;
  final String? categoryId;
  final double? maxDistanceKm;
  final double? maxPrice;
  final DateTime? neededFrom;
  final DateTime? neededUntil;
  final double? latitude;
  final double? longitude;
  final String? geohash;
  final DateTime createdAt;
  final bool active;
}
