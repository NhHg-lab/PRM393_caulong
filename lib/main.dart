import 'package:flutter/material.dart';

import 'screens/admin_dashboard.dart';
import 'screens/auth_screen.dart';
import 'screens/customer_app.dart';
import 'screens/splash_screen.dart';
import 'services/auth_manager.dart';
import 'services/firebase_auth_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Chỉ khởi tạo Firebase khi AppConfig.enableGoogleSignIn = true.
  await initFirebaseIfEnabled();
  // Không chờ: khởi tạo thông báo chạy song song với Splash.
  NotificationService.instance.initialize();
  runApp(const CourtlyApp());
}

class CourtlyApp extends StatefulWidget {
  const CourtlyApp({super.key});

  @override
  State<CourtlyApp> createState() => _CourtlyAppState();
}

class _CourtlyAppState extends State<CourtlyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _auth = AuthManager.instance;
  AuthStatus _lastStatus = AuthStatus.unknown;

  /// Màn đang chọn sau khi đã đăng nhập (customer hoặc admin).
  AppDestination _signedInDestination = AppDestination.customer;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
    _auth.restoreSession();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    final status = _auth.status;
    if (status == _lastStatus) return;
    _lastStatus = status;
    // Đổi trạng thái đăng nhập thì đóng mọi trang con đang mở (ví dụ màn đặt sân),
    // để người dùng không thể back về màn của phiên cũ.
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (status == AuthStatus.authenticated) {
      _signedInDestination = _auth.isAdmin
          ? AppDestination.admin
          : AppDestination.customer;
    }
  }

  /// Tính màn hiện tại từ trạng thái AuthManager. Admin chỉ vào được khi isAdmin.
  AppDestination get _destination => switch (_auth.status) {
    AuthStatus.unknown => AppDestination.splash,
    AuthStatus.unauthenticated => AppDestination.auth,
    AuthStatus.authenticated =>
      _signedInDestination == AppDestination.admin && _auth.isAdmin
          ? AppDestination.admin
          : AppDestination.customer,
  };

  void _go(AppDestination destination) =>
      setState(() => _signedInDestination = destination);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, _) => MaterialApp(
        title: 'Courtly',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        // Thay `home` thay vì push nên không thể back về Splash/Login.
        home: switch (_destination) {
          AppDestination.splash => const SplashScreen(),
          AppDestination.auth => const AuthScreen(),
          AppDestination.customer => CustomerApp(
            user: _auth.currentUser!,
            onLogout: _auth.logout,
            onOpenAdmin: _auth.isAdmin ? () => _go(AppDestination.admin) : null,
          ),
          AppDestination.admin => AdminDashboard(
            onExit: () => _go(AppDestination.customer),
          ),
        },
      ),
    );
  }
}

enum AppDestination { splash, auth, customer, admin }
