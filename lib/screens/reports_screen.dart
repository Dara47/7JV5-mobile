import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../utils/date_format.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  String _fullDate(String date) => thaiDateFromStr(date);
  String _fullDateTime(String date, String start, String end) =>
      thaiDateTimeFromStr(date, startTime: start, endTime: end);

  void _confirmDeleteOne(BuildContext context, SessionModel s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบรายการ'),
        content: Text('ลบคาบ ${s.studentName}\n${_fullDateTime(s.date, s.startTime, s.endTime)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService.deleteSession(s.id);
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll(BuildContext context, int count) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบทั้งหมด'),
        content: Text('ยืนยันลบ $count รายการที่เรียน/สอนเสร็จแล้วทั้งหมด?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService.deleteAllCompletedSessions();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('ลบทั้งหมด'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายงาน'),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<SessionModel>>(
        stream: FirestoreService.watchCompletedSessions(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final sessions = snap.data ?? [];

          if (sessions.isEmpty) {
            return const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 8),
                Text('ยังไม่มีคาบที่เรียน/สอนเสร็จแล้ว', style: TextStyle(color: Colors.grey)),
              ]),
            );
          }

          return Column(children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.green.shade50,
              child: Row(children: [
                Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text('เรียน/สอนเสร็จแล้ว ${sessions.length} รายการ',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _confirmDeleteAll(context, sessions.length),
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('ลบทั้งหมด', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ]),
            ),

            // List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final s = sessions[i];
                  return Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        // Number
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                          child: Center(child: Text('${i + 1}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700))),
                        ),
                        const SizedBox(width: 10),

                        // Info
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.school_outlined, size: 14, color: Color(0xFFF97316)),
                            const SizedBox(width: 4),
                            Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ]),
                          const SizedBox(height: 2),
                          Row(children: [
                            const Icon(Icons.person_outlined, size: 14, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 4),
                            Text(s.teacherName, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          ]),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.calendar_today, size: 12, color: Color(0xFFF97316)),
                            const SizedBox(width: 4),
                            Expanded(child: Text(
                              '${_fullDate(s.date)}  ${s.startTime} - ${s.endTime} น.'
                              '${s.language != null ? '  •  ${s.language}' : ''}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            )),
                          ]),
                        ])),

                        // Delete button
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                          onPressed: () => _confirmDeleteOne(context, s),
                          tooltip: 'ลบรายการนี้',
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  }
}
