import 'package:courtly/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('customer can enter the demo experience', (tester) async {
    await tester.pumpWidget(const CourtlyApp());

    expect(find.text('Sân xịn đang\nchờ bạn.'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsWidgets);

    await tester.tap(find.byKey(const Key('auth-primary-button')));
    await tester.pumpAndSettle();

    expect(find.text('Sân gần bạn'), findsOneWidget);
    expect(find.byKey(const Key('quick-book-button')), findsOneWidget);
  });

  testWidgets('admin dashboard is accessible from sign in', (tester) async {
    await tester.pumpWidget(const CourtlyApp());

    await tester.ensureVisible(find.byKey(const Key('admin-login-button')));
    await tester.tap(find.byKey(const Key('admin-login-button')));
    await tester.pumpAndSettle();

    expect(find.text('COURTLY ADMIN'), findsOneWidget);
    expect(find.text('Doanh thu hôm nay'), findsOneWidget);
  });
}
