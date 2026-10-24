import 'package:flutter_test/flutter_test.dart';
import 'package:courtly/models/auth_models.dart';
import 'package:courtly/models/booking_model.dart';
import 'package:courtly/models/venue_model.dart';
import 'package:courtly/services/booking_repository.dart';
import 'package:courtly/services/pricing_engine.dart';
import 'package:courtly/services/venue_repository.dart';

void main() {
  group('PricingEngine', () {
    const venue = VenueModel(
      id: '0',
      name: 'SkyBadminton',
      address: '152 Nguyen Thi Thap',
      district: 'Quan 7',
      price: 90000,
    );

    test('calculates standard hour vs peak hour (17:00 - 22:00)', () {
      // 14:00 is standard (90.000)
      expect(PricingEngine.calculateHourPrice(basePrice: 90000, hour: 14), 90000);
      // 17:00 is peak (90.000 + 30.000 = 120.000)
      expect(PricingEngine.calculateHourPrice(basePrice: 90000, hour: 17), 120000);
      // 21:00 is peak (120.000)
      expect(PricingEngine.calculateHourPrice(basePrice: 90000, hour: 21), 120000);
      // 22:00 is standard (90.000)
      expect(PricingEngine.calculateHourPrice(basePrice: 90000, hour: 22), 90000);
    });

    test('validates consecutive hours correctly', () {
      expect(PricingEngine.validateConsecutiveHours([14, 15, 16]), isTrue);
      expect(PricingEngine.validateConsecutiveHours([14]), isTrue);
      expect(PricingEngine.validateConsecutiveHours([14, 16]), isFalse);
      expect(PricingEngine.validateConsecutiveHours([]), isFalse);
    });

    test('comprehensive calculation with rent, addons, vouchers and deposit', () {
      // 2 hours: 16 (standard 90k) + 17 (peak 120k) = 210k rent
      // addons: 2 rackets (60k) + 1 shuttle (220k) + 2 waters (20k) = 300k
      // voucher: -30k
      // total = 210k + 300k - 30k = 480k
      // deposit = 50% = 240k
      final calc = PricingEngine.calculate(
        venue: venue,
        hours: [16, 17],
        rackets: 2,
        shuttleTubes: 1,
        waters: 2,
        applyVoucher: true,
      );

      expect(calc.rent, 210000);
      expect(calc.addonsTotal, 300000);
      expect(calc.discount, 30000);
      expect(calc.total, 480000);
      expect(calc.deposit, 240000);
    });
  });

  group('VenueRepository', () {
    late VenueRepository repo;

    setUp(() {
      repo = DemoVenueRepository();
    });

    test('retrieves venue list and court configurations', () async {
      final venues = await repo.getVenues();
      expect(venues.length, greaterThanOrEqualTo(3));

      final firstVenue = venues.first;
      final courts = await repo.getCourts(firstVenue.id);
      expect(courts.length, firstVenue.courtCount);
      expect(courts.first.venueId, firstVenue.id);
    });

    test('toggles and watches favorites per user', () async {
      const userId = 'user_abc';
      expect(await repo.isFavorite(userId, '0'), isFalse);

      await repo.toggleFavorite(userId, '0', true);
      expect(await repo.isFavorite(userId, '0'), isTrue);

      await repo.toggleFavorite(userId, '0', false);
      expect(await repo.isFavorite(userId, '0'), isFalse);
    });
  });

  group('BookingRepository & Hold Engine', () {
    late BookingRepository repo;
    final targetDate = DateTime.now().add(const Duration(days: 2));

    setUp(() {
      repo = DemoBookingRepository();
    });

    test('creates HOLD booking with 15 minutes expiry and unique PIN', () async {
      final booking = await repo.createHoldBooking(
        userId: 'user_1',
        venueId: '0',
        venueName: 'SkyBadminton',
        courtNumber: 1,
        date: targetDate,
        hours: [14, 15],
        total: 180000,
        paid: 90000,
      );

      expect(booking.status, BookingStatus.hold);
      expect(booking.pin.length, 4);
      expect(booking.isHoldExpired, isFalse);
      expect(booking.expiresAt.difference(DateTime.now().toUtc()).inMinutes, lessThanOrEqualTo(15));
      expect(booking.timeRangeLabel, '14:00 - 16:00 (2 giờ)');

      final userBookings = await repo.getUserBookings('user_1');
      expect(userBookings.length, 1);
      expect(userBookings.first.id, booking.id);
    });

    test('detects slot collision and prevents double booking of active holds', () async {
      await repo.createHoldBooking(
        userId: 'user_1',
        venueId: '0',
        venueName: 'SkyBadminton',
        courtNumber: 1,
        date: targetDate,
        hours: [14, 15],
        total: 180000,
        paid: 90000,
      );

      // user_2 tries to book overlapping hour 15 on same venue & court
      expect(
        () => repo.createHoldBooking(
          userId: 'user_2',
          venueId: '0',
          venueName: 'SkyBadminton',
          courtNumber: 1,
          date: targetDate,
          hours: [15, 16],
          total: 180000,
          paid: 90000,
        ),
        throwsA(isA<AuthException>().having((e) => e.statusCode, 'status', 409)),
      );

      // booking a different court or non-overlapping hours succeeds
      final okBooking = await repo.createHoldBooking(
        userId: 'user_2',
        venueId: '0',
        venueName: 'SkyBadminton',
        courtNumber: 1,
        date: targetDate,
        hours: [16, 17],
        total: 210000,
        paid: 105000,
      );
      expect(okBooking.status, BookingStatus.hold);
    });

    test('cancellation policy enforces >= 4 hours before startsAt', () async {
      // Booking in 2 days (can cancel)
      final farBooking = await repo.createHoldBooking(
        userId: 'user_1',
        venueId: '0',
        venueName: 'SkyBadminton',
        courtNumber: 1,
        date: targetDate,
        hours: [14],
        total: 90000,
        paid: 90000,
      );
      expect(farBooking.canCancel, isTrue);
      await repo.cancelBooking(bookingId: farBooking.id, userId: 'user_1');
      final cancelled = (await repo.getUserBookings('user_1')).first;
      expect(cancelled.status, BookingStatus.cancelled);

      // Booking only 2 hours away (cannot cancel)
      final nearDate = DateTime.now().add(const Duration(hours: 2));
      final nearBooking = await repo.createHoldBooking(
        userId: 'user_1',
        venueId: '0',
        venueName: 'SkyBadminton',
        courtNumber: 2,
        date: nearDate,
        hours: [nearDate.hour],
        total: 90000,
        paid: 90000,
      );
      expect(nearBooking.canCancel, isFalse);
      expect(
        () => repo.cancelBooking(bookingId: nearBooking.id, userId: 'user_1'),
        throwsA(isA<AuthException>().having((e) => e.statusCode, 'status', 400)),
      );
    });

    test('confirmBooking updates status to confirmed', () async {
      final booking = await repo.createHoldBooking(
        userId: 'user_1',
        venueId: '0',
        venueName: 'SkyBadminton',
        courtNumber: 1,
        date: targetDate,
        hours: [18, 19],
        total: 240000,
        paid: 120000,
      );

      await repo.confirmBooking(booking.id);
      final updated = (await repo.getUserBookings('user_1')).first;
      expect(updated.status, BookingStatus.confirmed);
      expect(updated.paid, 240000);
    });
  });
}
