// SDK types are mocked only to test service boundaries; production never subclasses them.
// ignore_for_file: subtype_of_sealed_class

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:courtly/models/auth_models.dart';
import 'package:courtly/services/auth_manager.dart';
import 'package:courtly/services/auth_service.dart';
import 'package:courtly/services/firebase_direct_auth_service.dart';
import 'package:courtly/services/google_token_provider.dart';
import 'package:courtly/services/session_storage.dart';
import 'package:courtly/services/registration_otp_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthMock extends Mock implements fb.FirebaseAuth {}

class UserMock extends Mock implements fb.User {}

class DbMock extends Mock implements FirebaseFirestore {}

class CollectionMock extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class DocumentMock extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class SnapshotMock extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class ServiceMock extends Mock implements AuthService {}

class GoogleMock extends Mock implements GoogleTokenProvider {}

class OtpMock extends Mock implements RegistrationOtpClient {}

class CredentialMock extends Mock implements fb.UserCredential {}

class SecureMock extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final session = AuthSession(
    accessToken: 'token',
    refreshToken: null,
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
    user: const AppUser(
      id: 'uid',
      fullName: 'Admin Player',
      email: 'p@example.com',
      role: UserRole.admin,
      authProvider: 'GOOGLE',
    ),
  );
  setUpAll(() {
    registerFallbackValue(session);
    registerFallbackValue(const LoginRequest(identifier: '', password: ''));
  });
  test('legacy and different-mode stored sessions are removed', () async {
    for (final mode in [null, 'firebase', 'spring']) {
      SharedPreferences.setMockInitialValues({
        'auth_token': 'token',
        'expires_at': session.expiresAt.toIso8601String(),
        'user_profile': jsonEncode(session.user.toJson()),
        'auth_mode': ?mode,
      });
      expect(await PrefsSessionStorage().read(), isNull);
      expect(
        (await SharedPreferences.getInstance()).getString('auth_token'),
        isNull,
      );
    }
  });
  test('current-mode session survives storage roundtrip', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = PrefsSessionStorage();
    await storage.save(session);
    expect((await storage.read())!.user.id, 'uid');
  });
  test('secure storage rejects legacy and foreign-mode sessions', () async {
    for (final mode in [null, 'firebase']) {
      final secure = SecureMock();
      when(() => secure.read(key: 'auth_mode')).thenAnswer((_) async => mode);
      when(() => secure.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});
      expect(await SecureSessionStorage(secure).read(), isNull);
      verify(() => secure.delete(key: 'access_token')).called(1);
    }
  });
  test(
    'offline restored ADMIN cannot open admin, including after refresh',
    () async {
      final service = ServiceMock();
      when(() => service.fetchProfile(any())).thenThrow(AuthException.network);
      when(() => service.refresh(any())).thenAnswer((_) async => session);
      final storage = MemorySessionStorage();
      await storage.save(session);
      final manager = AuthManager(service: service, storage: storage);
      await manager.restoreSession();
      expect(manager.isAuthenticated, true);
      expect(manager.isAdmin, false);
      await manager.refreshSession();
      expect(manager.isAdmin, false);
    },
  );
  test(
    'backend logout failure still clears storage and Google provider',
    () async {
      final service = ServiceMock();
      final google = GoogleMock();
      when(() => google.obtainIdToken()).thenAnswer((_) async => 'google');
      when(() => google.signOut()).thenAnswer((_) async {});
      when(() => service.loginWithGoogleIdToken('google'))
          .thenAnswer((_) async => session);
      when(() => service.logout(any())).thenThrow(Exception('offline'));
      final storage = MemorySessionStorage();
      final manager = AuthManager(service: service, storage: storage);
      await manager.loginWithGoogle(provider: google);
      await manager.logout();
      expect(manager.isAuthenticated, false);
      expect(await storage.read(), isNull);
      verify(() => google.signOut()).called(1);
    },
  );
  test(
    'remember false does not restore even when SDK could retain a user',
    () async {
      final service = ServiceMock();
      when(() => service.login(any())).thenAnswer((_) async => session);
      registerFallbackValue(const LoginRequest(identifier: '', password: ''));
      final storage = MemorySessionStorage();
      final manager = AuthManager(service: service, storage: storage);
      await manager.login('p@example.com', 'password', remember: false);
      final restarted = AuthManager(service: service, storage: storage);
      await restarted.restoreSession();
      expect(restarted.isAuthenticated, false);
      verifyNever(() => service.fetchProfile(any()));
    },
  );
  group('Firebase restore', () {
    late AuthMock auth;
    late UserMock user;
    late DbMock db;
    late DocumentMock document;
    late SnapshotMock snapshot;
    late FirebaseDirectAuthService service;
    setUp(() {
      auth = AuthMock();
      user = UserMock();
      db = DbMock();
      final collection = CollectionMock();
      document = DocumentMock();
      snapshot = SnapshotMock();
      when(() => auth.currentUser).thenReturn(user);
      when(() => user.uid).thenReturn('uid');
      when(() => user.email).thenReturn('p@example.com');
      when(() => db.collection('users')).thenReturn(collection);
      when(() => collection.doc('uid')).thenReturn(document);
      when(() => document.get(const GetOptions(source: Source.server)))
          .thenAnswer((_) async => snapshot);
      service = FirebaseDirectAuthService(auth: auth, firestore: db);
    });
    test('UID mismatch invalidates restore and refresh', () async {
      when(() => user.uid).thenReturn('other');
      await expectLater(
        service.fetchProfile(session),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        service.refresh(session),
        throwsA(isA<AuthException>()),
      );
      verifyNever(() => db.collection(any()));
    });
    test('missing profile clears saved admin session', () async {
      when(() => snapshot.exists).thenReturn(false);
      final storage = MemorySessionStorage();
      await storage.save(session);
      final manager = AuthManager(service: service, storage: storage);
      await manager.restoreSession();
      expect(manager.isAuthenticated, false);
      expect(await storage.read(), isNull);
    });
    test('server-confirmed admin profile is accepted', () async {
      when(() => snapshot.exists).thenReturn(true);
      when(() => snapshot.data()).thenReturn(session.user.toJson());
      final storage = MemorySessionStorage();
      await storage.save(session);
      final manager = AuthManager(service: service, storage: storage);
      await manager.restoreSession();
      expect(manager.isAdmin, true);
    });
    test('malformed profile is controlled and denied', () async {
      when(() => snapshot.exists).thenReturn(true);
      when(() => snapshot.data()).thenReturn({'role': 'ADMIN'});
      await expectLater(
        service.fetchProfile(session),
        throwsA(
          isA<AuthException>().having((e) => e.statusCode, 'status', 403),
        ),
      );
    });
    test(
      'signup provisions through Spring, then signs in and loads profile',
      () async {
        const request = SignupRequest(
          fullName: 'Player',
          email: 'p@example.com',
          password: 'Secret@123',
          otp: '123456',
        );
        final otp = OtpMock();
        final credential = CredentialMock();
        final order = <String>[];
        when(() => otp.register(request)).thenAnswer((_) async {
          order.add('backend');
        });
        when(
          () => auth.signInWithEmailAndPassword(
            email: request.email,
            password: request.password,
          ),
        ).thenAnswer((_) async {
          order.add('firebase');
          return credential;
        });
        when(() => credential.user).thenReturn(user);
        when(() => snapshot.exists).thenReturn(true);
        when(() => snapshot.data()).thenReturn({
          ...session.user.toJson(),
          'role': 'CUSTOMER',
          'authProvider': 'LOCAL',
        });
        when(() => user.getIdToken()).thenAnswer((_) async => 'firebase-token');
        final service = FirebaseDirectAuthService(
          auth: auth,
          firestore: db,
          registrationClient: otp,
        );
        final result = await service.signup(request);
        expect(order, ['backend', 'firebase']);
        expect(result.user.isAdmin, false);
        expect(result.accessToken, 'firebase-token');
        verifyNever(
          () => auth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        );
      },
    );
    test(
      'post-registration sign-in failure is uncertain and cleans SDK session',
      () async {
        const request = SignupRequest(
          fullName: 'Player',
          email: 'p@example.com',
          password: 'Secret@123',
          otp: '123456',
        );
        final otp = OtpMock();
        when(() => otp.register(request)).thenAnswer((_) async {});
        when(
          () => auth.signInWithEmailAndPassword(
            email: request.email,
            password: request.password,
          ),
        ).thenThrow(fb.FirebaseAuthException(code: 'network-request-failed'));
        when(() => auth.signOut()).thenAnswer((_) async {});
        final service = FirebaseDirectAuthService(
          auth: auth,
          firestore: db,
          registrationClient: otp,
        );
        await expectLater(
          service.signup(request),
          throwsA(same(RegistrationOtpClient.uncertainRegistration)),
        );
        verify(() => otp.register(request)).called(1);
        verify(() => auth.signOut()).called(1);
      },
    );
    test('password reset link delegates through manager to injected Firebase service', () async {
      when(() => auth.sendPasswordResetEmail(email: 'p@example.com'))
          .thenAnswer((_) async {});
      final manager = AuthManager(
        service: service,
        storage: MemorySessionStorage(),
      );
      await manager.sendPasswordResetLink(' p@example.com ');
      verify(() => auth.sendPasswordResetEmail(email: 'p@example.com'))
          .called(1);
    });
  });
}
