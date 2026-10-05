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
