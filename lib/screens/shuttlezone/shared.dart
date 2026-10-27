import 'package:flutter/material.dart';

import '../../widgets/common_widgets.dart' show formatVnd;

export '../../widgets/common_widgets.dart' show formatVnd;

const szLime = Color(0xFF84CC16);
const szGreen = Color(0xFF416900);
const szInk = Color(0xFF191C1E);
const szMuted = Color(0xFF626859);
const szSurface = Color(0xFFF7F9FB);
const szSoft = Color(0xFFECEEF0);

ThemeData shuttleTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'PlusJakartaSans',
  colorScheme: ColorScheme.fromSeed(seedColor: szGreen)
      .copyWith(primary: szGreen, secondary: szLime, surface: szSurface),
  scaffoldBackgroundColor: szSurface,
  appBarTheme: const AppBarTheme(
    backgroundColor: szSurface,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: szLime,
    height: 70,
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: szLime,
      foregroundColor: Color(0xFF315200),
      minimumSize: const Size(0, 48),
      textStyle: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: szSoft,
    contentPadding: const EdgeInsets.all(15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  ),
);

Future<T?> szPush<T>(BuildContext context, Widget page) => Navigator.of(context)
    .push<T>(
      MaterialPageRoute(
        builder: (_) => Theme(data: shuttleTheme(), child: page),
      ),
    );

void szNotice(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

class SzPanel extends StatelessWidget {
  const SzPanel({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .035),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

class SzHeading extends StatelessWidget {
  const SzHeading(this.title, {super.key, this.action, this.onTap});
  final String title;
  final String? action;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 12),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: szLime,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onTap,
            child: Text(action!, style: const TextStyle(fontSize: 12)),
          ),
      ],
    ),
  );
}

class SzTag extends StatelessWidget {
  const SzTag(
    this.text, {
    super.key,
    this.color = szSoft,
    this.foreground = szInk,
  });
  final String text;
  final Color color;
  final Color foreground;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    ),
  );
}

class SzLine extends StatelessWidget {
  const SzLine(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(icon, size: 18, color: szGreen),
        const SizedBox(width: 9),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
        ),
      ],
    ),
  );
}

class Venue {
  const Venue(
    this.id,
    this.name,
    this.address,
    this.district,
    this.price,
    this.rating,
    this.tags,
  );
  final int id;
  final String name, address, district;
  final int price;
  final double rating;
  final List<String> tags;
  int priceAt(int hour) => price + (hour >= 17 && hour < 22 ? 30000 : 0);
}

const venues = [
  Venue(
    0,
    'SkyBadminton Club',
    '152 Nguyễn Thị Thập, P. Bình Thuận, Quận 7',
    'Quận 7',
    90000,
    4.9,
    ['Máy lạnh', 'Thảm BWF', 'Bãi đỗ ô tô'],
  ),
  Venue(
    1,
    'Victory Arena',
    '340 Hoàng Văn Thụ, Tân Bình',
    'Tân Bình',
    100000,
    4.8,
    ['Thảm BWF', 'Bãi đỗ ô tô', 'Mở 24/7'],
  ),
  Venue(
    2,
    'CLB Cầu Lông Victor Pro',
    'Đường số 7, Tân Phong, Quận 7',
    'Quận 7',
    80000,
    4.7,
    ['Máy lạnh', 'Thảm BWF'],
  ),
];

String szDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String szHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

class CourtSelection {
  CourtSelection({
    required this.venue,
    required this.date,
    required this.court,
    required Set<int> hours,
  }) : hours = List.unmodifiable(hours.toList()..sort());
  final Venue venue;
  final DateTime date;
  final int court;
  final List<int> hours;
  int get rent => hours.fold(0, (sum, hour) => sum + venue.priceAt(hour));
  DateTime get startsAt =>
      DateTime(date.year, date.month, date.day, hours.first);
  String get time =>
      '${szHour(hours.first)} - ${szHour(hours.last + 1)} (${hours.length} giờ)';
}

class DemoTicket {
  DemoTicket({
    required this.selection,
    required this.total,
    required this.paid,
    required this.extras,
    required this.method,
  }) : id = 'SZ-${DateTime.now().microsecondsSinceEpoch}';
  final String id;
  final CourtSelection selection;
  final int total, paid;
  final String extras, method;
  bool cancelled = false;
  bool get canCancel =>
      !cancelled &&
      selection.startsAt.difference(DateTime.now()) >= const Duration(hours: 4);
  String get pin => id.substring(id.length - 4);
  String get paymentLabel => paid == total
      ? 'Đã thanh toán đủ (demo)'
      : 'Đã cọc ${formatVnd(paid)} (demo)';
}

class VenuePhoto extends StatelessWidget {
  const VenuePhoto(this.venue, {super.key, this.height = 180});
  final Venue venue;
  final double height;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/shuttlezone/court${venue.id}.jpg',
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (_, error, stackTrace) => Container(
      height: height,
      color: const Color(0xFF006C49),
      alignment: Alignment.center,
      child: const Icon(Icons.sports_tennis, color: szLime, size: 64),
    ),
  );
}

const demoDisclaimer =
    'Chế độ demo • Không thu tiền thật. Dữ liệu đặt sân và ghép kèo chỉ lưu trong phiên này.';
const cancellationPolicy =
    'Hủy miễn phí trước giờ thi đấu ít nhất 4 tiếng. Vé demo không phát sinh giao dịch hoặc hoàn tiền thật.';
