import 'package:flutter/foundation.dart';

enum BookingStatus {
  hold,
  confirmed,
  completed,
  expired,
  cancelled;

  String toApi() => switch (this) {
    BookingStatus.hold => 'HOLD',
    BookingStatus.confirmed => 'CONFIRMED',
    BookingStatus.completed => 'COMPLETED',
    BookingStatus.expired => 'EXPIRED',
    BookingStatus.cancelled => 'CANCELLED',
  };

  static BookingStatus fromApi(String? value) => switch (value?.toUpperCase()) {
    'HOLD' => BookingStatus.hold,
    'CONFIRMED' => BookingStatus.confirmed,
    'COMPLETED' => BookingStatus.completed,
    'EXPIRED' => BookingStatus.expired,
    'CANCELLED' => BookingStatus.cancelled,
    _ => BookingStatus.hold,
  };
}

@immutable
class BookingModel {
  const BookingModel({
    required this.id,
    required this.userId,
    required this.venueId,
    required this.venueName,
    required this.courtNumber,
    required this.date,
    required this.hours,
    required this.startAt,
    required this.endAt,
    required this.expiresAt,
    required this.total,
    required this.paid,
    required this.status,
    this.extras = '',
    this.paymentMethod = 'VietQR',
    this.pin = '0000',
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String venueId;
  final String venueName;
  final int courtNumber;
  final DateTime date;
  final List<int> hours;
  final DateTime startAt;
  final DateTime endAt;
  final DateTime expiresAt;
  final int total;
  final int paid;
  final BookingStatus status;
  final String extras;
  final String paymentMethod;
  final String pin;
  final DateTime createdAt;

  bool get isHoldExpired =>
      status == BookingStatus.hold && DateTime.now().toUtc().isAfter(expiresAt);

  bool get canCancel =>
      (status == BookingStatus.confirmed || status == BookingStatus.hold) &&
      startAt.difference(DateTime.now()).inHours >= 4;

  String get timeRangeLabel {
    if (hours.isEmpty) return '';
    final sorted = [...hours]..sort();
    final startStr = '${sorted.first.toString().padLeft(2, '0')}:00';
    final endStr = '${(sorted.last + 1).toString().padLeft(2, '0')}:00';
    return '$startStr - $endStr (${sorted.length} giờ)';
  }

  BookingModel copyWith({
    BookingStatus? status,
    int? paid,
    DateTime? expiresAt,
  }) => BookingModel(
    id: id,
    userId: userId,
    venueId: venueId,
    venueName: venueName,
    courtNumber: courtNumber,
    date: date,
    hours: hours,
    startAt: startAt,
    endAt: endAt,
    expiresAt: expiresAt ?? this.expiresAt,
    total: total,
    paid: paid ?? this.paid,
    status: status ?? this.status,
    extras: extras,
    paymentMethod: paymentMethod,
    pin: pin,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'venueId': venueId,
    'venueName': venueName,
    'courtNumber': courtNumber,
    'date': date.toIso8601String(),
    'hours': hours,
    'startAt': startAt.toUtc().toIso8601String(),
    'endAt': endAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'total': total,
    'paid': paid,
    'status': status.toApi(),
    'extras': extras,
    'paymentMethod': paymentMethod,
    'pin': pin,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory BookingModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final rawDate = DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now();
    final rawStart = DateTime.tryParse(json['startAt'] as String? ?? '') ?? rawDate;
    final rawEnd = DateTime.tryParse(json['endAt'] as String? ?? '') ?? rawStart.add(const Duration(hours: 1));
    final rawExpires = DateTime.tryParse(json['expiresAt'] as String? ?? '') ?? DateTime.now().add(const Duration(minutes: 15));
    final rawCreated = DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now();

    return BookingModel(
      id: id ?? json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      venueId: json['venueId'] as String? ?? '',
      venueName: json['venueName'] as String? ?? '',
      courtNumber: (json['courtNumber'] as num?)?.toInt() ?? 1,
      date: rawDate,
      hours: (json['hours'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? const [],
      startAt: rawStart,
      endAt: rawEnd,
      expiresAt: rawExpires,
      total: (json['total'] as num?)?.toInt() ?? 0,
      paid: (json['paid'] as num?)?.toInt() ?? 0,
      status: BookingStatus.fromApi(json['status'] as String?),
      extras: json['extras'] as String? ?? '',
      paymentMethod: json['paymentMethod'] as String? ?? 'VietQR',
      pin: json['pin'] as String? ?? '0000',
      createdAt: rawCreated,
    );
  }
}
