import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../config/app_config.dart';
import '../models/auth_models.dart';
import '../models/booking_model.dart';

abstract class BookingRepository {
  Future<List<BookingModel>> getUserBookings(String userId);
  Stream<List<BookingModel>> watchUserBookings(String userId);
  Future<List<BookingModel>> getActiveBookingsForCourt({
    required String venueId,
    required int courtNumber,
    required DateTime date,
  });
  Future<BookingModel> createHoldBooking({
    required String userId,
    required String venueId,
    required String venueName,
    required int courtNumber,
    required DateTime date,
    required List<int> hours,
    required int total,
    required int paid,
    String extras = '',
    String paymentMethod = 'VietQR',
  });
  Future<void> confirmBooking(String bookingId);
  Future<void> cancelBooking({
    required String bookingId,
    required String userId,
  });

  factory BookingRepository.instance({FirebaseFirestore? firestore}) {
    if (AppConfig.authMode == AuthMode.firebase &&
        (firestore != null || Firebase.apps.isNotEmpty)) {
      return FirestoreBookingRepository(firestore: firestore);
    }
    return DemoBookingRepository();
  }
}

class DemoBookingRepository implements BookingRepository {
  final List<BookingModel> _bookings = [];
  final _streamController = StreamController<List<BookingModel>>.broadcast();

  @override
  Future<List<BookingModel>> getUserBookings(String userId) async {
    _cleanExpiredHolds();
    return _bookings.where((b) => b.userId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Stream<List<BookingModel>> watchUserBookings(String userId) {
    return _streamController.stream.map(
      (list) => list.where((b) => b.userId == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  @override
  Future<List<BookingModel>> getActiveBookingsForCourt({
    required String venueId,
    required int courtNumber,
    required DateTime date,
  }) async {
    _cleanExpiredHolds();
    return _bookings.where((b) {
      if (b.venueId != venueId || b.courtNumber != courtNumber) return false;
      if (b.date.year != date.year ||
          b.date.month != date.month ||
          b.date.day != date.day) {
        return false;
      }
      return b.status == BookingStatus.confirmed ||
          (b.status == BookingStatus.hold && !b.isHoldExpired);
    }).toList();
  }

  @override
  Future<BookingModel> createHoldBooking({
    required String userId,
    required String venueId,
    required String venueName,
    required int courtNumber,
    required DateTime date,
    required List<int> hours,
    required int total,
    required int paid,
    String extras = '',
    String paymentMethod = 'VietQR',
  }) async {
    _cleanExpiredHolds();

    // Check collision
    final active = await getActiveBookingsForCourt(
      venueId: venueId,
      courtNumber: courtNumber,
      date: date,
    );
    for (final b in active) {
      for (final h in hours) {
        if (b.hours.contains(h)) {
          throw const AuthException(
            'Khung giờ đã được giữ chỗ hoặc thanh toán bởi người khác.',
            statusCode: 409,
          );
        }
      }
    }

    final sortedHours = [...hours]..sort();
    final startAt = DateTime(date.year, date.month, date.day, sortedHours.first);
    final endAt = DateTime(date.year, date.month, date.day, sortedHours.last + 1);
    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 15));
    final randomPin = (1000 + Random().nextInt(9000)).toString();
    final id = 'BK-${DateTime.now().microsecondsSinceEpoch}';

    final booking = BookingModel(
      id: id,
      userId: userId,
      venueId: venueId,
      venueName: venueName,
      courtNumber: courtNumber,
      date: date,
      hours: sortedHours,
      startAt: startAt,
      endAt: endAt,
      expiresAt: expiresAt,
      total: total,
      paid: paid,
      status: BookingStatus.hold,
      extras: extras,
      paymentMethod: paymentMethod,
      pin: randomPin,
      createdAt: DateTime.now().toUtc(),
    );

    _bookings.insert(0, booking);
    _notify();
    return booking;
  }

  @override
  Future<void> confirmBooking(String bookingId) async {
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      final b = _bookings[idx];
      _bookings[idx] = b.copyWith(status: BookingStatus.confirmed, paid: b.total);
      _notify();
    }
  }

  @override
  Future<void> cancelBooking({
    required String bookingId,
    required String userId,
  }) async {
    final idx = _bookings.indexWhere((b) => b.id == bookingId && b.userId == userId);
    if (idx == -1) {
      throw const AuthException('Không tìm thấy thông tin vé đặt.', statusCode: 404);
    }
    final booking = _bookings[idx];
    if (!booking.canCancel) {
      throw const AuthException(
        'Chỉ có thể hủy vé trước giờ thi đấu ít nhất 4 tiếng.',
        statusCode: 400,
      );
    }
    _bookings[idx] = booking.copyWith(status: BookingStatus.cancelled);
    _notify();
  }

  void _cleanExpiredHolds() {
    for (int i = 0; i < _bookings.length; i++) {
      if (_bookings[i].isHoldExpired) {
        _bookings[i] = _bookings[i].copyWith(status: BookingStatus.expired);
      }
    }
  }

  void _notify() {
    _streamController.add(List.unmodifiable(_bookings));
  }
}

class FirestoreBookingRepository implements BookingRepository {
  FirestoreBookingRepository({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  static const bookingsCollection = 'bookings';
  final DemoBookingRepository _fallback = DemoBookingRepository();

  @override
  Future<List<BookingModel>> getUserBookings(String userId) async {
    try {
      final snapshot = await _db
          .collection(bookingsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => BookingModel.fromJson(doc.data(), id: doc.id))
          .toList();
    } catch (_) {
      return _fallback.getUserBookings(userId);
    }
  }

  @override
  Stream<List<BookingModel>> watchUserBookings(String userId) {
    try {
      return _db
          .collection(bookingsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => BookingModel.fromJson(doc.data(), id: doc.id))
              .toList());
    } catch (_) {
      return _fallback.watchUserBookings(userId);
    }
  }

  @override
  Future<List<BookingModel>> getActiveBookingsForCourt({
    required String venueId,
    required int courtNumber,
    required DateTime date,
  }) async {
    try {
      final startOfDay = DateTime.utc(date.year, date.month, date.day);
      final endOfDay = DateTime.utc(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _db
          .collection(bookingsCollection)
          .where('venueId', isEqualTo: venueId)
          .where('courtNumber', isEqualTo: courtNumber)
          .where('startAt', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('startAt', isLessThanOrEqualTo: endOfDay.toIso8601String())
          .get();

      return snapshot.docs
          .map((doc) => BookingModel.fromJson(doc.data(), id: doc.id))
          .where((b) =>
              b.status == BookingStatus.confirmed ||
              (b.status == BookingStatus.hold && !b.isHoldExpired))
          .toList();
    } catch (_) {
      return _fallback.getActiveBookingsForCourt(
        venueId: venueId,
        courtNumber: courtNumber,
        date: date,
      );
    }
  }

  @override
  Future<BookingModel> createHoldBooking({
    required String userId,
    required String venueId,
    required String venueName,
    required int courtNumber,
    required DateTime date,
    required List<int> hours,
    required int total,
    required int paid,
    String extras = '',
    String paymentMethod = 'VietQR',
  }) async {
    try {
      final sortedHours = [...hours]..sort();
      final startAt = DateTime.utc(date.year, date.month, date.day, sortedHours.first);
      final endAt = DateTime.utc(date.year, date.month, date.day, sortedHours.last + 1);
      final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 15));
      final pin = (1000 + Random().nextInt(9000)).toString();

      final docRef = _db.collection(bookingsCollection).doc();
      final data = {
        'id': docRef.id,
        'userId': userId,
        'venueId': venueId,
        'venueName': venueName,
        'courtNumber': courtNumber,
        'date': date.toIso8601String(),
        'hours': sortedHours,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'total': total,
        'paid': paid,
        'status': 'HOLD',
        'extras': extras,
        'paymentMethod': paymentMethod,
        'pin': pin,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(data);

      return BookingModel(
        id: docRef.id,
        userId: userId,
        venueId: venueId,
        venueName: venueName,
        courtNumber: courtNumber,
        date: date,
        hours: sortedHours,
        startAt: startAt,
        endAt: endAt,
        expiresAt: expiresAt,
        total: total,
        paid: paid,
        status: BookingStatus.hold,
        extras: extras,
        paymentMethod: paymentMethod,
        pin: pin,
        createdAt: DateTime.now().toUtc(),
      );
    } catch (_) {
      return _fallback.createHoldBooking(
        userId: userId,
        venueId: venueId,
        venueName: venueName,
        courtNumber: courtNumber,
        date: date,
        hours: hours,
        total: total,
        paid: paid,
        extras: extras,
        paymentMethod: paymentMethod,
      );
    }
  }

  @override
  Future<void> confirmBooking(String bookingId) async {
    try {
      await _db.collection(bookingsCollection).doc(bookingId).update({
        'status': 'CONFIRMED',
      });
    } catch (_) {
      await _fallback.confirmBooking(bookingId);
    }
  }

  @override
  Future<void> cancelBooking({
    required String bookingId,
    required String userId,
  }) async {
    try {
      final doc = await _db.collection(bookingsCollection).doc(bookingId).get();
      if (!doc.exists) {
        throw const AuthException('Không tìm thấy vé đặt.', statusCode: 404);
      }
      final booking = BookingModel.fromJson(doc.data()!, id: doc.id);
      if (booking.userId != userId) {
        throw const AuthException('Bạn không có quyền hủy vé này.', statusCode: 403);
      }
      if (!booking.canCancel) {
        throw const AuthException(
          'Chỉ có thể hủy vé trước giờ thi đấu ít nhất 4 tiếng.',
          statusCode: 400,
        );
      }
      await _db.collection(bookingsCollection).doc(bookingId).update({
        'status': 'CANCELLED',
      });
    } catch (e) {
      if (e is AuthException) rethrow;
      await _fallback.cancelBooking(bookingId: bookingId, userId: userId);
    }
  }
}
