import '../models/venue_model.dart';

class PricingCalculation {
  const PricingCalculation({
    required this.hours,
    required this.hourlyRates,
    required this.rent,
    required this.addonsTotal,
    required this.discount,
    required this.total,
    required this.deposit,
  });

  final List<int> hours;
  final Map<int, int> hourlyRates;
  final int rent;
  final int addonsTotal;
  final int discount;
  final int total;
  final int deposit;
}

class PricingEngine {
  static const int peakHourStart = 17;
  static const int peakHourEnd = 22;
  static const int peakSurcharge = 30000;

  static const int racketPrice = 30000;
  static const int shuttleTubePrice = 220000;
  static const int waterPrice = 10000;
  static const int demoVoucherDiscount = 30000;

  static int calculateHourPrice({
    required int basePrice,
    required int hour,
    int peakPriceDifference = peakSurcharge,
  }) {
    final isPeak = hour >= peakHourStart && hour < peakHourEnd;
    return basePrice + (isPeak ? peakPriceDifference : 0);
  }

  static bool validateConsecutiveHours(Iterable<int> hours) {
    if (hours.isEmpty) return false;
    final sorted = hours.toList()..sort();
    return sorted.last - sorted.first + 1 == sorted.length;
  }

  static bool isHourInPast(DateTime date, int hour) {
    final slotTime = DateTime(date.year, date.month, date.day, hour);
    return slotTime.isBefore(DateTime.now());
  }

  static PricingCalculation calculate({
    required VenueModel venue,
    required Iterable<int> hours,
    int rackets = 0,
    int shuttleTubes = 0,
    int waters = 0,
    bool applyVoucher = false,
  }) {
    final sortedHours = hours.toList()..sort();
    final rates = <int, int>{};
    int rent = 0;

    for (final h in sortedHours) {
      final rate = venue.priceAt(h);
      rates[h] = rate;
      rent += rate;
    }

    final addons = (rackets * racketPrice) +
        (shuttleTubes * shuttleTubePrice) +
        (waters * waterPrice);
    final discount = applyVoucher ? demoVoucherDiscount : 0;
    final total = (rent + addons - discount).clamp(0, 100000000);
    // Deposit 50%
    final deposit = (total / 2).ceil();

    return PricingCalculation(
      hours: sortedHours,
      hourlyRates: rates,
      rent: rent,
      addonsTotal: addons,
      discount: discount,
      total: total,
      deposit: deposit,
    );
  }
}
