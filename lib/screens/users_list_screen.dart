import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import 'user_form_screen.dart';
import 'user_detail_screen.dart';

class _StudentStatusBadge extends StatelessWidget {
  final String userId;
  final bool isActive;
  const _StudentStatusBadge({required this.userId, required this.isActive});

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        child: Text('หยุด', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      );
    }
    return StreamBuilder<List<PackageModel>>(
      stream: FirestoreService.watchPackagesForUser(userId, 'student'),
      builder: (context, snap) {
        final pkgs = snap.data ?? [];
        final hasExpired = pkgs.isNotEmpty && pkgs.any((p) => p.remainingSessions == 0);
        final isLow = !hasExpired && pkgs.any((p) => p.isLowBalance);

        if (hasExpired) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
            child: Text('หมดคาบ', style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
          );
        }
        if (isLow) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
            child: Text('ใกล้หมด', style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
          child: Text('ใช้งาน', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
        );
      },
    );
  }
}

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});
  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openForm({UserModel? user}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => UserFormScreen(existing: user),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการผู้ใช้'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'นักเรียน'), Tab(text: 'ครู')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_user',
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('เพิ่มผู้ใช้'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อหรือรหัส...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchCtrl.clear())
                  : null,
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _UserList(role: 'student', search: _search, onEdit: _openForm),
              _UserList(role: 'teacher', search: _search, onEdit: _openForm),
            ],
          ),
        ),
      ]),
    );
  }
}

class _UserList extends StatelessWidget {
  final String role;
  final String search;
  final void Function({UserModel? user}) onEdit;
  const _UserList({required this.role, required this.search, required this.onEdit});

  void _confirmDelete(BuildContext context, UserModel u) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบผู้ใช้'),
        content: Text('ลบ "${u.name}" (${u.code})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService.deleteUser(u.id);
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserModel>>(
      stream: FirestoreService.watchUsers(role: role),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('ข้อผิดพลาด: ${snap.error}'));
        }
        final all = snap.data ?? [];
        final filtered = search.isEmpty
            ? all
            : all.where((u) =>
                u.name.toLowerCase().contains(search) ||
                u.code.toLowerCase().contains(search)).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(role == 'student' ? Icons.school_outlined : Icons.person_outlined, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(search.isEmpty ? 'ยังไม่มี${role == "student" ? "นักเรียน" : "ครู"}' : 'ไม่พบผลการค้นหา',
                  style: const TextStyle(color: Colors.grey)),
            ]),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final u = filtered[i];
            final color = role == 'student' ? const Color(0xFF1565C0) : const Color(0xFF2E7D32);
            return Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: CircleAvatar(
                  backgroundColor: color,
                  radius: 22,
                  child: Text(
                    u.name.isNotEmpty ? u.name[0] : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Row(children: [
                  Text(u.code, style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 13)),
                  if (u.age != null) ...[
                    const SizedBox(width: 8),
                    Text('อายุ ${u.age} ปี', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ]),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  role == 'student'
                    ? _StudentStatusBadge(userId: u.id, isActive: u.isActive)
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: u.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(u.isActive ? 'ใช้งาน' : 'หยุด',
                            style: TextStyle(fontSize: 11, color: u.isActive ? Colors.green.shade700 : Colors.grey)),
                      ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                    onSelected: (v) {
                      if (v == 'edit') onEdit(user: u);
                      if (v == 'detail') Navigator.push(context, MaterialPageRoute(
                          builder: (_) => UserDetailScreen(userId: u.id, userName: u.name, userCode: u.code, role: u.role)));
                      if (v == 'delete') _confirmDelete(context, u);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'detail', child: Row(children: [Icon(Icons.visibility_outlined, size: 18), SizedBox(width: 8), Text('ดูรายละเอียด')])),
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('แก้ไข')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('ลบ', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ]),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserDetailScreen(userId: u.id, userName: u.name, userCode: u.code, role: u.role))),
              ),
            );
          },
        );
      },
    );
  }
}
