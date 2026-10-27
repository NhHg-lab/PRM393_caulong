import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth_models.dart';
import '../models/models.dart';
import 'api_client.dart';

class CourtApiService {
  CourtApiService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  static bool get isEnabled =>
      AppConfig.authMode == AuthMode.spring ||
      AppConfig.authMode == AuthMode.firebaseOtp;

  Future<List<Court>> courts() async =>
      _courtList(await _client.get('/courts'));

  Future<List<Court>> favorites() async =>
      _courtList(await _client.get('/favorites'));

  Future<void> setFavorite(String courtId, bool favorite) async {
    final response = favorite
        ? await _client.post('/favorites', body: {'courtId': courtId})
        : await _client.delete('/favorites/$courtId');
    _ensureSuccess(response.statusCode, _body(response));
  }

  Future<List<TimeSlot>> slots(String courtId, DateTime date) async {
    final day = _isoDate(date);
    final response = await _client.get('/courts/$courtId/slots?date=$day');
    return _list(
      response.statusCode,
      _body(response),
    ).map(TimeSlot.fromJson).toList(growable: false);
  }

  Future<List<Booking>> bookings() async {
    final response = await _client.get('/bookings');
    return _list(
      response.statusCode,
      _body(response),
    ).map(Booking.fromJson).toList(growable: false);
  }

  Future<Booking> createBooking({
    required String slotId,
    required String paymentMethod,
  }) async {
    final response = await _client.post(
      '/bookings',
      body: {'slotId': slotId, 'paymentMethod': paymentMethod},
    );
    return Booking.fromJson(_map(response.statusCode, _body(response)));
  }

  Future<Booking> cancelBooking(String id) async {
    final response = await _client.post('/bookings/$id/cancel');
    return Booking.fromJson(_map(response.statusCode, _body(response)));
  }

  Future<AppUser> updateProfile({
    required String fullName,
    String? phone,
  }) async {
    final response = await _client.patch(
      '/users/me',
      body: {'fullName': fullName, 'phone': phone},
    );
    return AppUser.fromJson(_map(response.statusCode, _body(response)));
  }

  Future<AdminOverview> overview() async {
    final response = await _client.get('/admin/overview');
    return AdminOverview.fromJson(_map(response.statusCode, _body(response)));
  }

  Future<List<AdminSlot>> adminSchedule(DateTime date) async {
    final response = await _client.get(
      '/admin/schedule?date=${_isoDate(date)}',
    );
    return _list(
      response.statusCode,
      _body(response),
    ).map(AdminSlot.fromJson).toList(growable: false);
  }

  Future<void> setSlotEnabled(String id, bool enabled) async {
    final response = await _client.patch(
      '/admin/slots/$id',
      body: {'enabled': enabled},
    );
    _ensureSuccess(response.statusCode, _body(response));
  }

  Future<List<Court>> adminCourts() async =>
      _courtList(await _client.get('/admin/courts'));

  Future<Court> createCourt(Map<String, dynamic> body) async {
    final response = await _client.post('/admin/courts', body: body);
    return Court.fromJson(_map(response.statusCode, _body(response)));
  }

  Future<Court> updateCourt(String id, Map<String, dynamic> body) async {
    final response = await _client.put('/admin/courts/$id', body: body);
    return Court.fromJson(_map(response.statusCode, _body(response)));
  }

  Future<void> setCourtActive(String id, bool enabled) async {
    final response = await _client.patch(
      '/admin/courts/$id/active',
      body: {'enabled': enabled},
    );
    _ensureSuccess(response.statusCode, _body(response));
  }

  Future<List<AdminAccount>> accounts() async {
    final response = await _client.get('/admin/accounts');
    return _list(
      response.statusCode,
      _body(response),
    ).map(AdminAccount.fromJson).toList(growable: false);
  }

  Future<void> setAccountEnabled(String id, bool enabled) async {
    final response = await _client.patch(
      '/admin/accounts/$id/enabled',
      body: {'enabled': enabled},
    );
    _ensureSuccess(response.statusCode, _body(response));
  }

  Future<List<Court>> _courtList(http.Response response) async => _list(
    response.statusCode,
    _body(response),
  ).map(Court.fromJson).toList(growable: false);
}

class AdminOverview {
  const AdminOverview({
    required this.bookingsToday,
    required this.upcomingBookings,
    required this.activeCourts,
    required this.accounts,
    required this.paidRevenue,
  });

  factory AdminOverview.fromJson(Map<String, dynamic> json) => AdminOverview(
    bookingsToday: (json['bookingsToday'] as num).toInt(),
    upcomingBookings: (json['upcomingBookings'] as num).toInt(),
    activeCourts: (json['activeCourts'] as num).toInt(),
    accounts: (json['accounts'] as num).toInt(),
    paidRevenue: (json['paidRevenue'] as num).toInt(),
  );

  final int bookingsToday;
  final int upcomingBookings;
  final int activeCourts;
  final int accounts;
  final int paidRevenue;
}

class AdminSlot {
  const AdminSlot({
    required this.id,
    required this.courtId,
    required this.courtName,
    required this.startTime,
    required this.status,
    this.bookingId,
    this.customerName,
    this.paymentStatus,
  });

  factory AdminSlot.fromJson(Map<String, dynamic> json) => AdminSlot(
    id: json['id'] as String,
    courtId: json['courtId'] as String,
    courtName: json['courtName'] as String,
    startTime: json['startTime'] as String,
    status: json['status'] as String,
    bookingId: json['bookingId'] as String?,
    customerName: json['customerName'] as String?,
    paymentStatus: json['paymentStatus'] as String?,
  );

  final String id;
  final String courtId;
  final String courtName;
  final String startTime;
  final String status;
  final String? bookingId;
  final String? customerName;
  final String? paymentStatus;
}

class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.authProvider,
    required this.enabled,
    required this.bookingCount,
    this.phone,
  });

  factory AdminAccount.fromJson(Map<String, dynamic> json) => AdminAccount(
    id: json['id'] as String,
    fullName: json['fullName'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    role: json['role'] as String,
    authProvider: json['authProvider'] as String,
    enabled: json['enabled'] as bool,
    bookingCount: (json['bookingCount'] as num).toInt(),
  );

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String role;
  final String authProvider;
  final bool enabled;
  final int bookingCount;
}

List<Map<String, dynamic>> _list(int status, String body) {
  _ensureSuccess(status, body);
  return (jsonDecode(body) as List<dynamic>).cast<Map<String, dynamic>>();
}

Map<String, dynamic> _map(int status, String body) {
  _ensureSuccess(status, body);
  return jsonDecode(body) as Map<String, dynamic>;
}

void _ensureSuccess(int status, String body) {
  if (status < 200 || status >= 300) {
    throw AuthException.fromHttp(status, body);
  }
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _body(http.Response response) => utf8.decode(response.bodyBytes);
