import 'package:courtly/main.dart';
import 'package:courtly/screens/splash_screen.dart';
import 'package:courtly/services/auth_manager.dart';
import 'package:courtly/services/auth_service.dart';
import 'package:courtly/services/session_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemorySessionStorage storage;

  setUp(() {
    storage = MemorySessionStorage();
    AuthManager.instance = AuthManager(
      service: MockAuthService(latency: Duration.zero),
      storage: storage,
    );
  });

  Future<void> startApp(WidgetTester tester) async {
    await tester.pumpWidget(const CourtlyApp());
    await tester.pumpAndSettle();
  }

  Future<void> enterCredentials(
    WidgetTester tester,
    String identifier,
    String password,
  ) async {
    await tester.enterText(
      find.byKey(const Key('auth-identifier-field')),
      identifier,
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      password,
    );
  }

  Future<void> tapPrimary(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const Key('auth-primary-button')));
    await tester.tap(find.byKey(const Key('auth-primary-button')));
    await tester.pumpAndSettle();
  }

  testWidgets('starts on Splash then shows the login screen', (tester) async {
    await tester.pumpWidget(const CourtlyApp());
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.text('Sân xịn đang\nchờ bạn.'), findsOneWidget);
    // Không còn lối tắt vào trang quản trị cho người chưa đăng nhập.
    expect(find.text('Vào trang quản trị'), findsNothing);
  });

  testWidgets('shows validation errors for malformed input', (tester) async {
    await startApp(tester);
    await enterCredentials(tester, 'demo@courtly', '123');
    await tapPrimary(tester);

    expect(find.text('Email không đúng định dạng'), findsOneWidget);
    expect(find.text('Mật khẩu tối thiểu 6 ký tự'), findsOneWidget);
    expect(AuthManager.instance.isAuthenticated, isFalse);
  });

  testWidgets('wrong password shows an error SnackBar', (tester) async {
    await startApp(tester);
    await enterCredentials(tester, 'demo@courtly.vn', 'sai-mat-khau');
    await tapPrimary(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Sân xịn đang\nchờ bạn.'), findsOneWidget);
  });

  testWidgets('customer logs in, sees profile, cannot open admin, logs out', (
    tester,
  ) async {
    await startApp(tester);
    await enterCredentials(tester, 'demo@courtly.vn', '123456');
    await tapPrimary(tester);

    expect(find.text('Sân gần bạn'), findsOneWidget);
    expect(find.byKey(const Key('quick-book-button')), findsOneWidget);

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    expect(find.text('Hoàng Nam'), findsOneWidget);
    expect(find.text('demo@courtly.vn'), findsOneWidget);
    expect(find.byKey(const Key('open-admin-button')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('logout-button')));
    await tester.tap(find.byKey(const Key('logout-button')));
    await tester.pumpAndSettle();
    expect(find.text('Sân xịn đang\nchờ bạn.'), findsOneWidget);
    expect(await storage.read(), isNull);
  });

  testWidgets('admin account goes straight to the admin dashboard', (
    tester,
  ) async {
    await startApp(tester);
    await tester.ensureVisible(find.byKey(const Key('admin-login-button')));
    await tester.tap(find.byKey(const Key('admin-login-button')));
    await tester.pump();
    await tapPrimary(tester);

    expect(find.text('COURTLY ADMIN'), findsOneWidget);
    expect(find.text('Doanh thu hôm nay'), findsOneWidget);
  });

  testWidgets('demo button signs in with the demo account', (tester) async {
    await startApp(tester);
    await tester.ensureVisible(find.byKey(const Key('demo-login-button')));
    await tester.tap(find.byKey(const Key('demo-login-button')));
    await tester.pumpAndSettle();

    expect(find.text('Sân gần bạn'), findsOneWidget);
  });

  testWidgets('a stored session opens Home directly on next launch', (
    tester,
  ) async {
    final service = MockAuthService(latency: Duration.zero);
    await storage.save(await service.login(service.demoAccount));

    await startApp(tester);
    expect(find.text('Sân gần bạn'), findsOneWidget);
  });

  testWidgets('Google button reports that it is not configured', (
    tester,
  ) async {
    await startApp(tester);
    await tester.ensureVisible(find.byKey(const Key('google-login-button')));
    await tester.tap(find.byKey(const Key('google-login-button')));
    await tester.pump();

    expect(find.text('Đăng nhập Google chưa được cấu hình'), findsOneWidget);
  });
}
