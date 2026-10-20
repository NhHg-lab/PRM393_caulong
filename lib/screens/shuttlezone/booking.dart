import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shared.dart';

class VenueDetailScreen extends StatefulWidget {
  const VenueDetailScreen({
    super.key,
    required this.venue,
    required this.tickets,
    required this.onBooked,
    this.initialDate,
  });
  final Venue venue;
  final List<DemoTicket> tickets;
  final ValueChanged<DemoTicket> onBooked;
  final DateTime? initialDate;
  @override
  State<VenueDetailScreen> createState() => _VenueDetailScreenState();
}

class _VenueDetailScreenState extends State<VenueDetailScreen> {
  late DateTime _date;
  int _court = 1;
  final _hours = <int>{};
  @override
  void initState() {
    super.initState();
    _date =
        widget.initialDate ??
        DateUtils.dateOnly(DateTime.now().add(const Duration(days: 1)));
  }

  bool _unavailable(int hour) =>
      DateTime(
        _date.year,
        _date.month,
        _date.day,
        hour,
      ).isBefore(DateTime.now()) ||
      hour == 15 ||
      hour == 18 ||
      widget.tickets.any(
        (t) =>
            !t.cancelled &&
            t.selection.venue.id == widget.venue.id &&
            t.selection.court == _court &&
            DateUtils.isSameDay(t.selection.date, _date) &&
            t.selection.hours.contains(hour),
      );
  CourtSelection get _selection => CourtSelection(
    venue: widget.venue,
    date: _date,
    court: _court,
    hours: _hours,
  );
  void _select(int hour) {
    final next = {..._hours};
    next.contains(hour) ? next.remove(hour) : next.add(hour);
    if (next.isNotEmpty) {
      final sorted = next.toList()..sort();
      if (sorted.last - sorted.first + 1 != sorted.length) {
        szNotice(context, 'Vui lòng chọn các khung giờ liền nhau.');
        return;
      }
    }
    setState(() {
      _hours.clear();
      _hours.addAll(next);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết sân')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              VenuePhoto(widget.venue, height: 230),
              const Positioned(
                top: 12,
                left: 12,
                child: SzTag('✓ Chuẩn BWF thi đấu', color: szLime),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          widget.venue.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        SzLine(Icons.location_on_outlined, widget.venue.address),
        SzLine(
          Icons.star_rounded,
          '${widget.venue.rating} • Mở cửa 05:00 - 23:00',
        ),
        Text(
          'Mức giá: ${formatVnd(widget.venue.price)} - ${formatVnd(widget.venue.priceAt(19))}/giờ',
          style: const TextStyle(color: szGreen, fontWeight: FontWeight.w700),
        ),
        const SzHeading('Tiện ích cụm sân'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...widget.venue.tags,
            'Cho thuê vợt',
            'Nước giải khát',
            'Tắm nóng lạnh',
          ].map((t) => SzTag(t)).toList(),
        ),
        SzHeading(
          'Chọn ngày thi đấu',
          action: szDate(_date),
          onTap: () async {
            final today = DateUtils.dateOnly(DateTime.now());
            final picked = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: today,
              lastDate: today.add(const Duration(days: 60)),
            );
            if (picked != null && mounted) {
              setState(() {
                _date = picked;
                _hours.clear();
              });
            }
          },
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    showCheckmark: false,
                    selectedColor: szLime,
                    label: Text(
                      '${i == 0
                          ? 'Hôm nay'
                          : i == 1
                          ? 'Ngày mai'
                          : 'Ngày ${DateTime.now().add(Duration(days: i)).day}'}\n${szDate(DateTime.now().add(Duration(days: i))).substring(0, 5)}',
                      textAlign: TextAlign.center,
                    ),
                    selected: DateUtils.isSameDay(
                      _date,
                      DateTime.now().add(Duration(days: i)),
                    ),
                    onSelected: (_) => setState(() {
                      _date = DateUtils.dateOnly(
                        DateTime.now().add(Duration(days: i)),
                      );
                      _hours.clear();
                    }),
                  ),
                ),
            ],
          ),
        ),
        const SzHeading('Chọn thảm sân'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 1; i <= 4; i++)
              ChoiceChip(
                key: Key('court-$i'),
                label: Text('Sân $i${i == 3 ? ' • Thảm đỏ' : ' • Thảm xanh'}'),
                selected: _court == i,
                selectedColor: szLime,
                onSelected: (_) => setState(() {
                  _court = i;
                  _hours.clear();
                }),
              ),
          ],
        ),
        const SzHeading('Lưới khung giờ'),
        const Text(
          'Chọn một hoặc nhiều giờ liền kề • Giá theo giờ',
          style: TextStyle(fontSize: 12, color: szMuted),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (_, constraints) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var hour = 6; hour < 23; hour++)
                SizedBox(
                  width: (constraints.maxWidth - 10) / 2,
                  child: Semantics(
                    button: true,
                    selected: _hours.contains(hour),
                    enabled: !_unavailable(hour),
                    child: OutlinedButton(
                      key: Key('slot-$hour'),
                      onPressed: _unavailable(hour)
                          ? null
                          : () => _select(hour),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                          horizontal: 6,
                        ),
                        backgroundColor: _unavailable(hour)
                            ? szSoft
                            : _hours.contains(hour)
                            ? szLime
                            : Colors.white,
                        side: BorderSide(
                          color: _hours.contains(hour)
                              ? szGreen
                              : Colors.transparent,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${szHour(hour)} - ${szHour(hour + 1)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _unavailable(hour)
                                ? 'Hết chỗ / đã qua'
                                : _hours.contains(hour)
                                ? '✓ Đang chọn'
                                : 'Khả dụng',
                            style: const TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatVnd(widget.venue.priceAt(hour)),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SzPanel(
          color: Color(0xFFE9F3D8),
          child: Text(
            '🏸 Chọn giờ liền kề để có thêm thời gian giao lưu cùng đồng đội.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          demoDisclaimer,
          style: TextStyle(fontSize: 11, color: szMuted),
        ),
      ],
    ),
    bottomNavigationBar: SzBottomBar(
      label: _hours.isEmpty
          ? 'Chưa chọn khung giờ'
          : 'Sân $_court • ${_hours.length} giờ',
      amount: _hours.isEmpty ? 0 : _selection.rent,
      button: 'Tiếp tục đặt sân',
      buttonKey: const Key('continue-to-payment'),
      onPressed: _hours.isEmpty
          ? null
          : () async {
              // Availability is checked again after returning from checkout.
              if (_hours.any(_unavailable)) {
                setState(() => _hours.clear());
                return;
              }
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              final created = await szPush<bool>(
                context,
                CheckoutScreen(
                  selection: _selection,
                  onBooked: widget.onBooked,
                ),
              );
              if (created == true && context.mounted) {
                Navigator.of(context).pop();
              }
            },
    ),
  );
}

class SzBottomBar extends StatelessWidget {
  const SzBottomBar({
    super.key,
    required this.label,
    required this.amount,
    required this.button,
    required this.onPressed,
    this.buttonKey,
  });
  final String label, button;
  final int amount;
  final VoidCallback? onPressed;
  final Key? buttonKey;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 6,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: szMuted),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatVnd(amount),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: buttonKey,
                onPressed: onPressed,
                child: Text(button),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    required this.selection,
    required this.onBooked,
    this.now,
  });
  final CourtSelection selection;
  final ValueChanged<DemoTicket> onBooked;
  final DateTime Function()? now;
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _rackets = 2, _method = 0;
  bool _shuttles = true,
      _drink = false,
      _full = false,
      _voucher = true,
      _submitted = false;
  late final DateTime _expires;
  late final Timer _timer;
  DateTime _now() => widget.now?.call() ?? DateTime.now();
  int get _seconds => _expires.difference(_now()).inSeconds.clamp(0, 900);
  int get _addons =>
      _rackets * 30000 + (_shuttles ? 220000 : 0) + (_drink ? 15000 : 0);
  int get _total => widget.selection.rent + _addons - (_voucher ? 30000 : 0);
  int get _payable => _full ? _total : (_total / 2).ceil();
  static const _methods = [
    'VietQR / Chuyển khoản 247',
    'Ví MoMo',
    'Apple Pay / Visa, Mastercard',
  ];
  @override
  void initState() {
    super.initState();
    _expires = _now().add(const Duration(minutes: 15));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xác nhận đặt lịch')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: SzTag(
            _seconds > 0
                ? '⏱ Thời gian chọn: ${_seconds ~/ 60}:${(_seconds % 60).toString().padLeft(2, '0')} • Demo'
                : 'Phiên chọn đã hết hạn',
            color: const Color(0xFFE9F3D8),
          ),
        ),
        const SizedBox(height: 16),
        SzPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.selection.venue.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              SzLine(
                Icons.sports_tennis,
                'Sân ${widget.selection.court} • Chuẩn BWF',
              ),
              SzLine(Icons.calendar_today, szDate(widget.selection.date)),
              SzLine(Icons.schedule, widget.selection.time),
              SzLine(
                Icons.location_on_outlined,
                widget.selection.venue.address,
              ),
            ],
          ),
        ),
        const SzHeading('Dịch vụ & Phụ kiện thêm'),
        SzPanel(
          child: Column(
            children: [
              const SzLine(
                Icons.sports_tennis,
                'Vợt Yonex Astrox 88D • 30.000đ/cây',
              ),
              Row(
                children: [
                  IconButton(
                    key: const Key('racket-minus'),
                    tooltip: 'Bớt vợt',
                    onPressed: _rackets == 0
                        ? null
                        : () => setState(() => _rackets--),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$_rackets',
                    key: const Key('racket-count'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    key: const Key('racket-plus'),
                    tooltip: 'Thêm vợt',
                    onPressed: _rackets == 8
                        ? null
                        : () => setState(() => _rackets++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Ống cầu Thành Công',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text('220.000đ / 12 quả'),
                value: _shuttles,
                onChanged: (v) => setState(() => _shuttles = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Nước Pocari Sweat',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: const Text('15.000đ / chai'),
                value: _drink,
                onChanged: (v) => setState(() => _drink = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SzPanel(
          color: const Color(0xFFE9F3D8),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'BADMINTONFIRST',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('Ưu đãi demo: giảm 30.000đ'),
            value: _voucher,
            onChanged: (v) => setState(() => _voucher = v),
          ),
        ),
        const SzHeading('Chi tiết giá thanh toán'),
        SzPanel(
          child: Column(
            children: [
              _priceLine(
                'Tiền thuê sân (${widget.selection.hours.length} giờ)',
                widget.selection.rent,
              ),
              _priceLine('Phụ kiện thêm', _addons),
              _priceLine('Khuyến mãi', _voucher ? -30000 : 0),
              const Divider(height: 28),
              _priceLine('Tổng tiền dịch vụ', _total, bold: true),
            ],
          ),
        ),
        const SzHeading('Hình thức thanh toán'),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Cọc 50%')),
            ButtonSegment(value: true, label: Text('Toàn bộ 100%')),
          ],
          selected: {_full},
          onSelectionChanged: (v) => setState(() => _full = v.first),
        ),
        const SzHeading('Phương thức thanh toán'),
        for (var i = 0; i < _methods.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SzPanel(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  [
                    Icons.qr_code_scanner,
                    Icons.account_balance_wallet_outlined,
                    Icons.credit_card,
                  ][i],
                  color: szGreen,
                ),
                title: Text(
                  _methods[i],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Mô phỏng • Không kết nối cổng thanh toán',
                  style: TextStyle(fontSize: 10),
                ),
                trailing: Icon(
                  _method == i ? Icons.check_circle : Icons.circle_outlined,
                  color: _method == i ? szGreen : szMuted,
                ),
                onTap: () => setState(() => _method = i),
              ),
            ),
          ),
        const SzHeading('Chính sách hủy sân linh hoạt'),
        const Text(
          cancellationPolicy,
          style: TextStyle(height: 1.6, fontSize: 13, color: szMuted),
        ),
        const SizedBox(height: 16),
        const Text(
          demoDisclaimer,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: szGreen,
          ),
        ),
      ],
    ),
    bottomNavigationBar: SzBottomBar(
      label: _full ? 'Thanh toán toàn bộ (demo)' : 'Đặt cọc 50% (demo)',
      amount: _payable,
      buttonKey: const Key('pay-button'),
      button: _seconds == 0
          ? 'Hết hạn • Quay lại chọn giờ'
          : 'Tạo vé demo • ${formatVnd(_payable)}',
      onPressed: _seconds == 0 || _submitted ? null : _submit,
    ),
  );
  Widget _priceLine(String label, int amount, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          formatVnd(amount),
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    ),
  );
  Future<void> _submit() async {
    if (_submitted || _seconds == 0) return;
    setState(() => _submitted = true);
    _timer.cancel();
    final ticket = DemoTicket(
      selection: widget.selection,
      total: _total,
      paid: _payable,
      method: _methods[_method],
      extras: [
        '$_rackets vợt',
        if (_shuttles) '1 ống cầu',
        if (_drink) '1 chai Pocari',
      ].join(' • '),
    );
    widget.onBooked(ticket);
    await szPush(context, TicketScreen(ticket: ticket, newlyCreated: true));
    if (mounted) Navigator.of(context).pop(true);
  }
}

class TicketScreen extends StatefulWidget {
  const TicketScreen({
    super.key,
    required this.ticket,
    this.newlyCreated = false,
  });
  final DemoTicket ticket;
  final bool newlyCreated;
  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  @override
  Widget build(BuildContext context) {
    final t = widget.ticket;
    return Scaffold(
      appBar: AppBar(title: const Text('Vé điện tử')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(
            child: Icon(Icons.check_circle, size: 64, color: szGreen),
          ),
          const SizedBox(height: 12),
          Text(
            t.cancelled
                ? 'Vé đã hủy'
                : widget.newlyCreated
                ? 'Đặt sân thành công!'
                : 'Sẵn sàng ra sân!',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Vé mô phỏng • Không có giá trị nhận sân thật',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: szMuted),
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: const Color(0xFF2D3133),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CỤM SÂN CHUẨN QUỐC TẾ',
                        style: TextStyle(
                          color: szLime,
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        t.selection.venue.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sân ${t.selection.court.toString().padLeft(2, '0')} • Thảm tiêu chuẩn BWF',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      SzLine(Icons.calendar_today, szDate(t.selection.date)),
                      SzLine(Icons.schedule, t.selection.time),
                      const Divider(height: 30),
                      const Text(
                        'MÃ PIN NHẬN SÂN DEMO',
                        style: TextStyle(
                          fontSize: 11,
                          color: szMuted,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        t.pin,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 12,
                        ),
                      ),
                      Text(
                        t.id,
                        style: const TextStyle(fontSize: 10, color: szMuted),
                      ),
                      const Divider(height: 30),
                      SzLine(Icons.shopping_bag_outlined, t.extras),
                      SzLine(
                        Icons.payments_outlined,
                        'Tổng chi phí: ${formatVnd(t.total)}',
                      ),
                      SzLine(Icons.check_circle_outline, t.paymentLabel),
                      if (t.total > t.paid)
                        SzLine(
                          Icons.account_balance_wallet_outlined,
                          'Còn lại: ${formatVnd(t.total - t.paid)} (demo)',
                        ),
                      SzLine(Icons.credit_card, t.method),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SzHeading('Tiện ích ra sân nhanh'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: t.selection.venue.address),
                  );
                  if (context.mounted) {
                    szNotice(
                      context,
                      'Đã sao chép địa chỉ để tìm trên Google Maps.',
                    );
                  }
                },
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('Sao chép địa chỉ'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text:
                          'Vé DEMO ${t.id}\n${t.selection.venue.name} • Sân ${t.selection.court}\n${szDate(t.selection.date)} • ${t.selection.time}\n${t.selection.venue.address}\nKhông có giá trị nhận sân thật.',
                    ),
                  );
                  if (context.mounted) {
                    szNotice(context, 'Đã sao chép thông tin vé demo.');
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Sao chép vé'),
              ),
            ],
          ),
          const SzHeading('Vị trí nhà thi đấu'),
          SzPanel(
            child: SzLine(Icons.pin_drop_outlined, t.selection.venue.address),
          ),
          const SzHeading('Chính sách hủy sân'),
          const Text(
            cancellationPolicy,
            style: TextStyle(fontSize: 13, color: szMuted, height: 1.6),
          ),
          const SizedBox(height: 18),
          if (!t.cancelled)
            OutlinedButton(
              onPressed: t.canCancel
                  ? () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Hủy vé demo?'),
                          content: const Text(
                            'Khung giờ sẽ được mở lại trong phiên này.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, false),
                              child: const Text('Giữ vé'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext, true),
                              child: const Text('Hủy vé'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && mounted) {
                        setState(() => t.cancelled = true);
                      }
                    }
                  : null,
              child: Text(
                t.canCancel ? 'Hủy vé demo' : 'Đã qua thời hạn hủy miễn phí',
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('success-home-button'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hoàn tất'),
          ),
          const SizedBox(height: 12),
          const Text(
            demoDisclaimer,
            style: TextStyle(fontSize: 11, color: szMuted),
          ),
        ],
      ),
    );
  }
}
