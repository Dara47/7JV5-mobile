import 'dart:async';
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

/// breakpoint: จอกว้างกว่านี้ใช้ sidebar, แคบกว่าใช้ bottom bar
const _kWideBreakpoint = 800.0;

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
  const _NavItem(this.icon, this.selectedIcon, this.label, {this.badge = 0});
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
      _cutSub = FirestoreService.watchPendingCutPackages().listen((list) {
        final today = todayThaiStr();
        final count = list.where((p) => p.lastCutDate != today).length;
        if (mounted) setState(() => _pendingCuts = count);
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
        PackagesScreen(key: ValueKey('packages_$k')),
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
    // student
    return [
      StudentDashboardScreen(key: ValueKey('sdash_$k'), appUser: u),
      LeaveRequestScreen(key: ValueKey('sleave_$k'), appUser: u),
    ];
  }

  List<_NavItem> get _navItems {
    final u = widget.appUser;
    if (u.isAdmin) {
      return [
        const _NavItem(Icons.people_outline, Icons.people, 'ผู้ใช้'),
        const _NavItem(Icons.inventory_2_outlined, Icons.inventory_2, 'คาบเรียน'),
        _NavItem(Icons.content_cut_outlined, Icons.content_cut, 'ตัดคาบ', badge: _pendingCuts),
        const _NavItem(Icons.person_pin_outlined, Icons.person_pin, 'เวลาครู'),
        _NavItem(Icons.event_busy_outlined, Icons.event_busy, 'ใบลา', badge: _pendingLeaves),
        const _NavItem(Icons.bar_chart_outlined, Icons.bar_chart, 'รายงาน'),
        const _NavItem(Icons.settings_outlined, Icons.settings, 'ตั้งค่า'),
      ];
    }
    if (u.isTeacher) {
      return const [
        _NavItem(Icons.home_outlined, Icons.home, 'หน้าหลัก'),
        _NavItem(Icons.person_pin_outlined, Icons.person_pin, 'ตารางสอน'),
        _NavItem(Icons.event_busy_outlined, Icons.event_busy, 'ใบลา'),
      ];
    }
    return const [
      _NavItem(Icons.home_outlined, Icons.home, 'หน้าหลัก'),
      _NavItem(Icons.event_busy_outlined, Icons.event_busy, 'ใบลา'),
    ];
  }

  String get _roleLabel {
    final u = widget.appUser;
    if (u.isAdmin) return 'ผู้ดูแลระบบ';
    if (u.isTeacher) return 'ครู';
    return 'นักเรียน';
  }

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

  @override
  Widget build(BuildContext context) {
    final screens = _screens;
    final items = _navItems;
    if (_selectedIndex >= screens.length) _selectedIndex = 0;

    final isWide = MediaQuery.of(context).size.width >= _kWideBreakpoint;

    if (isWide) {
      // ── Desktop / tablet: sidebar layout ──
      return Scaffold(
        body: Row(children: [
          _Sidebar(
            items: items,
            selectedIndex: _selectedIndex,
            roleLabel: _roleLabel,
            userName: widget.isCodeLogin ? widget.appUser.name : null,
            userCode: widget.isCodeLogin ? widget.appUser.code : null,
            onSelect: (i) => setState(() => _selectedIndex = i),
            onRefresh: _refresh,
            onLogout: _logout,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: IndexedStack(index: _selectedIndex, children: screens)),
        ]),
      );
    }

    // ── Mobile: bottom navigation bar ──
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.centerRight,
            children: [
              NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (i) => setState(() => _selectedIndex = i),
                destinations: items.map((item) => NavigationDestination(
                  icon: _badged(Icon(item.icon), item.badge),
                  selectedIcon: _badged(Icon(item.selectedIcon), item.badge),
                  label: item.label,
                )).toList(),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.grey),
                  tooltip: 'รีเฟรชข้อมูล',
                  onPressed: _refresh,
                ),
              ),
            ],
          ),
          if (widget.isCodeLogin)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.appUser.name}  (${widget.appUser.code})',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, size: 14, color: Colors.grey),
                    label: const Text('ออกจากระบบ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 4, top: 2),
            child: const Text('Version 5.1.0',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  /// wrap icon ด้วย Badge เมื่อมีตัวเลขงานค้าง
  static Widget _badged(Widget icon, int count) {
    if (count <= 0) return icon;
    return Badge(
      label: Text('$count'),
      backgroundColor: Colors.red,
      child: icon,
    );
  }
}

// ── Sidebar (desktop/tablet) ──────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final String roleLabel;
  final String? userName;
  final String? userCode;
  final ValueChanged<int> onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;
  const _Sidebar({
    required this.items,
    required this.selectedIndex,
    required this.roleLabel,
    required this.userName,
    required this.userCode,
    required this.onSelect,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: Colors.white,
      child: SafeArea(
        child: Column(children: [
          // Brand header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kOrange, Color(0xFFFF8F00)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Text('7J',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('7J English',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(roleLabel,
                    style: const TextStyle(fontSize: 12, color: _kOrange, fontWeight: FontWeight.w600)),
              ])),
            ]),
          ),
          if (userName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$userName ($userCode)',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
              ),
            ),
          const Divider(height: 1),

          // Menu items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (_, i) => _SidebarItem(
                item: items[i],
                selected: selectedIndex == i,
                onTap: () => onSelect(i),
              ),
            ),
          ),

          const Divider(height: 1),
          // Footer actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              Expanded(child: TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18, color: Colors.grey),
                label: const Text('รีเฟรช', style: TextStyle(fontSize: 13, color: Colors.grey)),
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
              )),
              IconButton(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, size: 18, color: Colors.grey),
                tooltip: 'ออกจากระบบ',
              ),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Version 5.1.0',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        ]),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarItem({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: selected ? _kOrange.withAlpha(24) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              // accent bar
              Container(
                width: 3, height: 20,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: selected ? _kOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(selected ? item.selectedIcon : item.icon, size: 21,
                  color: selected ? _kOrange : Colors.grey.shade600),
              const SizedBox(width: 12),
              Expanded(child: Text(item.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? _kOrange : Colors.black87,
                  ))),
              if (item.badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${item.badge}',
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
