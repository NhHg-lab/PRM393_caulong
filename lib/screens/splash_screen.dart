import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Hiển thị trong lúc AuthManager khôi phục phiên đăng nhập.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(light: true),
            SizedBox(height: 14),
            Text(
              'Đặt sân nhanh, vào trận đúng giờ.',
              style: TextStyle(color: Color(0xFFB9C7D2), fontSize: 14),
            ),
            SizedBox(height: 36),
            SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.lime,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
