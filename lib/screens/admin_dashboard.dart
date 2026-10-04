import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.onExit});
  final VoidCallback onExit;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const titles = ['Tổng quan', 'Lịch đặt', 'Quản lý sân', 'Tài khoản'];
    final pages = const [
      _OverviewTab(),
      _ScheduleTab(),
      _CourtManagementTab(),
      _AccountManagementTab(),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navyDeep,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: widget.onExit,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titles[_tab],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'COURTLY ADMIN',
              style: TextStyle(
                color: AppColors.lime,
                fontSize: 9,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Badge(
              label: Text('3'),
              child: Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: _tab == 2
          ? FloatingActionButton.extended(
              onPressed: () => _showAddCourt(context),
              backgroundColor: AppColors.lime,
              foregroundColor: AppColors.navyDeep,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Thêm sân',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Lịch đặt',
          ),
          NavigationDestination(
            icon: Icon(Icons.stadium_outlined),
            selectedIcon: Icon(Icons.stadium_rounded),
            label: 'Sân',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }

  void _showAddCourt(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom +
              24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Thêm sân mới',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 18),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Tên sân',
                prefixIcon: Icon(Icons.stadium_outlined),
              ),
            ),
            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Giá mỗi giờ',
                prefixIcon: Icon(Icons.payments_outlined),
                suffixText: 'đ',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tạo sân'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.navyDeep, Color(0xFF164A65)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  StatusPill(label: 'HÔM NAY • 05/10', color: AppColors.lime),
                  Spacer(),
                  Icon(Icons.insights_rounded, color: Colors.white54),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                '8.460.000đ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.8,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Doanh thu hôm nay',
                style: TextStyle(color: Color(0xFFB9C7D2)),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    color: AppColors.lime,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '+12,4%',
                    style: TextStyle(
                      color: AppColors.lime,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    ' so với hôm qua',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.calendar_month_rounded,
                value: '38',
                label: 'Lượt đặt',
                color: AppColors.blue,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.stadium_rounded,
                value: '12/16',
                label: 'Sân hoạt động',
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: Icons.schedule_rounded,
                value: '76%',
                label: 'Lấp đầy',
                color: AppColors.warning,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.people_rounded,
                value: '1.284',
                label: 'Khách hàng',
                color: Color(0xFF9B62D0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        const SectionHeading(
          title: 'Hiệu suất 7 ngày',
          subtitle: 'Số lượt đặt theo ngày',
        ),
        const SizedBox(height: 14),
        const _MiniChart(),
        const SizedBox(height: 26),
        const SectionHeading(title: 'Hoạt động gần đây', action: 'Xem tất cả'),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: const [
              _ActivityRow(
                icon: Icons.add_task_rounded,
                title: 'Đơn mới #BK261005',
                subtitle: 'Smash Hub • 18:30',
                time: '2 phút',
                color: AppColors.success,
              ),
              Divider(height: 1, indent: 62),
              _ActivityRow(
                icon: Icons.cancel_outlined,
                title: 'Đơn #BK240118 đã hủy',
                subtitle: 'Nova Club • Hoàn 155.000đ',
                time: '18 phút',
                color: AppColors.danger,
              ),
              Divider(height: 1, indent: 62),
              _ActivityRow(
                icon: Icons.person_add_alt_rounded,
                title: 'Tài khoản mới',
                subtitle: 'Nguyễn Minh Anh',
                time: '32 phút',
                color: AppColors.blue,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _MiniChart extends StatelessWidget {
  const _MiniChart();

  @override
  Widget build(BuildContext context) {
    const values = [32.0, 48.0, 43.0, 68.0, 58.0, 84.0, 74.0];
    const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return Card(
      child: SizedBox(
        height: 190,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(values.length, (index) {
              final active = index == 5;
              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${values[index].round()}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: active ? AppColors.navy : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: values[index] * 1.2,
                      width: 22,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.lime
                            : AppColors.navy.withValues(alpha: .13),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      days[index],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab();

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  int _day = 0;
  final Set<int> _blocked = {5, 11};

  @override
  Widget build(BuildContext context) {
    const days = [
      ('T2', '05'),
      ('T3', '06'),
      ('T4', '07'),
      ('T5', '08'),
      ('T6', '09'),
      ('T7', '10'),
      ('CN', '11'),
    ];
    const times = [
      '06:00',
      '07:30',
      '09:00',
      '10:30',
      '14:00',
      '15:30',
      '17:00',
      '18:30',
      '20:00',
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                readOnly: true,
                decoration: const InputDecoration(
                  hintText: 'Tìm mã đơn, khách hàng...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final selected = _day == index;
              return InkWell(
                onTap: () => setState(() => _day = index),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 55,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.navy : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? AppColors.navy : AppColors.line,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        days[index].$1,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? Colors.white70 : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        days[index].$2,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
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
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'Thứ Hai, 05/10',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            const StatusPill(label: '6 ĐƠN', color: AppColors.blue),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Chạm vào khung giờ để đóng/mở lịch',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        ...List.generate(times.length, (index) {
          final booked = index == 1 || index == 4 || index == 7;
          final blocked = _blocked.contains(index);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: booked
                  ? null
                  : () => setState(
                      () => blocked
                          ? _blocked.remove(index)
                          : _blocked.add(index),
                    ),
              borderRadius: BorderRadius.circular(17),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: booked
                        ? AppColors.blue.withValues(alpha: .3)
                        : blocked
                        ? AppColors.danger.withValues(alpha: .3)
                        : AppColors.line,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 54,
                      child: Text(
                        times[index],
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Container(
                      width: 4,
                      height: 38,
                      decoration: BoxDecoration(
                        color: booked
                            ? AppColors.blue
                            : blocked
                            ? AppColors.danger
                            : AppColors.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booked
                                ? [
                                    'Nguyễn Minh Anh',
                                    'Lê Tuấn Hùng',
                                    'Trần Quốc Bảo',
                                  ][index == 1
                                      ? 0
                                      : index == 4
                                      ? 1
                                      : 2]
                                : blocked
                                ? 'Đã đóng lịch'
                                : 'Khung giờ trống',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            booked
                                ? 'Sân ${index % 3 + 1} • Đã thanh toán'
                                : blocked
                                ? 'Không nhận đặt sân'
                                : 'Sẵn sàng nhận đặt sân',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                      label: booked
                          ? 'ĐÃ ĐẶT'
                          : blocked
                          ? 'ĐÃ ĐÓNG'
                          : 'CÒN TRỐNG',
                      color: booked
                          ? AppColors.blue
                          : blocked
                          ? AppColors.danger
                          : AppColors.success,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CourtManagementTab extends StatefulWidget {
  const _CourtManagementTab();

  @override
  State<_CourtManagementTab> createState() => _CourtManagementTabState();
}

class _CourtManagementTabState extends State<_CourtManagementTab> {
  final Map<String, bool> _active = {'CR01': true, 'CR02': true, 'CR03': false};

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                readOnly: true,
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm sân...',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const StatusPill(label: '16 SÂN', color: AppColors.navy),
          ],
        ),
        const SizedBox(height: 22),
        ...demoCourts.map(
          (court) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Card(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22),
                    ),
                    child: CourtArtwork(
                      color: court.accent,
                      icon: court.icon,
                      height: 96,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    court.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${court.id} • ${formatVnd(court.price)}/giờ',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _active[court.id] ?? false,
                              activeTrackColor: AppColors.lime,
                              activeThumbColor: AppColors.navy,
                              onChanged: (value) =>
                                  setState(() => _active[court.id] = value),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _CourtStat(
                                label: 'Lượt đặt',
                                value: court.id == 'CR01' ? '126' : '94',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CourtStat(
                                label: 'Lấp đầy',
                                value: court.id == 'CR01' ? '86%' : '71%',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _CourtStat(
                                label: 'Đánh giá',
                                value: '${court.rating} ★',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {},
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Chỉnh sửa'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.more_horiz_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CourtStat extends StatelessWidget {
  const _CourtStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.canvas,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: AppColors.muted),
        ),
      ],
    ),
  );
}

class _AccountManagementTab extends StatefulWidget {
  const _AccountManagementTab();
  @override
  State<_AccountManagementTab> createState() => _AccountManagementTabState();
}

class _AccountManagementTabState extends State<_AccountManagementTab> {
  final List<bool> _enabled = [true, true, true, false];

  @override
  Widget build(BuildContext context) {
    const users = [
      ('Nguyễn Minh Anh', 'minhanh@gmail.com', 'MA', '24 đơn'),
      ('Lê Tuấn Hùng', 'tuanhung@gmail.com', 'TH', '18 đơn'),
      ('Trần Quốc Bảo', 'quocbao@gmail.com', 'QB', '12 đơn'),
      ('Phạm Thu Hà', 'thuha@gmail.com', 'TH', '3 đơn'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        TextField(
          readOnly: true,
          decoration: const InputDecoration(
            hintText: 'Tìm tên, email hoặc số điện thoại...',
            prefixIcon: Icon(Icons.search_rounded),
            suffixIcon: Icon(Icons.tune_rounded),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const StatusPill(label: '1.284 TÀI KHOẢN', color: AppColors.navy),
            const SizedBox(width: 8),
            const StatusPill(label: '+48 THÁNG NÀY', color: AppColors.success),
          ],
        ),
        const SizedBox(height: 18),
        ...List.generate(users.length, (index) {
          final user = users[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: [
                          AppColors.limeSoft,
                          const Color(0xFFE4EEFF),
                          const Color(0xFFFFEBDD),
                          const Color(0xFFF1E8F8),
                        ][index],
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        user.$3,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.$1,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.$2,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            user.$4,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.blue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Text('Xem chi tiết'),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                            _enabled[index]
                                ? 'Khóa tài khoản'
                                : 'Mở khóa tài khoản',
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'toggle') {
                          setState(() => _enabled[index] = !_enabled[index]);
                        }
                      },
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _enabled[index]
                            ? AppColors.success
                            : AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download_rounded),
          label: const Text('Xuất danh sách tài khoản'),
        ),
      ],
    );
  }
}
