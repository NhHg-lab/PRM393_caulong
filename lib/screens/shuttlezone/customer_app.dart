import 'package:flutter/material.dart';

import '../../models/auth_models.dart';
import 'shared.dart';
import 'booking.dart';
import 'matchmaking.dart';

class CustomerApp extends StatefulWidget {
  const CustomerApp({
    super.key,
    required this.user,
    required this.onLogout,
    this.onOpenAdmin,
  });
  final AppUser user;
  final VoidCallback onLogout;
  final VoidCallback? onOpenAdmin;
  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  int _tab = 0;
  final _favorites = <int>{0};
  final _tickets = <DemoTicket>[];
  void _go(int tab) => setState(() => _tab = tab);
  void _book(Venue venue, {DateTime? date}) => szPush(
    context,
    VenueDetailScreen(
      venue: venue,
      initialDate: date,
      tickets: _tickets,
      onBooked: (ticket) => setState(() => _tickets.insert(0, ticket)),
    ),
  );
  @override
  Widget build(BuildContext context) => Theme(
    data: shuttleTheme(),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          titleSpacing: 20,
          title: Row(
            children: [
              Container(
                width: 34,
                height: 38,
                decoration: BoxDecoration(
                  color: szLime,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sports_tennis,
                  size: 22,
                  color: szGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        'ShuttleZone',
                        'Tìm sân',
                        'Ghép kèo',
                        'Lịch & Vé',
                        'Tài khoản',
                      ][_tab],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      '⌖ TP. Hồ Chí Minh',
                      style: TextStyle(fontSize: 11, color: szGreen),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Thông báo',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.notifications_none,
                          size: 36,
                          color: szGreen,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Thông báo của bạn',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _tickets.isEmpty
                              ? 'Chưa có thông báo mới.'
                              : 'Bạn có ${_tickets.where((t) => !t.cancelled).length} vé demo trong Lịch & Vé.',
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          demoDisclaimer,
                          style: TextStyle(fontSize: 12, color: szMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.notifications_outlined),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                tooltip: 'Tài khoản',
                onPressed: () => _go(4),
                icon: CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFDAE2FD),
                  child: Text(
                    widget.user.initials,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: IndexedStack(
          index: _tab,
          children: [
            ExplorePage(
              onBook: _book,
              favorites: _favorites,
              onFavorite: (id) => setState(
                () => _favorites.contains(id)
                    ? _favorites.remove(id)
                    : _favorites.add(id),
              ),
              onGo: _go,
            ),
            ExplorePage(
              searchOnly: true,
              onBook: _book,
              favorites: _favorites,
              onFavorite: (id) => setState(
                () => _favorites.contains(id)
                    ? _favorites.remove(id)
                    : _favorites.add(id),
              ),
              onGo: _go,
            ),
            const MatchmakingPage(),
            TicketList(tickets: _tickets, onChanged: () => setState(() {})),
            AccountPage(
              user: widget.user,
              tickets: _tickets,
              onLogout: widget.onLogout,
              onAdmin: widget.onOpenAdmin,
              onTickets: () => _go(3),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _go,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.sports_tennis),
              label: 'Tìm sân',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              label: 'Ghép kèo',
            ),
            NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined),
              label: 'Lịch & Vé',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    ),
  );
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    super.key,
    this.searchOnly = false,
    required this.onBook,
    required this.favorites,
    required this.onFavorite,
    required this.onGo,
  });
  final bool searchOnly;
  final void Function(Venue, {DateTime? date}) onBook;
  final Set<int> favorites;
  final ValueChanged<int> onFavorite, onGo;
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  String _query = '';
  final _filters = <String>{};
  DateTime _date = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );
  bool _savedOnly = false;
  @override
  Widget build(BuildContext context) {
    final filtered = venues
        .where(
          (v) =>
              '${v.name} ${v.address}'.toLowerCase().contains(
                _query.toLowerCase(),
              ) &&
              _filters.every(v.tags.contains) &&
              (!_savedOnly || widget.favorites.contains(v.id)),
        )
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SzPanel(
            child: Column(
              children: [
                TextField(
                  key: widget.searchOnly
                      ? const Key('venue-search')
                      : const Key('home-search'),
                  onChanged: (text) => setState(() => _query = text),
                  decoration: const InputDecoration(
                    hintText: 'Tìm sân, Quận 7, Tân Bình...',
                    prefixIcon: Icon(Icons.search),
                    hintStyle: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < 3; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              i == 0
                                  ? 'Hôm nay'
                                  : i == 1
                                  ? 'Ngày mai'
                                  : szDate(
                                      DateTime.now().add(Duration(days: i)),
                                    ),
                            ),
                            selected: DateUtils.isSameDay(
                              _date,
                              DateTime.now().add(Duration(days: i)),
                            ),
                            selectedColor: szLime,
                            showCheckmark: false,
                            onSelected: (_) => setState(
                              () => _date = DateUtils.dateOnly(
                                DateTime.now().add(Duration(days: i)),
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: 'Chọn ngày',
                        onPressed: () async {
                          final today = DateUtils.dateOnly(DateTime.now());
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: today,
                            lastDate: today.add(const Duration(days: 60)),
                          );
                          if (picked != null && mounted) {
                            setState(() => _date = picked);
                          }
                        },
                        icon: const Icon(Icons.date_range),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Icon(Icons.tune, size: 16),
                      const SizedBox(width: 6),
                      for (final tag in [
                        'Máy lạnh',
                        'Thảm BWF',
                        'Mở 24/7',
                        'Bãi đỗ ô tô',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(
                              tag,
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: _filters.contains(tag),
                            selectedColor: szLime,
                            onSelected: (yes) => setState(
                              () => yes
                                  ? _filters.add(tag)
                                  : _filters.remove(tag),
                            ),
                          ),
                        ),
                      FilterChip(
                        label: const Text('Đã lưu'),
                        selected: _savedOnly,
                        onSelected: (v) => setState(() => _savedOnly = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!widget.searchOnly) ...[
            const SizedBox(height: 20),
            SzPanel(
              color: const Color(0xFF2D3133),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SzTag(
                        'ƯU ĐÃI TUẦN LỄ VÀNG',
                        color: szLime,
                        foreground: szGreen,
                      ),
                      SzTag(
                        '09:00 - 15:00',
                        color: Color(0xFF424936),
                        foreground: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'GIỜ VÀNG\n'),
                        TextSpan(
                          text: 'GIẢM 30%',
                          style: TextStyle(color: Color(0xFFACF847)),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Khởi động ngày mới. Chọn sân yêu thích và sẵn sàng vào trận!',
                    style: TextStyle(
                      color: Color(0xFFD8DADC),
                      height: 1.6,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Hẹn nhau trên sân',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ),
                      FilledButton(
                        key: const Key('quick-book-button'),
                        onPressed: () =>
                            widget.onBook(venues.first, date: _date),
                        child: const Text('Xem ngay →'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final action in [
                  (Icons.near_me_outlined, 'Sân gần nhất', 1),
                  (Icons.event_repeat, 'Cố định tháng', 2),
                  (Icons.group_add_outlined, 'Ghép kèo đấu', 2),
                  (Icons.shopping_bag_outlined, 'Cầu & Vợt', 1),
                ])
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => widget.onGo(action.$3),
                      child: Column(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9F3D8),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(action.$1, color: szGreen),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            action.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          SzHeading(
            widget.searchOnly
                ? 'Kết quả tìm sân (${filtered.length})'
                : 'Sân gần bạn',
            action: widget.searchOnly ? null : 'Xem tất cả',
            onTap: () => widget.onGo(1),
          ),
          if (filtered.isEmpty)
            const SzPanel(
              child: Text(
                'Chưa tìm thấy sân phù hợp. Thử đổi từ khóa hoặc bỏ bớt bộ lọc.',
              ),
            ),
          for (final venue in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: VenueCard(
                venue: venue,
                favorite: widget.favorites.contains(venue.id),
                onFavorite: () => widget.onFavorite(venue.id),
                onBook: () => widget.onBook(venue, date: _date),
              ),
            ),
          if (!widget.searchOnly) ...[
            SzHeading(
              'Tìm đồng đội, vào trận!',
              action: 'Tất cả',
              onTap: () => widget.onGo(2),
            ),
            SzPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SzTag('THIẾU 1 BẠN', color: Color(0xFFE9F3D8)),
                      SzTag('Trung bình khá'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'CLB Cầu Lông Trẻ Q7',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SzLine(Icons.schedule, '18:30 - 20:30 • Ngày mai'),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '45.000đ / người',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      FilledButton(
                        onPressed: () => widget.onGo(2),
                        child: const Text('Vào kèo →'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            demoDisclaimer,
            style: TextStyle(fontSize: 11, color: szMuted, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class VenueCard extends StatelessWidget {
  const VenueCard({
    super.key,
    required this.venue,
    required this.favorite,
    required this.onFavorite,
    required this.onBook,
  });
  final Venue venue;
  final bool favorite;
  final VoidCallback onFavorite, onBook;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Material(
      color: Colors.white,
      child: InkWell(
        onTap: onBook,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                VenuePhoto(venue),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: .75),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  top: 12,
                  left: 12,
                  child: SzTag(
                    '✓ Chuẩn BWF',
                    color: Color(0xDD2D3133),
                    foreground: Colors.white,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    tooltip: 'Lưu sân',
                    onPressed: onFavorite,
                    icon: Icon(
                      favorite ? Icons.favorite : Icons.favorite_outline,
                      color: favorite ? szLime : Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 14,
                  right: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              venue.district,
                              style: const TextStyle(
                                color: szLime,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              venue.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SzTag('★ ${venue.rating}', color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: venue.tags.map((tag) => SzTag(tag)).toList(),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Từ ',
                                style: TextStyle(fontSize: 11),
                              ),
                              TextSpan(
                                text: formatVnd(venue.price),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const TextSpan(
                                text: '/giờ',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                      FilledButton(
                        onPressed: onBook,
                        child: const Text('Đặt chỗ ⚡'),
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
  );
}

class TicketList extends StatefulWidget {
  const TicketList({super.key, required this.tickets, required this.onChanged});
  final List<DemoTicket> tickets;
  final VoidCallback onChanged;
  @override
  State<TicketList> createState() => _TicketListState();
}

class _TicketListState extends State<TicketList> {
  int _filter = 0;
  @override
  Widget build(BuildContext context) {
    final tickets = widget.tickets
        .where(
          (t) =>
              _filter == 0 ||
              (_filter == 1
                  ? !t.cancelled && t.selection.startsAt.isAfter(DateTime.now())
                  : t.cancelled ||
                        t.selection.startsAt.isBefore(DateTime.now())),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Lịch của tôi',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Mọi cuộc hẹn trên sân, trong một nơi.',
          style: TextStyle(color: szMuted),
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Tất cả')),
            ButtonSegment(value: 1, label: Text('Sắp tới')),
            ButtonSegment(value: 2, label: Text('Lịch sử')),
          ],
          selected: {_filter},
          onSelectionChanged: (v) => setState(() => _filter = v.first),
        ),
        const SizedBox(height: 18),
        if (tickets.isEmpty)
          const SzPanel(
            child: Column(
              children: [
                Icon(
                  Icons.confirmation_number_outlined,
                  size: 48,
                  color: szGreen,
                ),
                SizedBox(height: 12),
                Text('Chưa có vé trong mục này'),
                SizedBox(height: 8),
                Text(
                  'Chọn sân và khung giờ để tạo vé demo.',
                  style: TextStyle(color: szMuted),
                ),
              ],
            ),
          ),
        for (final ticket in tickets)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SzPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SzTag(
                    ticket.cancelled ? 'ĐÃ HỦY' : ticket.paymentLabel,
                    color: const Color(0xFFE9F3D8),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ticket.selection.venue.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  SzLine(Icons.calendar_today, szDate(ticket.selection.date)),
                  SzLine(Icons.schedule, ticket.selection.time),
                  FilledButton(
                    onPressed: () async {
                      await szPush(context, TicketScreen(ticket: ticket));
                      widget.onChanged();
                    },
                    child: const Text('Xem vé & mã nhận sân'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        const Text(
          demoDisclaimer,
          style: TextStyle(color: szMuted, fontSize: 12),
        ),
      ],
    );
  }
}

class AccountPage extends StatelessWidget {
  const AccountPage({
    super.key,
    required this.user,
    required this.tickets,
    required this.onLogout,
    required this.onTickets,
    this.onAdmin,
  });
  final AppUser user;
  final List<DemoTicket> tickets;
  final VoidCallback onLogout, onTickets;
  final VoidCallback? onAdmin;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SzPanel(
          child: Column(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: const Color(0xFFE9F3D8),
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.fullName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(user.email, style: const TextStyle(color: szMuted)),
              const SizedBox(height: 12),
              const SzTag(
                '🏅 Thành viên ShuttleZone',
                color: Color(0xFFE9F3D8),
              ),
              const SizedBox(height: 14),
              const SzLine(
                Icons.sports_tennis,
                'Trình độ & UTR: Chưa cập nhật',
              ),
              SzLine(
                Icons.phone_outlined,
                user.phone ?? 'Số điện thoại: Chưa cập nhật',
              ),
              OutlinedButton.icon(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Thẻ vận động viên',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(user.fullName),
                          Text('ID: ${user.id}'),
                          const SizedBox(height: 18),
                          const Icon(
                            Icons.badge_outlined,
                            size: 72,
                            color: szGreen,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Thẻ demo • Chưa có mã QR xác thực tại sân',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Thẻ của tôi'),
              ),
            ],
          ),
        ),
        const SzHeading('Hoạt động của bạn'),
        Row(
          children: [
            Expanded(
              child: SzPanel(
                child: Column(
                  children: [
                    Text(
                      '${tickets.where((t) => !t.cancelled).length}',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Vé trong phiên',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: SzPanel(
                child: Column(
                  children: [
                    Text('—', style: TextStyle(fontSize: 30)),
                    Text('UTR chưa xác minh', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SzPanel(
                child: Column(
                  children: [
                    const Icon(Icons.schedule, color: szGreen),
                    const SizedBox(height: 8),
                    Text(
                      '${tickets.where((t) => !t.cancelled).fold<int>(0, (sum, t) => sum + t.selection.hours.length)} giờ',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'Thời gian đã đặt',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: SzPanel(
                child: Column(
                  children: [
                    Icon(Icons.thumb_up_outlined, color: szGreen),
                    SizedBox(height: 8),
                    Text(
                      '— /100',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Uy tín chưa xác minh',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SzHeading('Huy hiệu đạt được'),
        const SzPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Icon(Icons.bolt, size: 32, color: szMuted),
                    SizedBox(height: 8),
                    Text(
                      'Smash Master',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Chưa mở khóa',
                      style: TextStyle(fontSize: 9, color: szMuted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Icon(Icons.bedtime_outlined, size: 32, color: szMuted),
                    SizedBox(height: 8),
                    Text(
                      'Cú đêm 22h',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Chưa mở khóa',
                      style: TextStyle(fontSize: 9, color: szMuted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 32,
                      color: szMuted,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'SkyFan Pro',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Chưa mở khóa',
                      style: TextStyle(fontSize: 9, color: szMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SzHeading('Lịch sử & Tiện ích'),
        SzPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.confirmation_number_outlined),
                title: const Text('Lịch sử & Vé'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onTickets,
              ),
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Chính sách hủy sân'),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(
                    title: Text('Chính sách demo'),
                    content: Text(cancellationPolicy),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Ví ShuttlePay'),
                subtitle: const Text('Chưa kết nối thanh toán thật'),
              ),
              if (onAdmin != null)
                ListTile(
                  key: const Key('open-admin-button'),
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Trung tâm quản trị'),
                  onTap: onAdmin,
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        OutlinedButton.icon(
          key: const Key('logout-button'),
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất tài khoản'),
        ),
        const SizedBox(height: 18),
        const Text(
          'ShuttleZone • Demo giao diện\n$demoDisclaimer',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: szMuted, height: 1.7),
        ),
      ],
    ),
  );
}
