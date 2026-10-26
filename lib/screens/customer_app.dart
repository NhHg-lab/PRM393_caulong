import 'package:flutter/material.dart';

import '../data/demo_data.dart';
import '../models/auth_models.dart';
import '../models/models.dart';
import '../services/court_api_service.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/common_widgets.dart';
import 'booking_flow.dart';

class CustomerApp extends StatefulWidget {
  const CustomerApp({
    super.key,
    required this.user,
    required this.onLogout,
    this.onOpenAdmin,
  });
  final AppUser user;
  final VoidCallback onLogout;

  /// null khi người dùng không phải admin: ẩn thẻ "Trung tâm quản trị".
  final VoidCallback? onOpenAdmin;

  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  int _tab = 0;
  final CourtApiService _api = CourtApiService();
  List<Court> _courts = List.of(demoCourts);
  List<Booking> _bookings = List.of(initialBookings);
  final Set<String> _favorites = {'CR01'};
  late AppUser _profileUser;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _profileUser = widget.user;
    if (CourtApiService.isEnabled) _loadRemoteData();
  }

  Future<void> _loadRemoteData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final courts = await _api.courts();
      final bookings = await _api.bookings();
      if (!mounted) return;
      setState(() {
        _courts = courts;
        _bookings = bookings;
        _favorites
          ..clear()
          ..addAll(courts.where((c) => c.isFavorite).map((c) => c.id));
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _book(Court court) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CourtBookingScreen(
          court: court,
          useApi: CourtApiService.isEnabled,
          onBooked: (booking) => setState(() {
            _bookings.removeWhere((item) => item.id == booking.id);
            _bookings.insert(0, booking);
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Không tải được dữ liệu sân',
          message: _error!,
          action: FilledButton(
            onPressed: _loadRemoteData,
            child: const Text('Thử lại'),
          ),
        ),
      );
    }
    final pages = [
      HomeScreen(
        courts: _courts,
        onBook: _book,
        favorites: _favorites,
        onToggleFavorite: _toggleFavorite,
      ),
      BookingListScreen(
        bookings: _bookings,
        onCancel: _cancelBooking,
        onBookAgain: _book,
      ),
      FavoritesScreen(
        courts: _courts,
        favorites: _favorites,
        onBook: _book,
        onToggleFavorite: _toggleFavorite,
      ),
      ProfileScreen(
        user: _profileUser,
        onLogout: widget.onLogout,
        onOpenAdmin: widget.onOpenAdmin,
        onUpdateProfile: _updateProfile,
      ),
    ];
    return Scaffold(
      // IndexedStack giữ mọi tab trong cây; tắt Hero ở tab ẩn để không trùng tag
      // (vd. cùng một sân vừa ở Trang chủ vừa ở Yêu thích).
      body: IndexedStack(
        index: _tab,
        children: [
          for (var i = 0; i < pages.length; i++)
            HeroMode(enabled: i == _tab, child: pages[i]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Khám phá',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Đơn sân',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'Yêu thích',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFavorite(String id) async {
    final favorite = !_favorites.contains(id);
    setState(() => favorite ? _favorites.add(id) : _favorites.remove(id));
    if (!CourtApiService.isEnabled) return;
    try {
      await _api.setFavorite(id, favorite);
    } catch (error) {
      if (!mounted) return;
      setState(() => favorite ? _favorites.remove(id) : _favorites.add(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không cập nhật được yêu thích: $error')),
      );
    }
  }

  Future<void> _cancelBooking(Booking booking) async {
    final updated = CourtApiService.isEnabled
        ? await _api.cancelBooking(booking.id)
        : booking.copyWith(status: BookingStatus.cancelled);
    final index = _bookings.indexWhere((item) => item.id == booking.id);
    if (index >= 0) {
      setState(() => _bookings[index] = updated);
    }
  }

  Future<void> _updateProfile(String fullName, String? phone) async {
    final normalizedPhone = phone == null || phone.trim().isEmpty
        ? null
        : Validators.normalizePhone(phone.trim());
    final updated = CourtApiService.isEnabled
        ? await _api.updateProfile(
            fullName: fullName.trim(),
            phone: normalizedPhone,
          )
        : _profileUser.copyWith(
            fullName: fullName.trim(),
            phone: normalizedPhone,
            clearPhone: normalizedPhone == null,
          );
    if (mounted) setState(() => _profileUser = updated);
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onBook,
    required this.courts,
    required this.favorites,
    required this.onToggleFavorite,
  });
  final ValueChanged<Court> onBook;
  final List<Court> courts;
  final Set<String> favorites;
  final ValueChanged<String> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vị trí của bạn',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 17,
                              color: AppColors.navy,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Thanh Xuân, Hà Nội',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.displaySmall,
                      children: const [
                        TextSpan(text: 'Tìm sân. '),
                        TextSpan(
                          text: 'Vào trận.',
                          style: TextStyle(color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Sân chất lượng quanh bạn, đặt trong vài chạm.'),
                  const SizedBox(height: 20),
                  TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên sân, khu vực...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: Container(
                        margin: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (courts.isNotEmpty)
                    _QuickBooking(onPressed: () => onBook(courts.first)),
                  const SizedBox(height: 30),
                  const SectionHeading(
                    title: 'Sân gần bạn',
                    subtitle: 'Được yêu thích tại Thanh Xuân',
                    action: 'Xem tất cả',
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
          SliverList.separated(
            itemCount: courts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final court = courts[index];
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  index == courts.length - 1 ? 28 : 0,
                ),
                child: CourtCard(
                  court: court,
                  favorite: favorites.contains(court.id),
                  onFavorite: () => onToggleFavorite(court.id),
                  onTap: () => onBook(court),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickBooking extends StatelessWidget {
  const _QuickBooking({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.navyDeep, AppColors.navy],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: .15),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const StatusPill(
                label: 'ĐẶT NHANH',
                color: AppColors.lime,
                icon: Icons.bolt_rounded,
              ),
              const Spacer(),
              Icon(
                Icons.sports_tennis_rounded,
                color: Colors.white.withValues(alpha: .45),
                size: 35,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Tối nay chơi ở đâu?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Còn 12 khung giờ trống gần bạn',
            style: TextStyle(color: Color(0xFFB9C7D2), fontSize: 13),
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('quick-book-button'),
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.lime,
              foregroundColor: AppColors.navyDeep,
            ),
            child: const Text('Tìm sân ngay'),
          ),
        ],
      ),
    );
  }
}

class CourtCard extends StatelessWidget {
  const CourtCard({
    super.key,
    required this.court,
    required this.favorite,
    required this.onFavorite,
    required this.onTap,
  });
  final Court court;
  final bool favorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CourtArtwork(
                  color: court.accent,
                  icon: court.icon,
                  heroTag: 'court-${court.id}',
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: onFavorite,
                      icon: Icon(
                        favorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: favorite ? AppColors.danger : AppColors.navyDeep,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: StatusPill(
                    label: court.distance,
                    color: Colors.white,
                    icon: Icons.near_me_rounded,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          court.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.warning,
                        size: 19,
                      ),
                      Text(
                        '${court.rating}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 17,
                        color: AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          court.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Wrap(
                        spacing: 6,
                        children: court.tags.take(2).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.canvas,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const Spacer(),
                      Text(
                        'từ ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        formatVnd(court.price),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.navyDeep,
                        ),
                      ),
                      const Text(
                        '/giờ',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookingListScreen extends StatefulWidget {
  const BookingListScreen({
    super.key,
    required this.bookings,
    required this.onCancel,
    required this.onBookAgain,
  });
  final List<Booking> bookings;
  final Future<void> Function(Booking) onCancel;
  final ValueChanged<Court> onBookAgain;

  @override
  State<BookingListScreen> createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final filtered = widget.bookings
        .where(
          (item) =>
              _filter == 0 ||
              (_filter == 1 && item.status == BookingStatus.upcoming) ||
              (_filter == 2 && item.status != BookingStatus.upcoming),
        )
        .toList();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đơn đặt sân',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                const Text('Theo dõi và quản lý lịch chơi của bạn'),
                const SizedBox(height: 20),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Tất cả')),
                    ButtonSegment(value: 1, label: Text('Sắp tới')),
                    ButtonSegment(value: 2, label: Text('Lịch sử')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (value) =>
                      setState(() => _filter = value.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.navy,
                    selectedForegroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'Chưa có lịch đặt',
                    message: 'Lịch chơi của bạn sẽ xuất hiện tại đây.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) => _BookingCard(
                      booking: filtered[index],
                      onCancel: () => _confirmCancel(filtered[index]),
                      onBookAgain: () =>
                          widget.onBookAgain(filtered[index].court),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCancel(Booking booking) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                color: AppColors.danger,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Hủy lịch đặt sân?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn đang hủy ${booking.court.name} vào ${booking.time}. Khoản hoàn tiền sẽ về ví trong 1–3 ngày.',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.5, color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận hủy sân'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Giữ lịch đặt'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await widget.onCancel(booking);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã hủy sân thành công.')));
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không hủy được sân: $error')));
      }
    }
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.onCancel,
    required this.onBookAgain,
  });
  final Booking booking;
  final VoidCallback onCancel;
  final VoidCallback onBookAgain;

  @override
  Widget build(BuildContext context) {
    final upcoming = booking.status == BookingStatus.upcoming;
    final cancelled = booking.status == BookingStatus.cancelled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(
                  label: upcoming
                      ? 'SẮP TỚI'
                      : cancelled
                      ? 'ĐÃ HỦY'
                      : 'HOÀN THÀNH',
                  color: upcoming
                      ? AppColors.blue
                      : cancelled
                      ? AppColors.danger
                      : AppColors.success,
                ),
                const Spacer(),
                Text(
                  '#${booking.id}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: booking.court.accent.withValues(alpha: .1),
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
                      const SizedBox(height: 5),
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
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.muted,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    booking.date,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.schedule_rounded,
                  color: AppColors.muted,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Text(
                  booking.time,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Text(
                  formatVnd(booking.total),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (upcoming)
                  OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(92, 40),
                      foregroundColor: AppColors.danger,
                    ),
                    child: const Text('Hủy sân'),
                  )
                else
                  OutlinedButton(
                    onPressed: onBookAgain,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(102, 40),
                    ),
                    child: const Text('Đặt lại'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    super.key,
    required this.courts,
    required this.favorites,
    required this.onBook,
    required this.onToggleFavorite,
  });
  final List<Court> courts;
  final Set<String> favorites;
  final ValueChanged<Court> onBook;
  final ValueChanged<String> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final favoriteCourts = courts
        .where((court) => favorites.contains(court.id))
        .toList();
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sân yêu thích',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text('${favoriteCourts.length} địa điểm bạn đã lưu'),
              ],
            ),
          ),
          Expanded(
            child: favoriteCourts.isEmpty
                ? const EmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'Chưa có sân yêu thích',
                    message: 'Chạm biểu tượng trái tim để lưu sân bạn thích.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    itemCount: favoriteCourts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) => CourtCard(
                      court: favoriteCourts[index],
                      favorite: true,
                      onFavorite: () =>
                          onToggleFavorite(favoriteCourts[index].id),
                      onTap: () => onBook(favoriteCourts[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onUpdateProfile,
    this.onOpenAdmin,
  });
  final AppUser user;
  final VoidCallback onLogout;
  final Future<void> Function(String fullName, String? phone) onUpdateProfile;
  final VoidCallback? onOpenAdmin;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        children: [
          Text('Tài khoản', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: const BoxDecoration(
                      color: AppColors.lime,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: AppColors.navyDeep,
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email.isNotEmpty ? user.email : user.phone ?? '',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _editProfile(context),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'CÀI ĐẶT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Thông tin cá nhân',
                  onTap: () => _editProfile(context),
                ),
                const Divider(height: 1, indent: 66),
                _ProfileTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Phương thức thanh toán',
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 66),
                _ProfileTile(
                  icon: Icons.notifications_none_rounded,
                  label: 'Thông báo',
                  trailing: const StatusPill(
                    label: 'BẬT',
                    color: AppColors.success,
                  ),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 66),
                _ProfileTile(
                  icon: Icons.help_outline_rounded,
                  label: 'Trợ giúp & hỗ trợ',
                  onTap: () {},
                ),
              ],
            ),
          ),
          if (onOpenAdmin != null) ...[
            const SizedBox(height: 20),
            Card(
              color: AppColors.navyDeep,
              child: InkWell(
                key: const Key('open-admin-button'),
                onTap: onOpenAdmin,
                borderRadius: BorderRadius.circular(22),
                child: const Padding(
                  padding: EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        color: AppColors.lime,
                        size: 30,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trung tâm quản trị',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Quản lý sân, lịch đặt và người dùng',
                              style: TextStyle(
                                color: Color(0xFFB9C7D2),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white54,
                        size: 17,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            key: const Key('logout-button'),
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Đăng xuất'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          ),
          const SizedBox(height: 18),
          const Text(
            'Courtly v1.0.0 • Made for badminton lovers',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.fullName);
    final phoneController = TextEditingController(text: user.phone ?? '');
    var busy = false;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: !busy,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thông tin cá nhân'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                  validator: Validators.fullName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  enabled: !busy,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại (không bắt buộc)',
                  ),
                  validator: Validators.optionalPhone,
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppColors.danger)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() != true) return;
                      setDialogState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await onUpdateProfile(
                          nameController.text,
                          phoneController.text,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (exception) {
                        setDialogState(() {
                          busy = false;
                          error = exception is AuthException
                              ? exception.message
                              : exception.toString();
                        });
                      }
                    },
              child: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    phoneController.dispose();
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    leading: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 20, color: AppColors.navy),
    ),
    title: Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
    ),
    trailing:
        trailing ??
        const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 15,
          color: AppColors.muted,
        ),
  );
}
