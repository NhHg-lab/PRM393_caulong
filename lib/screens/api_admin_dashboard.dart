import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/court_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class ApiAdminDashboard extends StatefulWidget {
  const ApiAdminDashboard({super.key, required this.onExit});
  final VoidCallback onExit;

  @override
  State<ApiAdminDashboard> createState() => _ApiAdminDashboardState();
}

class _ApiAdminDashboardState extends State<ApiAdminDashboard> {
  final CourtApiService _api = CourtApiService();
  int _tab = 0;
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    const titles = ['Tổng quan', 'Lịch đặt', 'Quản lý sân', 'Tài khoản'];
    final pages = [
      _Overview(api: _api, version: _version),
      _Schedule(api: _api, version: _version),
      _Courts(api: _api, version: _version, refresh: _refresh),
      _Accounts(api: _api, version: _version, refresh: _refresh),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navyDeep,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: widget.onExit,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titles[_tab],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'COURTLY ADMIN',
              style: TextStyle(
                color: AppColors.lime,
                fontSize: 9,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: _tab == 2
          ? FloatingActionButton.extended(
              onPressed: _addCourt,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm sân'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Lịch đặt',
          ),
          NavigationDestination(
            icon: Icon(Icons.stadium_outlined),
            label: 'Sân',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }

  void _refresh() => setState(() => _version++);

  Future<void> _addCourt() async {
    final name = TextEditingController();
    final address = TextEditingController();
    final price = TextEditingController(text: '120000');
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thêm sân mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Tên sân'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá mỗi giờ'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tạo sân'),
          ),
        ],
      ),
    );
    final courtName = name.text.trim();
    final courtAddress = address.text.trim();
    final courtPrice = int.tryParse(price.text) ?? 120000;
    name.dispose();
    address.dispose();
    price.dispose();
    if (result != true || !mounted) return;
    try {
      await _api.createCourt({
        'name': courtName,
        'address': courtAddress,
        'pricePerHour': courtPrice,
        'distanceLabel': '--',
        'tags': <String>[],
      });
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không tạo được sân: $error')));
      }
    }
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.api, required this.version});
  final CourtApiService api;
  final int version;

  @override
  Widget build(BuildContext context) => _FutureBody<AdminOverview>(
    key: ValueKey(version),
    future: api.overview(),
    builder: (data) => GridView.count(
      padding: const EdgeInsets.all(18),
      crossAxisCount: 2,
      childAspectRatio: 1.25,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _Metric('Đơn hôm nay', '${data.bookingsToday}', Icons.today_rounded),
        _Metric(
          'Đơn sắp tới',
          '${data.upcomingBookings}',
          Icons.event_available_rounded,
        ),
        _Metric('Sân hoạt động', '${data.activeCourts}', Icons.stadium_rounded),
        _Metric('Tài khoản', '${data.accounts}', Icons.people_rounded),
        _Metric(
          'Doanh thu đã thu',
          formatVnd(data.paidRevenue),
          Icons.payments_rounded,
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.navy),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          Text(label, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    ),
  );
}

class _Schedule extends StatefulWidget {
  const _Schedule({required this.api, required this.version});
  final CourtApiService api;
  final int version;
  @override
  State<_Schedule> createState() => _ScheduleState();
}

class _ScheduleState extends State<_Schedule> {
  DateTime _date = DateTime.now();
  int _reload = 0;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Ngày ${_date.day}/${_date.month}/${_date.year}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              onPressed: _pickDate,
              icon: const Icon(Icons.date_range_rounded),
            ),
          ],
        ),
      ),
      Expanded(
        child: _FutureBody<List<AdminSlot>>(
          key: ValueKey(
            '${widget.version}-$_reload-${_date.toIso8601String()}',
          ),
          future: widget.api.adminSchedule(_date),
          builder: (slots) => ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: slots.length,
            itemBuilder: (_, index) {
              final slot = slots[index];
              final booked = slot.status == 'BOOKED';
              final enabled = slot.status == 'AVAILABLE';
              return Card(
                child: SwitchListTile(
                  value: enabled,
                  onChanged: booked
                      ? null
                      : (value) async {
                          try {
                            await widget.api.setSlotEnabled(slot.id, value);
                            if (mounted) setState(() => _reload++);
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('$error')));
                            }
                          }
                        },
                  title: Text('${slot.startTime} • ${slot.courtName}'),
                  subtitle: Text(
                    booked
                        ? '${slot.customerName ?? 'Khách'} • ${slot.paymentStatus ?? ''}'
                        : (enabled ? 'Sẵn sàng nhận đặt sân' : 'Đã đóng lịch'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _date = picked);
  }
}

class _Courts extends StatelessWidget {
  const _Courts({
    required this.api,
    required this.version,
    required this.refresh,
  });
  final CourtApiService api;
  final int version;
  final VoidCallback refresh;
  @override
  Widget build(BuildContext context) => _FutureBody<List<Court>>(
    key: ValueKey(version),
    future: api.adminCourts(),
    builder: (courts) => ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: courts.length,
      itemBuilder: (_, index) {
        final court = courts[index];
        return Card(
          child: SwitchListTile(
            value: court.active,
            onChanged: (value) async {
              try {
                await api.setCourtActive(court.id, value);
                refresh();
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$error')));
                }
              }
            },
            secondary: IconButton(
              tooltip: 'Chỉnh sửa sân',
              onPressed: () => _editCourt(context, court),
              icon: Icon(Icons.edit_outlined, color: court.accent),
            ),
            title: Text(court.name),
            subtitle: Text('${court.id} • ${formatVnd(court.price)}/giờ'),
          ),
        );
      },
    ),
  );

  Future<void> _editCourt(BuildContext context, Court court) async {
    final name = TextEditingController(text: court.name);
    final address = TextEditingController(text: court.address);
    final price = TextEditingController(text: '${court.price}');
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Chỉnh sửa ${court.id}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Tên sân'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Địa chỉ'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá mỗi giờ'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    final courtName = name.text.trim();
    final courtAddress = address.text.trim();
    final courtPrice = int.tryParse(price.text) ?? court.price;
    name.dispose();
    address.dispose();
    price.dispose();
    if (result != true || !context.mounted) return;
    try {
      final color = court.accent
          .toARGB32()
          .toRadixString(16)
          .padLeft(8, '0')
          .substring(2)
          .toUpperCase();
      await api.updateCourt(court.id, {
        'name': courtName,
        'address': courtAddress,
        'pricePerHour': courtPrice,
        'distanceLabel': court.distance,
        'accentColor': color,
        'iconName': _iconName(court.icon),
        'tags': court.tags,
      });
      refresh();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không sửa được sân: $error')));
      }
    }
  }

  String _iconName(IconData icon) {
    if (icon == Icons.bolt_rounded) return 'bolt';
    if (icon == Icons.stadium_rounded) return 'stadium';
    return 'sports_tennis';
  }
}

class _Accounts extends StatelessWidget {
  const _Accounts({
    required this.api,
    required this.version,
    required this.refresh,
  });
  final CourtApiService api;
  final int version;
  final VoidCallback refresh;
  @override
  Widget build(BuildContext context) => _FutureBody<List<AdminAccount>>(
    key: ValueKey(version),
    future: api.accounts(),
    builder: (accounts) => ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: accounts.length,
      itemBuilder: (_, index) {
        final account = accounts[index];
        return Card(
          child: SwitchListTile(
            value: account.enabled,
            onChanged: (value) async {
              try {
                await api.setAccountEnabled(account.id, value);
                refresh();
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$error')));
                }
              }
            },
            title: Text(account.fullName),
            subtitle: Text(
              '${account.email}\n${account.role} • ${account.bookingCount} đơn',
            ),
            isThreeLine: true,
          ),
        );
      },
    ),
  );
}

class _FutureBody<T> extends StatelessWidget {
  const _FutureBody({super.key, required this.future, required this.builder});
  final Future<T> future;
  final Widget Function(T data) builder;
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (_, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Không tải được dữ liệu',
          message: '${snapshot.error}',
        );
      }
      return builder(snapshot.data as T);
    },
  );
}
