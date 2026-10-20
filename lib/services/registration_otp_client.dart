import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth_models.dart';

/// Spring only verifies registration OTP and provisions Firebase accounts.
/// Requests are deliberately never retried: creation may already have succeeded.
class RegistrationOtpClient {
  RegistrationOtpClient({
    http.Client? client,
    String? baseUrl,
    this.timeout = AppConfig.requestTimeout,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;
  final Duration timeout;

  static const uncertainRegistration = AuthException(
    'Chưa xác nhận được kết quả tạo tài khoản. Hãy thử đăng nhập hoặc đặt lại '
    'mật khẩu trước khi đăng ký lại.',
  );

  Future<OtpSent> send(String email) async {
    final data = await _post('/auth/register/send-otp', {
      'email': email.trim(),
    }, creating: false);
    if (data['message'] is! String ||
        data['expiresIn'] is! int ||
        data['resendAfter'] is! int ||
        (data['expiresIn'] as int) <= 0 ||
        (data['resendAfter'] as int) < 0) {
      throw const AuthException('Máy chủ trả về thông tin OTP không hợp lệ.');
    }
    return OtpSent.fromJson(data);
  }

  Future<void> register(SignupRequest request) async {
    if (!RegExp(r'^\d{6}$').hasMatch(request.otp ?? '')) {
      throw const AuthException(
        'Vui lòng nhập mã OTP gồm 6 chữ số.',
        statusCode: 400,
      );
    }
    final data = await _post('/auth/register/firebase', {
      ...request.toJson(),
      'email': request.email.trim(),
      'fullName': request.fullName.trim(),
    }, creating: true);
    if (data['message'] is! String) throw uncertainRegistration;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    required bool creating,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (creating && response.statusCode >= 500) throw uncertainRegistration;
        throw AuthException.fromHttp(response.statusCode, response.body);
      }
      if (response.statusCode != 200 &&
          !(creating && response.statusCode == 201)) {
        throw const FormatException();
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic>) throw const FormatException();
      return data;
    } on TimeoutException {
      throw creating ? uncertainRegistration : AuthException.timeout;
    } on http.ClientException {
      throw creating ? uncertainRegistration : AuthException.network;
    } on FormatException {
      throw creating
          ? uncertainRegistration
          : const AuthException('Máy chủ trả về dữ liệu không hợp lệ.');
    }
  }
}
