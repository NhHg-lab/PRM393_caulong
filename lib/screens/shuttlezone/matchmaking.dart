import 'package:flutter/material.dart';

import 'shared.dart';

class _Match {
  _Match(
    this.title,
    this.venue,
    this.level,
    this.time,
    this.fee,
    this.slots, {
    this.mine = false,
  });
  final String title, venue, level, time;
  final int fee;
  int slots;
  final bool mine;
  bool joined = false;
}

class MatchmakingPage extends StatefulWidget {
  const MatchmakingPage({super.key});
  @override
  State<MatchmakingPage> createState() => _MatchmakingPageState();
}

class _MatchmakingPageState extends State<MatchmakingPage> {
  int _tab = 0;
  String _level = 'Tất cả';
  final _matches = [
    _Match(
      'SkyBadminton • Cần thêm 1 bạn',
      'SkyBadminton Club • Quận 7 • Sân 4',
      'Trung bình khá',
      'Ngày mai • 19:30 - 21:30',
      50000,
      1,
    ),
    _Match(
      'Kèo giao lưu vui vẻ • Đôi nam nữ',
      'CLB Cầu Lông Victor Pro • Quận 7',
      'Mới chơi',
      'Ngày mai • 20:00 - 22:00',
      45000,
      2,
    ),
    _Match(
      'Kèo cọ xát đỉnh cao • Đôi nam',
      'Victory Arena • Tân Bình',
      'Nâng cao',
      'Ngày mai • 18:00 - 20:00',
      65000,
      1,
    ),
    _Match(
      'CLB Smashers • Hội viên cố định',
      'Nhà thi đấu Phú Thọ • Quận 11',
      'Trung bình khá',
      'Thứ 2 - 4 - 6 • 18:00 - 20:00',
      450000,
      3,
    ),
  ];
  @override
  Widget build(BuildContext context) {
    final filtered = _matches
        .where(
          (m) =>
              (_tab == 0 || m.joined || m.mine) &&
              (_level == 'Tất cả' || m.level == _level),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Kèo tìm người')),
            ButtonSegment(value: 1, label: Text('Kèo của tôi')),
          ],
          selected: {_tab},
          onSelectionChanged: (v) => setState(() => _tab = v.first),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final level in [
                'Tất cả',
                'Mới chơi',
                'Trung bình khá',
                'Nâng cao',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(level),
                    selected: _level == level,
                    selectedColor: szLime,
                    onSelected: (_) => setState(() => _level = level),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SzPanel(
          color: const Color(0xFFE9F3D8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Thiếu chân cầu lông?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text('Mở kèo ghép, tìm đồng đội cùng trình.'),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('create-match'),
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('Tạo kèo demo'),
              ),
            ],
          ),
        ),
        SzHeading(_tab == 0 ? 'Kèo đang tuyển thành viên' : 'Kèo của tôi'),
        if (filtered.isEmpty)
          const SzPanel(
            child: Text(
              'Chưa có kèo phù hợp. Bạn có thể tạo kèo hoặc đổi bộ lọc.',
            ),
          ),
        for (final match in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: SzPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SzTag(
                        match.mine
                            ? 'CHỦ KÈO • DEMO'
                            : match.joined
                            ? 'ĐÃ THAM GIA • DEMO'
                            : 'CÒN ${match.slots} SLOT',
                        color: const Color(0xFFE9F3D8),
                      ),
                      SzTag(match.level),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    match.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SzLine(Icons.location_on_outlined, match.venue),
                  SzLine(Icons.schedule, match.time),
                  const SizedBox(height: 8),
                  Text(
                    '${formatVnd(match.fee)} ${match.title.contains('cố định') ? '/ tháng' : '/ người'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed:
                          match.mine || (!match.joined && match.slots == 0)
                          ? null
                          : () => _join(match),
                      child: Text(
                        match.mine
                            ? 'Bạn là chủ kèo'
                            : match.joined
                            ? 'Rời kèo demo'
                            : 'Tham gia kèo demo →',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SzPanel(
          color: Color(0xFFE9F3D8),
          child: SzLine(
            Icons.verified_user_outlined,
            'Giao lưu văn minh • Tôn trọng đồng đội • Đúng giờ ra sân',
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          demoDisclaimer,
          style: TextStyle(fontSize: 11, color: szMuted),
        ),
      ],
    );
  }

  Future<void> _join(_Match match) async {
    if (match.joined) {
      setState(() {
        match.joined = false;
        match.slots++;
      });
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tham gia kèo demo?'),
        content: Text(
          '${match.title}\n${match.time}\nPhí dự kiến: ${formatVnd(match.fee)}\n\nKhông gửi yêu cầu hay thu tiền thật.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tham gia'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        match.joined = true;
        match.slots--;
      });
    }
  }

  Future<void> _create() async {
    final created = await szPush<_Match>(context, const _CreateMatchScreen());
    if (created != null && mounted) {
      setState(() {
        _matches.insert(0, created);
        _tab = 1;
        _level = 'Tất cả';
      });
    }
  }
}

class _CreateMatchScreen extends StatefulWidget {
  const _CreateMatchScreen();
  @override
  State<_CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<_CreateMatchScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _fee = TextEditingController(text: '50000');
  Venue _venue = venues.first;
  String _level = 'Trung bình khá';
  DateTime _date = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );
  int _hour = 19, _slots = 1;
  @override
  void dispose() {
    _title.dispose();
    _fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tạo kèo ghép')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Đồng đội mới, trận cầu mới.',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _title,
            maxLength: 80,
            decoration: const InputDecoration(labelText: 'Tên kèo'),
            validator: (v) => (v?.trim().length ?? 0) < 5
                ? 'Nhập tên kèo ít nhất 5 ký tự'
                : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _venue.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Cụm sân'),
            items: venues
                .map((v) => DropdownMenuItem(value: v.id, child: Text(v.name)))
                .toList(),
            onChanged: (id) =>
                setState(() => _venue = venues.firstWhere((v) => v.id == id)),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _level,
            decoration: const InputDecoration(labelText: 'Trình độ'),
            items: [
              'Mới chơi',
              'Trung bình khá',
              'Nâng cao',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (v) => setState(() => _level = v!),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final today = DateUtils.dateOnly(DateTime.now());
              final selected = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: today,
                lastDate: today.add(const Duration(days: 60)),
              );
              if (selected != null && mounted) setState(() => _date = selected);
            },
            icon: const Icon(Icons.calendar_today),
            label: Text(szDate(_date)),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _hour,
            decoration: const InputDecoration(labelText: 'Khung giờ (2 tiếng)'),
            items: [
              for (var i = 6; i <= 21; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text('${szHour(i)} - ${szHour(i + 2)}'),
                ),
            ],
            onChanged: (v) => setState(() => _hour = v!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _slots,
            decoration: const InputDecoration(labelText: 'Số người cần thêm'),
            items: [
              for (var i = 1; i <= 4; i++)
                DropdownMenuItem(value: i, child: Text('$i người')),
            ],
            onChanged: (v) => setState(() => _slots = v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _fee,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Phí mỗi người (đ)'),
            validator: (v) =>
                int.tryParse(v ?? '') == null ||
                    int.parse(v!) < 0 ||
                    int.parse(v) > 1000000
                ? 'Nhập số tiền từ 0 đến 1.000.000đ'
                : null,
          ),
          const SizedBox(height: 24),
          const Text(
            'Kèo demo chỉ hiển thị trong phiên này. Tạo kèo không đồng nghĩa với đặt sân.',
            style: TextStyle(color: szMuted, fontSize: 12),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              if (!_form.currentState!.validate()) return;
              if (DateTime(
                _date.year,
                _date.month,
                _date.day,
                _hour,
              ).isBefore(DateTime.now())) {
                szNotice(context, 'Vui lòng chọn giờ trong tương lai.');
                return;
              }
              Navigator.pop(
                context,
                _Match(
                  _title.text.trim(),
                  '${_venue.name} • ${_venue.district}',
                  _level,
                  '${szDate(_date)} • ${szHour(_hour)} - ${szHour(_hour + 2)}',
                  int.parse(_fee.text),
                  _slots,
                  mine: true,
                ),
              );
            },
            child: const Text('Tạo kèo demo'),
          ),
        ],
      ),
    ),
  );
}
