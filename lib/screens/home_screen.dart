import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../utils/date_format.dart';
import 'users_list_screen.dart';
import 'packages_screen.dart';
import 'teacher_schedule_screen.dart';
import 'reports_screen.dart';
import 'cut_session_screen.dart';
import 'leave_request_screen.dart';
import 'settings_screen.dart';
import 'teacher_dashboard_screen.dart';
import 'student_dashboard_screen.dart';

const _kOrange = Color(0xFFF97316);

class _NavItem {
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  const _NavItem(this.icon, this.label, this.color, {this.badge = 0});
}

class HomeScreen extends StatefulWidget {
  final AppUser appUser;
  final bool isCodeLogin;
  const HomeScreen({super.key, required this.appUser, this.isCodeLogin = false});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _refreshKey = 0;

  // Badge counts (admin only)
  int _pendingCuts = 0;
  int _pendingLeaves = 0;
  StreamSubscription? _cutSub;
  StreamSubscription? _leaveSub;

  @override
  void initState() {
    super.initState();
    if (widget.appUser.isAdmin) {
      _cutSub = FirestoreService.watchPendingCuts().listen((list) {
        if (mounted) setState(() => _pendingCuts = list.length);
      });
      _leaveSub = FirestoreService.watchLeaveRequests().listen((list) {
        final count = list.where((r) => r.isPending).length;
        if (mounted) setState(() => _pendingLeaves = count);
      });
    }
  }

  @override
  void dispose() {
    _cutSub?.cancel();
    _leaveSub?.cancel();
    super.dispose();
  }

  void _refresh() => setState(() => _refreshKey++);

  List<Widget> get _screens {
    final u = widget.appUser;
    final k = _refreshKey;
    if (u.isAdmin) {
      return [
        UsersListScreen(key: ValueKey('users_$k')),
        PackagesScreen(key: ValueKey('packages_$k'), teacherViewOnly: true),
        CutSessionScreen(key: ValueKey('cut_$k')),
        TeacherScheduleScreen(key: ValueKey('schedule_$k')),
        LeaveRequestScreen(key: ValueKey('leave_$k'), appUser: u),
        ReportsScreen(key: ValueKey('reports_$k')),
        SettingsScreen(key: ValueKey('settings_$k')),
      ];
    }
    if (u.isTeacher) {
      return [
        TeacherDashboardScreen(key: ValueKey('tdash_$k'), appUser: u),
        TeacherScheduleScreen(key: ValueKey('tschedule_$k'), filterTeacherId: u.uid),
        LeaveRequestScreen(key: ValueKey('tleave_$k'), appUser: u),
      ];
    }
    return [
      StudentDashboardScreen(key: ValueKey('sdash_$k'), appUser: u),
      LeaveRequestScreen(key: ValueKey('sleave_$k'), appUser: u),
    ];
  }

  List<_NavItem> get _navItems {
    final u = widget.appUser;
    if (u.isAdmin) {
      return [
        const _NavItem(Icons.people, 'ผู้ใช้', Color(0xFF3B82F6)),
        const _NavItem(Icons.groups, 'ครู–ศิษย์', Color(0xFFF97316)),
        _NavItem(Icons.content_cut, 'ตัดคาบ', const Color(0xFF7E57C2), badge: _pendingCuts),
        const _NavItem(Icons.person_pin, 'เวลาครู', Color(0xFF2E7D32)),
        _NavItem(Icons.event_busy, 'ใบลา', const Color(0xFFE65100), badge: _pendingLeaves),
        const _NavItem(Icons.bar_chart, 'รายงาน', Color(0xFF00897B)),
        const _NavItem(Icons.settings, 'ตั้งค่า', Color(0xFF607D8B)),
      ];
    }
    if (u.isTeacher) {
      return const [
        _NavItem(Icons.home, 'หน้าหลัก', Color(0xFFF97316)),
        _NavItem(Icons.person_pin, 'ตารางสอน', Color(0xFF2E7D32)),
        _NavItem(Icons.event_busy, 'ใบลา', Color(0xFFE65100)),
      ];
    }
    return const [
      _NavItem(Icons.home, 'หน้าหลัก', Color(0xFFF97316)),
      _NavItem(Icons.event_busy, 'ใบลา', Color(0xFFE65100)),
    ];
  }

  String get _roleLabel {
    final u = widget.appUser;
    if (u.isAdmin) return 'ผู้ดูแลระบบ';
    if (u.isTeacher) return 'ครู';
    return 'นักเรียน';
  }

  int get _totalBadge => _pendingCuts + _pendingLeaves;

  Future<void> _logout() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('ออกจากระบบ'),
      content: const Text('ยืนยันออกจากระบบ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ออก', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (ok == true) {
      if (widget.isCodeLogin) {
        if (mounted) Navigator.of(context).pop();
      } else {
        FirebaseAuth.instance.signOut();
      }
    }
  }

  void _openMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MenuSheet(
        items: _navItems,
        selectedIndex: _selectedIndex,
        roleLabel: _roleLabel,
        userName: '${widget.appUser.name} (${widget.appUser.code})',
        onSelect: (i) {
          Navigator.pop(context);
          setState(() => _selectedIndex = i);
        },
        onRefresh: () { Navigator.pop(context); _refresh(); },
        onLogout: () { Navigator.pop(context); _logout(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = _screens;
    if (_selectedIndex >= screens.length) _selectedIndex = 0;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _HomeButton(badge: _totalBadge, onTap: _openMenu),
    );
  }
}

// ── Home button (iPhone-style single launcher) ────────────────────────────────

class _HomeButton extends StatelessWidget {
  final int badge;
  final VoidCallback onTap;
  const _HomeButton({required this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kOrange, Color(0xFFFF8F00)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: _kOrange.withAlpha(110), blurRadius: 14, offset: const Offset(0, 5)),
            ],
          ),
          child: const Icon(Icons.apps_rounded, color: Colors.white, size: 30),
        ),
        if (badge > 0)
          Positioned(
            right: -2, top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text('$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
      ]),
    );
  }
}

// ── Menu popup (iOS-style app grid) ───────────────────────────────────────────

class _MenuSheet extends StatefulWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final String roleLabel;
  final String userName;
  final ValueChanged<int> onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  const _MenuSheet({
    required this.items,
    required this.selectedIndex,
    required this.roleLabel,
    required this.userName,
    required this.onSelect,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  State<_MenuSheet> createState() => _MenuSheetState();
}

class _MenuSheetState extends State<_MenuSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// สีประจำวันไทย (จ.เหลือง อ.ชมพู พ.เขียว พฤ.ส้ม ศ.ฟ้า ส.ม่วง อา.แดง)
  Color _dayColor() {
    const colors = {
      1: Color(0xFFF9A825), // จันทร์ — เหลือง
      2: Color(0xFFEC407A), // อังคาร — ชมพู
      3: Color(0xFF43A047), // พุธ — เขียว
      4: Color(0xFFFB8C00), // พฤหัสบดี — ส้ม
      5: Color(0xFF039BE5), // ศุกร์ — ฟ้า
      6: Color(0xFF8E24AA), // เสาร์ — ม่วง
      7: Color(0xFFE53935), // อาทิตย์ — แดง
    };
    return colors[nowThai().weekday] ?? _kOrange;
  }

  /// คำทักทายตามช่วงเวลา (เวลาไทย)
  ({String text, String emoji}) _greeting() {
    final h = nowThai().hour;
    if (h < 12) return (text: 'สวัสดีตอนเช้า', emoji: '☀️');
    if (h < 17) return (text: 'สวัสดีตอนบ่าย', emoji: '🌤️');
    if (h < 20) return (text: 'สวัสดีตอนเย็น', emoji: '🌆');
    return (text: 'สวัสดีตอนค่ำ', emoji: '🌙');
  }

  /// pop-in แบบ staggered (scale + fade) ทีละไอคอนแบบ iOS
  Widget _staggered(int i, int count, Widget child) {
    final start = ((i / (count < 1 ? 1 : count)) * 0.55).clamp(0.0, 1.0);
    final end = (start + 0.45).clamp(0.0, 1.0);
    final anim = CurvedAnimation(parent: _ctrl, curve: Interval(start, end, curve: Curves.easeOutBack));
    return AnimatedBuilder(
      animation: anim,
      builder: (_, c) {
        final v = anim.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.5 + 0.5 * v, child: c),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final width = MediaQuery.of(context).size.width;
    final cols = width >= 700 ? 5 : 4;

    final dayColor = _dayColor();

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(245),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              // Header (พื้นหลังไล่สี "ตามวัน" + คำทักทายตามเวลา + วันที่ไทย)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [dayColor.withValues(alpha: 0.14), dayColor.withValues(alpha: 0.02)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
                child: Row(children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kOrange, Color(0xFFFF8F00)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: _kOrange.withAlpha(80), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: const Center(child: Text('7J',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_greeting().text} ${_greeting().emoji}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE65100))),
                    const SizedBox(height: 1),
                    Text(widget.roleLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(widget.userName, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(height: 3),
                    // แถววันที่ไทย ใช้ "สีประจำวัน"
                    Row(children: [
                      Icon(Icons.event_rounded, size: 13, color: dayColor),
                      const SizedBox(width: 4),
                      Flexible(child: Text(thaiDateFull(nowThai()),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: dayColor))),
                    ]),
                  ])),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ]),
              ),
              const Divider(height: 1),

              // App grid
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    childAspectRatio: 0.82,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _staggered(i, items.length, _AppTile(
                    item: items[i],
                    selected: widget.selectedIndex == i,
                    onTap: () => widget.onSelect(i),
                  )),
                ),
              ),

              const Divider(height: 1),
              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Row(children: [
                  Expanded(child: TextButton.icon(
                    onPressed: widget.onRefresh,
                    icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
                    label: const Text('รีเฟรช', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                  )),
                  Text('Version 5.1.1', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout, size: 18, color: Colors.red),
                    label: const Text('ออก', style: TextStyle(fontSize: 13, color: Colors.red)),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _AppTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 58, height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [item.color, Color.lerp(item.color, Colors.black, 0.18)!],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: item.color.withAlpha(90), blurRadius: 8, offset: const Offset(0, 3)),
              ],
              border: selected ? Border.all(color: Colors.white, width: 2) : null,
            ),
            child: Icon(item.icon, color: Colors.white, size: 28),
          ),
          if (item.badge > 0)
            Positioned(
              right: -4, top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                constraints: const BoxConstraints(minWidth: 20),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text('${item.badge}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          if (selected)
            Positioned(
              bottom: -3, left: 0, right: 0,
              child: Center(child: Container(
                width: 5, height: 5,
                decoration: const BoxDecoration(color: _kOrange, shape: BoxShape.circle),
              )),
            ),
        ]),
        const SizedBox(height: 6),
        Text(item.label,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? _kOrange : Colors.black87,
            )),
      ]),
    );
  }
}
