import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'users_list_screen.dart';
import 'packages_screen.dart';
import 'teacher_schedule_screen.dart';
import 'reports_screen.dart';
import 'cut_session_screen.dart';
import 'leave_request_screen.dart';
import 'settings_screen.dart';
import 'payroll_screen.dart';
import 'teacher_dashboard_screen.dart';
import 'student_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppUser appUser;
  final bool isCodeLogin;
  const HomeScreen({super.key, required this.appUser, this.isCodeLogin = false});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  List<Widget> get _screens {
    final u = widget.appUser;
    if (u.isAdmin) {
      return [
        const UsersListScreen(),
        const PackagesScreen(),
        const CutSessionScreen(),
        const TeacherScheduleScreen(),
        LeaveRequestScreen(appUser: u),
        const ReportsScreen(),
        const SettingsScreen(),
        const PayrollScreen(),
      ];
    }
    if (u.isTeacher) {
      return [
        TeacherDashboardScreen(appUser: u),
        TeacherScheduleScreen(filterTeacherId: u.uid),
        LeaveRequestScreen(appUser: u),
      ];
    }
    // student
    return [
      StudentDashboardScreen(appUser: u),
      LeaveRequestScreen(appUser: u),
    ];
  }

  List<NavigationDestination> get _destinations {
    final u = widget.appUser;
    if (u.isAdmin) {
      return const [
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'ผู้ใช้'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'คาบเรียน'),
        NavigationDestination(icon: Icon(Icons.content_cut_outlined), selectedIcon: Icon(Icons.content_cut), label: 'ตัดคาบ'),
        NavigationDestination(icon: Icon(Icons.person_pin_outlined), selectedIcon: Icon(Icons.person_pin), label: 'เวลาครู'),
        NavigationDestination(icon: Icon(Icons.event_busy_outlined), selectedIcon: Icon(Icons.event_busy), label: 'ใบลา'),
        NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'รายงาน'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'ตั้งค่า'),
        NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'บัญชี'),
      ];
    }
    if (u.isTeacher) {
      return const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'หน้าหลัก'),
        NavigationDestination(icon: Icon(Icons.person_pin_outlined), selectedIcon: Icon(Icons.person_pin), label: 'ตารางสอน'),
        NavigationDestination(icon: Icon(Icons.event_busy_outlined), selectedIcon: Icon(Icons.event_busy), label: 'ใบลา'),
      ];
    }
    return const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'หน้าหลัก'),
      NavigationDestination(icon: Icon(Icons.event_busy_outlined), selectedIcon: Icon(Icons.event_busy), label: 'ใบลา'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screens = _screens;
    final destinations = _destinations;

    if (_selectedIndex >= screens.length) _selectedIndex = 0;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (destinations.length > 1)
            NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: destinations,
            )
          else
            _SingleTabBar(
              label: destinations.first.label,
              onLogout: () async {
                final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                  title: const Text('ออกจากระบบ'),
                  content: const Text('ยืนยันออกจากระบบ?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ออก', style: TextStyle(color: Colors.red))),
                  ],
                ));
                if (ok == true) FirebaseAuth.instance.signOut();
              },
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
                    onPressed: () => Navigator.of(context).pop(),
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
}

class _SingleTabBar extends StatelessWidget {
  final String label;
  final VoidCallback onLogout;
  const _SingleTabBar({required this.label, required this.onLogout});

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFF97316))),
        ),
        IconButton(icon: const Icon(Icons.logout, color: Colors.grey), onPressed: onLogout),
      ]),
    ),
  );
}
