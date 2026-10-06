import 'dart:convert';

import 'package:courtly/models/auth_models.dart';
import 'package:courtly/services/api_client.dart';
import 'package:courtly/services/auth_manager.dart';
import 'package:courtly/services/auth_service.dart';
import 'package:courtly/services/session_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('MockAuthService', () {
    late MockAuthService service;
    setUp(() => service = MockAuthService(latency: Duration.zero));

    test('logs in the demo customer by email or phone', () async {
      final byEmail = await service.login(
        const LoginRequest(identifier: 'DEMO@courtly.vn', password: '123456'),
      );
      expect(byEmail.user.role, UserRole.customer);
      expect(byEmail.accessToken, isNotEmpty);
      expect(byEmail.isExpired, isFalse);

      final byPhone = await service.login(
        const LoginRequest(identifier: '0912345678', password: '123456'),
      );
      expect(byPhone.user.email, MockAuthService.demoEmail);
    });

    test('logs in the admin account with admin role', () async {
      final session = await service.login(
        const LoginRequest(
          identifier: MockAuthService.adminEmail,
          password: MockAuthService.adminPassword,
        ),
      );
      expect(session.user.isAdmin, isTrue);
    });

    test('rejects a wrong password with a 401 AuthException', () async {
      expect(
        () => service.login(
          const LoginRequest(identifier: 'demo@courtly.vn', password: 'wrong!'),
        ),
        throwsA(
          isA<AuthException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test(
      'signup creates an account that can log in, duplicates fail',
      () async {
        const request = SignupRequest(
          fullName: 'Trần An',
          email: 'an@courtly.vn',
          password: 'Abcd1234',
          otp: MockAuthService.otpCode,
        );
        final session = await service.signup(request);
        expect(session.user.fullName, 'Trần An');
        await service.login(
          const LoginRequest(identifier: 'an@courtly.vn', password: 'Abcd1234'),
        );
        expect(
          () => service.signup(request),
          throwsA(
            isA<AuthException>().having((e) => e.statusCode, 'statusCode', 409),
          ),
        );
      },
    );

    test(
      'signup is rejected without the right OTP, accepted with it',
      () async {
        const request = SignupRequest(
          fullName: 'Lê Bình',
          email: 'binh@courtly.vn',
          password: 'Abcd1234',
        );
        await expectLater(
          service.signup(request.copyWith(otp: '000000')),
          throwsA(
            isA<AuthException>().having((e) => e.statusCode, 'statusCode', 400),
          ),
        );
        final session = await service.signup(
          request.copyWith(otp: MockAuthService.otpCode),
        );
        expect(session.user.email, 'binh@courtly.vn');
      },
    );

    test('sendRegisterOtp: new email ok, registered email -> 409', () async {
      expect(service.requiresSignupOtp, isTrue);
      final sent = await service.sendRegisterOtp('moi@courtly.vn');
      expect(sent.resendAfter, greaterThan(0));
      expect(sent.expiresIn, greaterThan(0));
      await expectLater(
        service.sendRegisterOtp(MockAuthService.demoEmail),
        throwsA(
          isA<AuthException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test(
      'password reset OTP looks the same for known and unknown emails',
      () async {
        expect(service.supportsPasswordReset, isTrue);
        final known = await service.sendPasswordResetOtp(
          MockAuthService.demoEmail,
        );
        final unknown = await service.sendPasswordResetOtp('la@courtly.vn');
        expect(unknown.message, known.message);
        expect(unknown.expiresIn, known.expiresIn);
        expect(unknown.resendAfter, known.resendAfter);
        expect(known.message, contains(MockAuthService.otpCode));
      },
    );

    test('resetPassword with the right OTP changes the password', () async {
      await service.resetPassword(
        email: ' DEMO@courtly.vn ',
        otp: MockAuthService.otpCode,
        newPassword: 'Moi12345',
      );
      final session = await service.login(
        const LoginRequest(identifier: 'demo@courtly.vn', password: 'Moi12345'),
      );
      expect(session.user.email, MockAuthService.demoEmail);
      await expectLater(
        service.login(
          const LoginRequest(
            identifier: 'demo@courtly.vn',
            password: MockAuthService.demoPassword,
          ),
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test(
      'resetPassword: wrong OTP and unknown email give the same 400',
      () async {
        Matcher sameError() => throwsA(
          isA<AuthException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e.message,
                'message',
                'Mã OTP không hợp lệ hoặc đã hết hạn.',
              ),
        );
        await expectLater(
          service.resetPassword(
            email: MockAuthService.demoEmail,
            otp: '000000',
            newPassword: 'Moi12345',
          ),
          sameError(),
        );
        await expectLater(
          service.resetPassword(
            email: 'la@courtly.vn',
            otp: MockAuthService.otpCode,
            newPassword: 'Moi12345',
          ),
          sameError(),
        );
        // Mật khẩu cũ vẫn dùng được vì chưa reset thành công.
        await service.login(service.demoAccount);
      },
    );

    test('refresh issues a new token for a mock refresh token', () async {
      final session = await service.login(service.demoAccount);
      final renewed = await service.refresh(session);
      expect(renewed.user.id, session.user.id);
      expect(
        () => service.refresh(session.copyWith(refreshToken: 'bogus')),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('AuthManager', () {
    late MemorySessionStorage storage;
    late AuthManager manager;
    setUp(() {
      storage = MemorySessionStorage();
      manager = AuthManager(
        service: MockAuthService(latency: Duration.zero),
        storage: storage,
      );
    });

    test('restoreSession without stored session -> unauthenticated', () async {
      expect(manager.status, AuthStatus.unknown);
      await manager.restoreSession();
      expect(manager.status, AuthStatus.unauthenticated);
    });

    test('login with remember persists the session', () async {
      await manager.login('demo@courtly.vn', '123456');
      expect(manager.isAuthenticated, isTrue);
      expect(manager.isAdmin, isFalse);
      expect(await storage.read(), isNotNull);
    });

    test('login without remember keeps the session in memory only', () async {
      await manager.login('demo@courtly.vn', '123456', remember: false);
      expect(manager.isAuthenticated, isTrue);
      expect(await storage.read(), isNull);
    });

    test('restoreSession refreshes an expired session', () async {
      await manager.login('admin@courtly.vn', 'Admin@123');
      final stored = (await storage.read())!;
      await storage.save(
        stored.copyWith(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );

      final reopened = AuthManager(
        service: MockAuthService(latency: Duration.zero),
        storage: storage,
      );
      await reopened.restoreSession();
      expect(reopened.isAdmin, isTrue);
      expect(reopened.session!.isExpired, isFalse);
    });

    test('logout clears memory and storage', () async {
      await manager.login('demo@courtly.vn', '123456');
      await manager.logout();
      expect(manager.status, AuthStatus.unauthenticated);
      expect(manager.currentUser, isNull);
      expect(await storage.read(), isNull);
    });
  });

  group('ApiClient', () {
    late AuthManager manager;
    setUp(() async {
      manager = AuthManager(
        service: MockAuthService(latency: Duration.zero),
        storage: MemorySessionStorage(),
      );
      await manager.login('demo@courtly.vn', '123456');
    });

    test(
      'sends Bearer token and retries once after refreshing on 401',
      () async {
        final firstToken = manager.session!.accessToken;
        final seenTokens = <String?>[];
        final client = MockClient((request) async {
          seenTokens.add(request.headers['Authorization']);
          return seenTokens.length == 1
              ? http.Response('', 401)
              : http.Response(jsonEncode({'ok': true}), 200);
        });

        final api = ApiClient(
          client: client,
          auth: manager,
          baseUrl: 'http://x',
        );
        final json = await api.getJson('/users/me');

        expect(json['ok'], isTrue);
        expect(seenTokens.first, 'Bearer $firstToken');
        expect(seenTokens.last, isNot(seenTokens.first));
        expect(manager.isAuthenticated, isTrue);
      },
    );

    test('logs out when the request is still 401 after refreshing', () async {
      final client = MockClient((_) async => http.Response('', 401));
      final api = ApiClient(client: client, auth: manager, baseUrl: 'http://x');

      await expectLater(api.get('/users/me'), throwsA(isA<AuthException>()));
      expect(manager.status, AuthStatus.unauthenticated);
    });
  });

  group('SpringAuthService OTP registration', () {
    const authJson = {
      'accessToken': 'access',
      'refreshToken': 'refresh',
      'tokenType': 'Bearer',
      'expiresIn': 1800,
      'user': {
        'id': 'u1',
        'fullName': 'Tran An',
        'email': 'an@courtly.vn',
        'phone': null,
        'role': 'CUSTOMER',
        'avatarUrl': null,
        'authProvider': 'LOCAL',
      },
    };

    test('send-otp then register with the code in the body', () async {
      final calls = <String>[];
      Map<String, dynamic>? sendBody;
      Map<String, dynamic>? registerBody;
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('/auth/register/send-otp')) {
          sendBody = body;
          return http.Response(
            jsonEncode({
              'message': 'Da gui ma OTP toi an@courtly.vn',
              'expiresIn': 300,
              'resendAfter': 60,
            }),
            200,
          );
        }
        registerBody = body;
        return http.Response(jsonEncode(authJson), 201);
      });
      final service = SpringAuthService(
        client: client,
        apiBaseUrl: 'http://test/api',
      );

      expect(service.requiresSignupOtp, isTrue);
      final sent = await service.sendRegisterOtp(' an@courtly.vn ');
      expect(sent.expiresIn, 300);
      expect(sent.resendAfter, 60);
      expect(sendBody, {'email': 'an@courtly.vn'});

      final session = await service.signup(
        const SignupRequest(
          fullName: 'Tran An',
          email: 'an@courtly.vn',
          password: 'Abcd1234',
          otp: '123456',
        ),
      );
      expect(session.accessToken, 'access');
      expect(registerBody?['otp'], '123456');
      expect(registerBody?['email'], 'an@courtly.vn');
      expect(calls, [
        'POST /api/auth/register/send-otp',
        'POST /api/auth/register',
      ]);
    });

    test(
      'server errors surface as AuthException with the server message',
      () async {
        final client = MockClient(
          (request) async => http.Response(
            jsonEncode({
              'status': 429,
              'error': 'Too Many Requests',
              'message': 'Vui long doi 30 giay truoc khi yeu cau ma moi',
            }),
            429,
          ),
        );
        final service = SpringAuthService(
          client: client,
          apiBaseUrl: 'http://test/api',
        );
        await expectLater(
          service.sendRegisterOtp('an@courtly.vn'),
          throwsA(
            isA<AuthException>()
                .having((e) => e.statusCode, 'statusCode', 429)
                .having((e) => e.message, 'message', contains('30 giay')),
          ),
        );
      },
    );
  });

  group('SpringAuthService password reset', () {
    test(
      'forgot then reset hit the contract endpoints with the right bodies',
      () async {
        final calls = <String>[];
        final bodies = <Map<String, dynamic>>[];
        final client = MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (request.url.path.endsWith('/auth/password/forgot')) {
            return http.Response(
              jsonEncode({
                'message': 'Neu email ton tai, ma OTP da duoc gui',
                'expiresIn': 600,
                'resendAfter': 45,
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'message': 'Da doi mat khau'}), 200);
        });
        final service = SpringAuthService(
          client: client,
          apiBaseUrl: 'http://test/api',
        );

        expect(service.supportsPasswordReset, isTrue);
        final sent = await service.sendPasswordResetOtp(' an@courtly.vn ');
        expect(sent.expiresIn, 600);
        expect(sent.resendAfter, 45);
        await service.resetPassword(
          email: 'an@courtly.vn',
          otp: '123456',
          newPassword: 'Moi12345',
        );

        expect(calls, [
          'POST /api/auth/password/forgot',
          'POST /api/auth/password/reset',
        ]);
        expect(bodies.first, {'email': 'an@courtly.vn'});
        expect(bodies.last, {
          'email': 'an@courtly.vn',
          'otp': '123456',
          'newPassword': 'Moi12345',
        });
      },
    );

    SpringAuthService failingWith(int status, String message) =>
        SpringAuthService(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'status': status, 'message': message}),
              status,
            ),
          ),
          apiBaseUrl: 'http://test/api',
        );

    test('429 on forgot surfaces the server wait message', () async {
      final service = failingWith(429, 'Vui long doi 45 giay');
      await expectLater(
        service.sendPasswordResetOtp('an@courtly.vn'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.message, 'message', contains('45 giay')),
        ),
      );
    });

    test('400 on reset surfaces the server message', () async {
      final service = failingWith(400, 'Ma OTP khong hop le hoac da het han');
      await expectLater(
        service.resetPassword(
          email: 'an@courtly.vn',
          otp: '000000',
          newPassword: 'Moi12345',
        ),
        throwsA(
          isA<AuthException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', contains('OTP')),
        ),
      );
    });
  });

  test('DummyJsonAuthService does not support password reset', () {
    expect(DummyJsonAuthService().supportsPasswordReset, isFalse);
  });

  test('AuthException.fromHttp prefers the server message', () {
    final error = AuthException.fromHttp(
      400,
      jsonEncode({
        'status': 400,
        'message': 'Email đã tồn tại',
        'fieldErrors': {'email': 'Email đã tồn tại'},
      }),
    );
    expect(error.message, 'Email đã tồn tại');
    expect(error.fieldErrors, {'email': 'Email đã tồn tại'});
    expect(AuthException.fromHttp(500, 'oops').statusCode, 500);
  });
}
