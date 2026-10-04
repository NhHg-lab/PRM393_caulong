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
  });
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
  });
  final String id;
  final Court court;
  final String date;
  final String time;
  final int total;
  final BookingStatus status;

  Booking copyWith({BookingStatus? status}) => Booking(
    id: id,
    court: court,
    date: date,
    time: time,
    total: total,
    status: status ?? this.status,
  );
}

class TimeSlot {
  const TimeSlot(this.label, this.available);
  final String label;
  final bool available;
}
