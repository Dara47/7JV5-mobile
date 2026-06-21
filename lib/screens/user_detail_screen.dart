import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../widgets/session_table.dart';
import '../widgets/summary_footer.dart';

class UserDetailScreen extends StatelessWidget {
  final String userId;
  final String userName;
  final String userCode;
  final String role;

  const UserDetailScreen({
    super.key, required this.userId, required this.userName,
    required this.userCode, required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(userName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('รหัส $userCode', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ]),
          backgroundColor: const Color(0xFFEA580C),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'คาบเรียน'), Tab(text: 'แพ็กเกจ')],
          ),
        ),
        body: TabBarView(children: [
          _SessionsTab(userId: userId, role: role),
          _PackagesTab(userId: userId, role: role),
        ]),
      ),
    );
  }
}

class _SessionsTab extends StatelessWidget {
  final String userId;
  final String role;
  const _SessionsTab({required this.userId, required this.role});

  void _confirmDelete(BuildContext context, SessionModel session) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบคาบเรียน'),
        content: Text('ยืนยันลบคาบ ${session.date} ${session.startTime}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService.deleteSession(session.id);
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: StreamBuilder<List<SessionModel>>(
        stream: FirestoreService.watchSessionsForUser(userId, role),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snap.data ?? [];
          if (sessions.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.event_note, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                const Text('ยังไม่มีคาบเรียน', style: TextStyle(color: Colors.grey)),
              ]),
            );
          }
          return Column(children: [
            Expanded(child: SessionTable(
              sessions: sessions,
              onEdit: null,
              onDelete: (s) => _confirmDelete(context, s),
            )),
            SummaryFooter(sessions: sessions),
          ]);
        },
      ),
    );
  }
}

class _PackagesTab extends StatelessWidget {
  final String userId;
  final String role;
  const _PackagesTab({required this.userId, required this.role});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PackageModel>>(
      stream: FirestoreService.watchPackagesForUser(userId, role),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final pkgs = snap.data ?? [];
        if (pkgs.isEmpty) {
          return const Center(child: Text('ยังไม่มีแพ็กเกจ', style: TextStyle(color: Colors.grey)));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: pkgs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _PackageCard(pkg: pkgs[i], viewerRole: role),
        );
      },
    );
  }
}

class _PackageCard extends StatelessWidget {
  final PackageModel pkg;
  final String viewerRole;
  const _PackageCard({required this.pkg, required this.viewerRole});

  @override
  Widget build(BuildContext context) {
    final pct = pkg.totalSessions > 0 ? pkg.remainingSessions / pkg.totalSessions : 0.0;
    final barColor = pkg.isLowBalance ? Colors.orange : const Color(0xFFEA580C);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(
              viewerRole == 'student'
                  ? 'ครู: ${pkg.teacherName} (${pkg.teacherCode})'
                  : 'นักเรียน: ${pkg.studentName} (${pkg.studentCode})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: pkg.isActive ? Colors.green.shade100 : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
              child: Text(pkg.isActive ? 'ใช้งาน' : 'หมดอายุ', style: TextStyle(fontSize: 11, color: pkg.isActive ? Colors.green.shade800 : Colors.grey.shade700)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _Stat(label: 'ทั้งหมด', value: '${pkg.totalSessions} คาบ'),
            _Stat(label: 'ใช้ไปแล้ว', value: '${pkg.usedSessions} คาบ'),
            _Stat(label: 'คงเหลือ', value: '${pkg.remainingSessions} คาบ', highlight: pkg.isLowBalance),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct, backgroundColor: Colors.grey.shade200, color: barColor, minHeight: 8),
          ),
          if (pkg.notes != null) ...[
            const SizedBox(height: 8),
            Text(pkg.notes!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _Stat({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: highlight ? Colors.orange.shade800 : Colors.black87)),
    ]),
  );
}
