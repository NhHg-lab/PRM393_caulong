import 'package:flutter/material.dart';

import 'screens/admin_dashboard.dart';
import 'screens/auth_screen.dart';
import 'screens/customer_app.dart';
import 'theme/app_theme.dart';

void main() => runApp(const CourtlyApp());

class CourtlyApp extends StatefulWidget {
  const CourtlyApp({super.key});

  @override
  State<CourtlyApp> createState() => _CourtlyAppState();
}

class _CourtlyAppState extends State<CourtlyApp> {
  AppDestination _destination = AppDestination.auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Courtly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: switch (_destination) {
        AppDestination.auth => AuthScreen(
          onCustomerLogin: () =>
              setState(() => _destination = AppDestination.customer),
          onAdminLogin: () =>
              setState(() => _destination = AppDestination.admin),
        ),
        AppDestination.customer => CustomerApp(
          onLogout: () => setState(() => _destination = AppDestination.auth),
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

enum AppDestination { auth, customer, admin }
