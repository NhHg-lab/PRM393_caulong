import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:courtly/models/auth_models.dart';
import 'package:courtly/services/registration_otp_client.dart';

void main() {
  const request = SignupRequest(
    fullName: ' Test Player ',
    email: ' player@example.com ',
    password: 'Secret@123',
    otp: '123456',
  );
  test('OTP request trims email and preserves backend timers', () async {
    final client = RegistrationOtpClient(
      client: MockClient((r) async {
        expect(r.url.path, '/api/auth/register/send-otp');
        expect(jsonDecode(r.body), {'email': 'player@example.com'});
        return http.Response(
          '{"message":"sent","expiresIn":120,"resendAfter":30}',
          200,
        );
      }),
    );
    final sent = await client.send(' player@example.com ');
    expect(sent.expiresIn, 120);
    expect(sent.resendAfter, 30);
  });
  for (final status in [200, 201]) {
    test('registration accepts $status and sends no role', () async {
      final client = RegistrationOtpClient(
        client: MockClient((r) async {
          expect(r.url.path, '/api/auth/register/firebase');
          final data = jsonDecode(r.body) as Map;
          expect(data['fullName'], 'Test Player');
          expect(data['otp'], '123456');
          expect(data.containsKey('role'), false);
          return http.Response('{"message":"created"}', status);
        }),
      );
      await client.register(request);
    });
  }
  for (final status in [400, 409, 429, 503]) {
    test('send OTP maps HTTP $status', () async {
      final client = RegistrationOtpClient(
        client: MockClient(
          (_) async => http.Response('{"message":"failure"}', status),
        ),
      );
      await expectLater(
        client.send('p@example.com'),
        throwsA(
          isA<AuthException>().having((e) => e.statusCode, 'status', status),
        ),
      );
    });
  }
  for (final body in [
    '<html>',
    '[]',
    '{}',
    '{"message":"ok","expiresIn":"bad","resendAfter":0}',
  ]) {
    test('malformed OTP response is controlled: $body', () async {
      final client = RegistrationOtpClient(
        client: MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        client.send('p@example.com'),
        throwsA(isA<AuthException>()),
      );
    });
  }
  test('ambiguous creation is never retried', () async {
    for (final response in [
      http.Response('', 201),
      http.Response('{}', 200),
      http.Response('bad', 503),
    ]) {
      var calls = 0;
      final client = RegistrationOtpClient(
        client: MockClient((_) async {
          calls++;
          return response;
        }),
      );
      await expectLater(
        client.register(request),
        throwsA(same(RegistrationOtpClient.uncertainRegistration)),
      );
      expect(calls, 1);
    }
  });
  test('timeout and network failure are controlled without retry', () async {
    for (final error in [
      TimeoutException('test'),
      http.ClientException('test'),
    ]) {
      var calls = 0;
      final client = RegistrationOtpClient(
        client: MockClient((_) async {
          calls++;
          throw error;
        }),
      );
      await expectLater(
        client.register(request),
        throwsA(same(RegistrationOtpClient.uncertainRegistration)),
      );
      expect(calls, 1);
      await expectLater(
        client.send('p@example.com'),
        throwsA(isA<AuthException>()),
      );
    }
  });
  test('invalid OTP does not send request', () async {
    final client = RegistrationOtpClient(
      client: MockClient((_) async => fail('must not send')),
    );
    await expectLater(
      client.register(request.copyWith(otp: 'bad')),
      throwsA(isA<AuthException>()),
    );
  });
}
