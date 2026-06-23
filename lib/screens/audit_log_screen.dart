import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

/// บันทึกการใช้งานผู้ดูแล — ใครทำอะไร เมื่อไหร่
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});
  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _q = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Color _actionColor(String a) {
    if (a.contains('ตัดคาบ')) return const Color(0xFF1976D2);
    if (a.contains('อนุมัติ')) return const Color(0xFF2E7D32);
    if (a.contains('ปฏิเสธ') || a.contains('ลบ')) return const Color(0xFFC62828);
    if (a.contains('นำเข้า')) return const Color(0xFF6A1B9A);
    if (a.contains('เพิ่ม')) return const Color(0xFFF57C00);
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('บันทึกการใช้งาน'),
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'ค้นหา ชื่อ admin / การกระทำ / รายละเอียด...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _q.isNotEmpty
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
          child: StreamBuilder<List<AuditLogModel>>(
            stream: FirestoreService.watchAuditLogs(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snap.data ?? [];
              final logs = _q.isEmpty ? all : all.where((l) =>
                l.adminName.toLowerCase().contains(_q) ||
                l.action.toLowerCase().contains(_q) ||
                l.detail.toLowerCase().contains(_q) ||
                l.adminEmail.toLowerCase().contains(_q)).toList();

              if (logs.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.history, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(_q.isEmpty ? 'ยังไม่มีบันทึกการใช้งาน' : 'ไม่พบผลการค้นหา',
                      style: const TextStyle(color: Colors.grey)),
                ]));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final l = logs[i];
                  final c = _actionColor(l.action);
                  return Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: c.withAlpha(80)),
                            ),
                            child: Text(l.action, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.bold)),
                          ),
                          const Spacer(),
                          Text(l.timeLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ]),
                        if (l.detail.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(l.detail, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        ],
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.person_outline, size: 14, color: Color(0xFF37474F)),
                          const SizedBox(width: 4),
                          Text(l.adminName.isEmpty ? '(ไม่ระบุ)' : l.adminName,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF37474F), fontWeight: FontWeight.w600)),
                          if (l.adminEmail.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(l.adminEmail, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ]),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
