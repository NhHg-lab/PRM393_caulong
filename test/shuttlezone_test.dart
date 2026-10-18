import 'dart:io';
import 'dart:ui' as ui;

import 'package:courtly/models/auth_models.dart';
import 'package:courtly/screens/shuttlezone/customer_app.dart';
import 'package:courtly/screens/shuttlezone/shared.dart';
import 'package:courtly/screens/shuttlezone/booking.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans')
      ..addFont(rootBundle.load('assets/shuttlezone/PlusJakartaSans.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  const user = AppUser(
    id: 'demo',
    fullName: 'Nguyễn Văn Kim',
    email: 'kim@example.com',
  );
  final captureKey = GlobalKey();
  Future<void> start(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: CustomerApp(user: user, onLogout: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('SHUTTLE_PREVIEWS')) return;
    await tester.pump();
    await tester.runAsync(() async {
      final boundary =
          captureKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/shuttlezone/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        250,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  test('selection sorts hours and uses individual hourly rates', () {
    final selection = CourtSelection(
      venue: venues.first,
      date: DateTime(2026, 10, 20),
      court: 2,
      hours: {17, 16},
    );
    expect(selection.hours, [16, 17]);
    expect(selection.rent, 210000);
    expect(selection.time, '16:00 - 18:00 (2 giờ)');
    final ticket = DemoTicket(
      selection: selection,
      total: 490000,
      paid: 245000,
      extras: '2 vợt',
      method: 'VietQR',
    );
    expect(ticket.paymentLabel, contains('245.000đ'));
  });

  testWidgets(
    'booking carries selected date, court, addons, full payment into a cancellable ticket',
    (tester) async {
      await start(tester);
      await capture(tester, '01-home');
      await tester.tap(find.byKey(const Key('quick-book-button')));
      await tester.pumpAndSettle();
      await capture(tester, '02-detail');
      await tapVisible(tester, find.byKey(const Key('court-2')));
      await tapVisible(tester, find.byKey(const Key('slot-19')));
      await tapVisible(tester, find.byKey(const Key('slot-21')));
      expect(
        find.text('Vui lòng chọn các khung giờ liền nhau.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.byKey(const Key('slot-20')));
      await tapVisible(tester, find.byKey(const Key('continue-to-payment')));
      await capture(tester, '03-checkout');
      // 240k rent + 60k rackets + 220k shuttles - 30k voucher.
      expect(find.text('Tạo vé demo • 245.000đ'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('racket-plus')));
      expect(find.text('Tạo vé demo • 260.000đ'), findsOneWidget);
      await tapVisible(tester, find.text('Toàn bộ 100%'));
      expect(find.text('Tạo vé demo • 520.000đ'), findsOneWidget);
      await tapVisible(tester, find.byKey(const Key('pay-button')));
      expect(find.text('Đặt sân thành công!'), findsOneWidget);
      expect(find.text('Sân 02 • Thảm tiêu chuẩn BWF'), findsOneWidget);
      expect(find.text('Đã thanh toán đủ (demo)'), findsOneWidget);
      expect(find.text('3 vợt • 1 ống cầu'), findsOneWidget);
      expect(find.text('Tổng chi phí: 520.000đ'), findsOneWidget);
      await capture(tester, '04-ticket');
      await tapVisible(tester, find.text('Hủy vé demo'));
      await tester.tap(find.text('Hủy vé', skipOffstage: false));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TicketScreen>(find.byType(TicketScreen)).ticket.cancelled,
        isTrue,
      );
      await tapVisible(tester, find.byKey(const Key('success-home-button')));
      await tester.tap(find.text('Lịch & Vé'));
      await tester.pumpAndSettle();
      expect(find.text('ĐÃ HỦY'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search and amenity filters change results; matchmaking join and leave works',
    (tester) async {
      await start(tester, width: 360);
      await tester.tap(find.text('Tìm sân'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('venue-search')), 'Victory');
      await tester.pumpAndSettle();
      expect(find.text('Kết quả tìm sân (1)'), findsOneWidget);
      await tester.tap(find.text('Máy lạnh').first);
      await tester.pumpAndSettle();
      expect(find.text('Kết quả tìm sân (0)'), findsOneWidget);
      await tester.tap(find.text('Ghép kèo'));
      await tester.pumpAndSettle();
      await capture(tester, '05-matchmaking');
      await tapVisible(tester, find.text('Tham gia kèo demo →').first);
      await tester.tap(find.text('Tham gia', skipOffstage: false));
      await tester.pumpAndSettle();
      expect(find.text('ĐÃ THAM GIA • DEMO'), findsOneWidget);
      await tapVisible(tester, find.text('Rời kèo demo'));
      expect(find.text('ĐÃ THAM GIA • DEMO'), findsNothing);
      await tester.tap(find.text('Tài khoản'));
      await tester.pumpAndSettle();
      expect(find.text(user.fullName), findsOneWidget);
      await capture(tester, '06-account');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new match form validates, creates and displays an owned match', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.text('Ghép kèo'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('create-match')));
    await tapVisible(tester, find.text('Tạo kèo demo'));
    expect(find.text('Nhập tên kèo ít nhất 5 ký tự'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Kèo giao lưu cuối tuần',
    );
    await tapVisible(tester, find.text('Tạo kèo demo'));
    expect(find.text('Kèo giao lưu cuối tuần'), findsOneWidget);
    expect(find.text('Bạn là chủ kèo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checkout expires and disables demo payment', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var currentTime = DateTime(2026, 10, 20, 12);
    await tester.pumpWidget(
      MaterialApp(
        theme: shuttleTheme(),
        home: CheckoutScreen(
          now: () => currentTime,
          selection: CourtSelection(
            venue: venues.first,
            date: DateTime.now().add(const Duration(days: 1)),
            court: 1,
            hours: {19},
          ),
          onBooked: (_) => fail('Expired checkout must not create a ticket'),
        ),
      ),
    );
    currentTime = currentTime.add(const Duration(minutes: 16));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('pay-button')))
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
