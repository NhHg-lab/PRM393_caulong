import 'package:flutter/material.dart';

class Court {
  const Court({
    required this.id,
    required this.name,
    required this.address,
    required this.distance,
    required this.price,
    required this.rating,
    required this.reviewCount,
    required this.accent,
    required this.icon,
    required this.tags,
    this.isFavorite = false,
    this.active = true,
  });

  factory Court.fromJson(Map<String, dynamic> json) => Court(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
    distance: (json['distance'] as String?) ?? '--',
    price: (json['price'] as num).toInt(),
    rating: (json['rating'] as num).toDouble(),
    reviewCount: (json['reviewCount'] as num).toInt(),
    accent: _colorFromHex((json['accentColor'] as String?) ?? '0E6B53'),
    icon: _iconFromName((json['iconName'] as String?) ?? 'sports_tennis'),
    tags: (json['tags'] as List<dynamic>? ?? const [])
        .map((item) => item.toString())
        .toList(growable: false),
    isFavorite: json['favorite'] as bool? ?? false,
    active: json['active'] as bool? ?? true,
  );

  final String id;
  final String name;
  final String address;
  final String distance;
  final int price;
  final double rating;
  final int reviewCount;
  final Color accent;
  final IconData icon;
  final List<String> tags;
  final bool isFavorite;
  final bool active;

  Court copyWith({bool? isFavorite, bool? active}) => Court(
    id: id,
    name: name,
    address: address,
    distance: distance,
    price: price,
    rating: rating,
    reviewCount: reviewCount,
    accent: accent,
    icon: icon,
    tags: tags,
    isFavorite: isFavorite ?? this.isFavorite,
    active: active ?? this.active,
  );
}

enum BookingStatus { upcoming, completed, cancelled }

class Booking {
  const Booking({
    required this.id,
    required this.court,
    required this.date,
    required this.time,
    required this.total,
    required this.status,
    this.slotId,
    this.paymentMethod,
    this.paymentStatus,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final start = json['startTime'] as String? ?? '';
    final end = json['endTime'] as String? ?? '';
    return Booking(
      id: json['id'] as String,
      court: Court.fromJson(json['court'] as Map<String, dynamic>),
      date: _displayDate(json['date'] as String),
      time: '$start – $end',
      total: (json['total'] as num).toInt(),
      status: _bookingStatus(json['status'] as String?),
      paymentMethod: json['paymentMethod'] as String?,
      paymentStatus: json['paymentStatus'] as String?,
    );
  }

  final String id;
  final Court court;
  final String date;
  final String time;
  final int total;
  final BookingStatus status;
  final String? slotId;
  final String? paymentMethod;
  final String? paymentStatus;

  Booking copyWith({BookingStatus? status}) => Booking(
    id: id,
    court: court,
    date: date,
    time: time,
    total: total,
    status: status ?? this.status,
    slotId: slotId,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus,
  );
}

class TimeSlot {
  const TimeSlot(
    this.label,
    this.available, {
    this.id = '',
    this.endTime = '',
    this.status = 'AVAILABLE',
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
    json['startTime'] as String,
    json['available'] as bool? ?? false,
    id: json['id'] as String,
    endTime: json['endTime'] as String? ?? '',
    status: json['status'] as String? ?? 'AVAILABLE',
  );

  final String id;
  final String label;
  final String endTime;
  final bool available;
  final String status;
}

Color _colorFromHex(String value) {
  final clean = value.replaceAll('#', '');
  final parsed = int.tryParse(clean, radix: 16) ?? 0x0E6B53;
  return Color(0xFF000000 | parsed);
}

IconData _iconFromName(String value) => switch (value) {
  'bolt' => Icons.bolt_rounded,
  'stadium' => Icons.stadium_rounded,
  _ => Icons.sports_tennis_rounded,
};

BookingStatus _bookingStatus(String? value) => switch (value) {
  'COMPLETED' => BookingStatus.completed,
  'CANCELLED' => BookingStatus.cancelled,
  _ => BookingStatus.upcoming,
};

String _displayDate(String iso) {
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  const weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  return '${weekdays[date.weekday - 1]}, $dd/$mm/${date.year}';
}
