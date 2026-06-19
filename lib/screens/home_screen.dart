import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'users_list_screen.dart';
import 'packages_screen.dart';
import 'teacher_schedule_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _screens = <Widget>[
    UsersListScreen(),
    PackagesScreen(),
    TeacherScheduleScreen(),
    _PlaceholderScreen(label: 'รายงาน', icon: Icons.bar_chart_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'ผู้ใช้'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'คาบเรียน'),
          NavigationDestination(icon: Icon(Icons.person_pin_outlined), selectedIcon: Icon(Icons.person_pin), label: 'เวลาครู'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'รายงาน'),
        ],
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PlaceholderScreen({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(label),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () async {
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
        ],
      ),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text('$label (กำลังพัฒนา)', style: const TextStyle(color: Colors.grey)),
      ])),
    );
  }
}
