import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/admin_dashboard.dart';
import 'screens/auth_screen.dart';
import 'screens/customer_app.dart';
import 'services/auth_gateway.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    runApp(CourtlyApp(authGateway: FirebaseCourtlyAuthGateway()));
  } catch (error) {
    runApp(FirebaseStartupErrorApp(message: error.toString()));
  }
}

class CourtlyApp extends StatefulWidget {
  const CourtlyApp({super.key, this.authGateway = const DemoAuthGateway()});

  final AuthGateway authGateway;

  @override
  State<CourtlyApp> createState() => _CourtlyAppState();
}

class _CourtlyAppState extends State<CourtlyApp> {
  AppDestination _destination = AppDestination.loading;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    AuthSession? session;
    try {
      session = await widget.authGateway.restoreSession();
    } catch (_) {
      session = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _destination = session == null
          ? AppDestination.auth
          : session.isAdmin
          ? AppDestination.admin
          : AppDestination.customer;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Courtly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: switch (_destination) {
        AppDestination.loading => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        AppDestination.auth => AuthScreen(
          authGateway: widget.authGateway,
          onAuthenticated: (session) => setState(
            () => _destination = session.isAdmin
                ? AppDestination.admin
                : AppDestination.customer,
          ),
          onDemoCustomer: () =>
              setState(() => _destination = AppDestination.customer),
          onDemoAdmin: () =>
              setState(() => _destination = AppDestination.admin),
        ),
        AppDestination.customer => CustomerApp(
          onLogout: () async {
            await widget.authGateway.signOut();
            if (mounted) {
              setState(() => _destination = AppDestination.auth);
            }
          },
          onOpenAdmin: () =>
              setState(() => _destination = AppDestination.admin),
        ),
        AppDestination.admin => AdminDashboard(
          onExit: () => setState(() => _destination = AppDestination.customer),
        ),
      },
    );
  }
}

enum AppDestination { loading, auth, customer, admin }

class FirebaseStartupErrorApp extends StatelessWidget {
  const FirebaseStartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    'Không khởi tạo được Firebase',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Kiểm tra google-services.json rồi khởi động lại ứng dụng.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
