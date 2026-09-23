enum ListingMode {
  sell,
  rent,
  borrow,
  give,
}

enum ListingStatus {
  draft,
  active,
  paused,
  closed,
}

class Listing {
  const Listing({
    required this.id,
    required this.thingId,
    required this.ownerId,
    required this.title,
    required this.modes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.salePrice,
    this.hourlyPrice,
    this.dailyPrice,
    this.weeklyPrice,
    this.deposit,
    this.insurancePrice,
    this.publicLocationLabel,
    this.latitude,
    this.longitude,
    this.geohash,
  });

  final String id;
  final String thingId;
  final String ownerId;
  final String title;
  final Set<ListingMode> modes;
  final ListingStatus status;
  final double? salePrice;
  final double? hourlyPrice;
  final double? dailyPrice;
  final double? weeklyPrice;
  final double? deposit;
  final double? insurancePrice;
  final String? publicLocationLabel;
  final double? latitude;
  final double? longitude;
  final String? geohash;
  final DateTime createdAt;
  final DateTime updatedAt;
}
