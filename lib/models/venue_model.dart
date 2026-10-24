import 'package:flutter/foundation.dart';

@immutable
class VenueModel {
  const VenueModel({
    required this.id,
    required this.name,
    required this.address,
    required this.district,
    required this.price,
    this.rating = 4.8,
    this.tags = const [],
    this.courtCount = 4,
    this.timezone = 'Asia/Ho_Chi_Minh',
    this.active = true,
  });

  final String id;
  final String name;
  final String address;
  final String district;
  final int price;
  final double rating;
  final List<String> tags;
  final int courtCount;
  final String timezone;
  final bool active;

  int priceAt(int hour) => price + (hour >= 17 && hour < 22 ? 30000 : 0);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'district': district,
    'price': price,
    'rating': rating,
    'tags': tags,
    'courtCount': courtCount,
    'timezone': timezone,
    'active': active,
  };

  factory VenueModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return VenueModel(
      id: id ?? json['id'] as String? ?? '0',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      district: json['district'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      courtCount: (json['courtCount'] as num?)?.toInt() ?? 4,
      timezone: json['timezone'] as String? ?? 'Asia/Ho_Chi_Minh',
      active: json['active'] as bool? ?? true,
    );
  }
}

@immutable
class CourtModel {
  const CourtModel({
    required this.id,
    required this.venueId,
    required this.courtNumber,
    required this.name,
    this.basePrice = 90000,
    this.peakPrice = 120000,
    this.active = true,
  });

  final String id;
  final String venueId;
  final int courtNumber;
  final String name;
  final int basePrice;
  final int peakPrice;
  final bool active;

  Map<String, dynamic> toJson() => {
    'id': id,
    'venueId': venueId,
    'courtNumber': courtNumber,
    'name': name,
    'basePrice': basePrice,
    'peakPrice': peakPrice,
    'active': active,
  };

  factory CourtModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return CourtModel(
      id: id ?? json['id'] as String? ?? '',
      venueId: json['venueId'] as String? ?? '',
      courtNumber: (json['courtNumber'] as num?)?.toInt() ?? 1,
      name: json['name'] as String? ?? 'Sân 1',
      basePrice: (json['basePrice'] as num?)?.toInt() ?? 90000,
      peakPrice: (json['peakPrice'] as num?)?.toInt() ?? 120000,
      active: json['active'] as bool? ?? true,
    );
  }
}
