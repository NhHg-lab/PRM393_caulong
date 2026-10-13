import 'dart:convert';

import 'package:courtly/models/auth_models.dart';
import 'package:courtly/services/firebase_direct_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('FirebaseOtpAuthService gửi email đúng endpoint backend', () async {
    late http.Request seen;
    final service = FirebaseOtpAuthService(
      apiBaseUrl: 'http://test/api',
      client: MockClient((request) async {
        seen = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'message': 'Đã gửi mã OTP',
              'expiresIn': 300,
              'resendAfter': 60,
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final sent = await service.sendRegisterOtp(' User@Example.com ');

    expect(seen.method, 'POST');
    expect(seen.url.path, '/api/auth/firebase/register/send-otp');
    expect(jsonDecode(seen.body), {'email': 'User@Example.com'});
    expect(sent.expiresIn, 300);
    expect(sent.resendAfter, 60);
  });

  test('FirebaseOtpAuthService giữ thông báo lỗi của backend', () async {
    final service = FirebaseOtpAuthService(
      apiBaseUrl: 'http://test/api',
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode({'message': 'Email đã được sử dụng'})),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      service.sendRegisterOtp('used@example.com'),
      throwsA(
        isA<AuthException>()
            .having((error) => error.statusCode, 'statusCode', 409)
            .having((error) => error.message, 'message', contains('sử dụng')),
      ),
    );
  });
}
