import 'package:flutter/material.dart';

import '../models/models.dart';

const demoCourts = <Court>[
  Court(
    id: 'CR01',
    name: 'Smash Hub Nguyễn Trãi',
    address: '128 Nguyễn Trãi, Thanh Xuân',
    distance: '1,2 km',
    price: 120000,
    rating: 4.9,
    reviewCount: 238,
    accent: Color(0xFF0E6B53),
    icon: Icons.sports_tennis_rounded,
    tags: ['Điều hòa', 'Thảm PVC', 'Bãi xe'],
    isFavorite: true,
  ),
  Court(
    id: 'CR02',
    name: 'Nova Badminton Club',
    address: '56 Lê Văn Lương, Cầu Giấy',
    distance: '2,8 km',
    price: 100000,
    rating: 4.8,
    reviewCount: 164,
    accent: Color(0xFF285F9E),
    icon: Icons.bolt_rounded,
    tags: ['8 sân', 'Căng tin', 'Tủ đồ'],
  ),
  Court(
    id: 'CR03',
    name: 'The Rally Arena',
    address: '21 Hoàng Minh Giám, Hà Nội',
    distance: '3,5 km',
    price: 140000,
    rating: 4.7,
    reviewCount: 91,
    accent: Color(0xFF74503B),
    icon: Icons.stadium_rounded,
    tags: ['Mới', 'Trần cao', 'Phòng tắm'],
  ),
];

const demoSlots = <TimeSlot>[
  TimeSlot('06:00', true),
  TimeSlot('07:30', true),
  TimeSlot('09:00', false),
  TimeSlot('10:30', true),
  TimeSlot('14:00', true),
  TimeSlot('15:30', true),
  TimeSlot('17:00', false),
  TimeSlot('18:30', true),
  TimeSlot('20:00', true),
];

final initialBookings = <Booking>[
  Booking(
    id: 'BK240921',
    court: demoCourts[0],
    date: 'Thứ Bảy, 10/10/2026',
    time: '18:30 – 20:00',
    total: 180000,
    status: BookingStatus.upcoming,
  ),
  Booking(
    id: 'BK190802',
    court: demoCourts[1],
    date: 'Chủ Nhật, 27/09/2026',
    time: '07:30 – 09:00',
    total: 150000,
    status: BookingStatus.completed,
  ),
];
