import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'users_list_screen.dart';
import 'packages_screen.dart';
import 'teacher_schedule_screen.dart';
import 'reports_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppUser appUser;
  const HomeScreen({super.key, required this.appUser});
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
        const TeacherScheduleScreen(),
        const ReportsScreen(),
      ];
    }
    if (u.isTeacher) {
      return [
        PackagesScreen(filterTeacherId: u.uid, filterTeacherName: u.name),
        TeacherScheduleScreen(filterTeacherId: u.uid),
      ];
    }
    // student
    return [
      PackagesScreen(filterStudentId: u.uid, filterStudentName: u.name),
    ];
  }

  List<NavigationDestination> get _destinations {
    final u = widget.appUser;
    if (u.isAdmin) {
      return const [
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'ผู้ใช้'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'คาบเรียน'),
        NavigationDestination(icon: Icon(Icons.person_pin_outlined), selectedIcon: Icon(Icons.person_pin), label: 'เวลาครู'),
        NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'รายงาน'),
      ];
    }
    if (u.isTeacher) {
      return const [
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'คาบเรียน'),
        NavigationDestination(icon: Icon(Icons.person_pin_outlined), selectedIcon: Icon(Icons.person_pin), label: 'ตารางสอน'),
      ];
    }
    return const [
      NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'คาบเรียน'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screens = _screens;
    final destinations = _destinations;

    // keep index in bounds when role changes
    if (_selectedIndex >= screens.length) _selectedIndex = 0;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: destinations.length > 1
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              destinations: destinations,
            )
          : _SingleTabBar(
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
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1565C0))),
        ),
        IconButton(icon: const Icon(Icons.logout, color: Colors.grey), onPressed: onLogout),
      ]),
    ),
  );
}
