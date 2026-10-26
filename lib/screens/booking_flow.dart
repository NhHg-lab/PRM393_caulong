import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/models.dart';
import '../services/court_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class CourtBookingScreen extends StatefulWidget {
  const CourtBookingScreen({
    super.key,
    required this.court,
    required this.onBooked,
    this.useApi = false,
  });
  final Court court;
  final ValueChanged<Booking> onBooked;
  final bool useApi;

  @override
  State<CourtBookingScreen> createState() => _CourtBookingScreenState();
}

class _CourtBookingScreenState extends State<CourtBookingScreen> {
  final CourtApiService _api = CourtApiService();
  late final List<DateTime> _dates;
  late List<TimeSlot> _slots;
  int _date = 0;
  int? _slot;
  bool _loadingSlots = false;
  String? _slotError;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _dates = List.generate(
      7,
      (index) => DateTime(today.year, today.month, today.day + index),
    );
    _slots = widget.useApi ? <TimeSlot>[] : List.of(demoSlots);
    _slot = widget.useApi ? null : 7;
    if (widget.useApi) _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loadingSlots = true;
      _slotError = null;
      _slot = null;
    });
    try {
      final slots = await _api.slots(widget.court.id, _dates[_date]);
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _loadingSlots = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingSlots = false;
        _slotError = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = (widget.court.price * 1.5).round();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đặt sân'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.favorite_border_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 126),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: CourtArtwork(
              color: widget.court.accent,
              icon: widget.court.icon,
              height: 206,
              heroTag: 'court-${widget.court.id}',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.court.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(widget.court.address),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const StatusPill(label: '4.9 ★', color: AppColors.warning),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.court.tags
                .map((tag) => StatusPill(label: tag, color: AppColors.navy))
                .toList(),
          ),
          const SizedBox(height: 28),
          SectionHeading(
            title: 'Chọn ngày',
            subtitle: 'Tháng ${_dates[_date].month}, ${_dates[_date].year}',
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _dates.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final selected = _date == index;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setState(() => _date = index);
                    if (widget.useApi) _loadSlots();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 65,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.navy : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected ? AppColors.navy : AppColors.line,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _dayLabel(_dates[index], index),
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? Colors.white70 : AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _dates[index].day.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: selected ? Colors.white : AppColors.navyDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeading(
            title: 'Khung giờ còn trống',
            subtitle: 'Mỗi lượt kéo dài 90 phút',
          ),
          const SizedBox(height: 14),
          if (_loadingSlots)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_slotError != null)
            EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Không tải được khung giờ',
              message: _slotError!,
              action: OutlinedButton(
                onPressed: _loadSlots,
                child: const Text('Thử lại'),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.05,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _slots.length,
              itemBuilder: (context, index) {
                final slot = _slots[index];
                final selected = _slot == index;
                return InkWell(
                  onTap: slot.available
                      ? () => setState(() => _slot = index)
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: !slot.available
                          ? const Color(0xFFECEFF1)
                          : selected
                          ? AppColors.lime
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppColors.lime : AppColors.line,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      slot.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: slot.available
                            ? AppColors.navyDeep
                            : const Color(0xFFAFB8BF),
                        decoration: slot.available
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.muted,
              ),
              SizedBox(width: 6),
              Text(
                'Ô màu xám là khung giờ đã được đặt',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.paddingOf(context).bottom + 14,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tạm tính',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatVnd(price),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 188,
              child: FilledButton(
                key: const Key('continue-to-payment'),
                onPressed: _slot == null ? null : () => _openPayment(price),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Tiếp tục'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 19),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPayment(int price) async {
    final slot = _slots[_slot!];
    final date = _dates[_date];
    final booking = Booking(
      id: 'PENDING',
      court: widget.court,
      date:
          '${_dayLabel(date, _date)}, ${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/${date.year}',
      time:
          '${slot.label} – ${slot.endTime.isEmpty ? _endTime(slot.label) : slot.endTime}',
      total: price + 5000,
      status: BookingStatus.upcoming,
      slotId: slot.id,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          booking: booking,
          onPaid: widget.onBooked,
          useApi: widget.useApi,
        ),
      ),
    );
  }

  String _endTime(String start) {
    final parts = start.split(':');
    final minutes = int.parse(parts[0]) * 60 + int.parse(parts[1]) + 90;
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }

  String _dayLabel(DateTime date, int index) {
    if (index == 0) return 'Hôm nay';
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return labels[date.weekday - 1];
  }
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.booking,
    required this.onPaid,
    this.useApi = false,
  });
  final Booking booking;
  final ValueChanged<Booking> onPaid;
  final bool useApi;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  int _payment = 0;
  bool _paying = false;

  @override
  Widget build(BuildContext context) {
    final methods = [
      (
        Icons.account_balance_wallet_rounded,
        'Ví MoMo',
        'Thanh toán nhanh qua ví điện tử',
        const Color(0xFFD82D8B),
      ),
      (
        Icons.qr_code_2_rounded,
        'VNPay QR',
        'Quét mã bằng ứng dụng ngân hàng',
        AppColors.blue,
      ),
      (
        Icons.payments_outlined,
        'Thanh toán tại sân',
        'Giữ chỗ, trả tiền khi đến sân',
        AppColors.success,
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Thanh toán')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 130),
        children: [
          _BookingSummary(booking: widget.booking),
          const SizedBox(height: 26),
          const SectionHeading(
            title: 'Phương thức thanh toán',
            subtitle: 'Chọn một phương thức bên dưới',
          ),
          const SizedBox(height: 14),
          ...List.generate(methods.length, (index) {
            final method = methods[index];
            final selected = _payment == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _payment = index),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? AppColors.navy : AppColors.line,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: method.$4.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(method.$1, color: method.$4),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              method.$2,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              method.$3,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? AppColors.navy : Colors.transparent,
                          border: Border.all(
                            color: selected ? AppColors.navy : AppColors.line,
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 15,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.limeSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, color: AppColors.success),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Thanh toán của bạn được mã hóa và bảo vệ. Courtly không lưu thông tin ngân hàng.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.paddingOf(context).bottom + 14,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: FilledButton(
          key: const Key('pay-button'),
          onPressed: _paying ? null : _pay,
          child: _paying
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Thanh toán ${formatVnd(widget.booking.total)}'),
        ),
      ),
    );
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      const methods = ['MOMO', 'VNPAY', 'AT_COURT'];
      final booking = widget.useApi
          ? await CourtApiService().createBooking(
              slotId: widget.booking.slotId!,
              paymentMethod: methods[_payment],
            )
          : widget.booking;
      widget.onPaid(booking);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(booking: booking),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thanh toán/đặt sân thất bại: $error')),
      );
      setState(() => _paying = false);
    }
  }
}

class _BookingSummary extends StatelessWidget {
  const _BookingSummary({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: booking.court.accent.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(booking.court.icon, color: booking.court.accent),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.court.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.court.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            _SummaryLine(
              icon: Icons.calendar_month_outlined,
              label: booking.date,
            ),
            const SizedBox(height: 11),
            _SummaryLine(icon: Icons.schedule_rounded, label: booking.time),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('Phí nền tảng'), Text('5.000đ')],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng cộng',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  formatVnd(booking.total),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 19, color: AppColors.muted),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    ],
  );
}

class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key, required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: AppColors.lime,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lime.withValues(alpha: .4),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 58,
                  color: AppColors.navyDeep,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Đặt sân thành công!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              const Text(
                'Lịch chơi đã được xác nhận. Hẹn gặp bạn trên sân!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'MÃ ĐẶT SÂN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.muted,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            booking.id,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.blue,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),
                      Text(
                        booking.court.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _SummaryLine(
                        icon: Icons.calendar_month_outlined,
                        label: booking.date,
                      ),
                      const SizedBox(height: 10),
                      _SummaryLine(
                        icon: Icons.schedule_rounded,
                        label: booking.time,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                key: const Key('success-home-button'),
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Về trang chủ'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('Thêm vào lịch'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
