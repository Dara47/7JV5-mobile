import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

class CutSessionScreen extends StatefulWidget {
  const CutSessionScreen({super.key});
  @override
  State<CutSessionScreen> createState() => _CutSessionScreenState();
}

class _CutSessionScreenState extends State<CutSessionScreen> {
  String? _filterDate; // 'YYYY-MM-DD'

  String _thaiDay(String date) {
    try {
      final dt = DateTime.parse(date);
      const days = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
      return days[dt.weekday - 1];
    } catch (_) { return ''; }
  }

  String _shortDate(String date) {
    if (date.length < 10) return date;
    return '${date.substring(8)}/${date.substring(5, 7)}/${date.substring(0, 4)}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate != null ? DateTime.parse(_filterDate!) : DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _filterDate = picked.toIso8601String().substring(0, 10));
    }
  }

  void _confirmCut(BuildContext context, SessionModel s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ตัดคาบเรียน'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('นักเรียน: ${s.studentName}'),
          Text('ครู: ${s.teacherName}'),
          Text('วันที่: ${_shortDate(s.date)}'),
          Text('เวลา: ${s.startTime} – ${s.endTime}'),
          const SizedBox(height: 8),
          const Text('ยืนยันตัดคาบ? ระบบจะ:\n• เปลี่ยนสถานะเป็น "เรียนแล้ว"\n• หักคาบที่เหลือ 1 คาบ',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService.cutSession(s.id, s.packageId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('ตัดคาบ ${s.studentName} เรียบร้อย'), backgroundColor: Colors.green));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            child: const Text('ยืนยันตัดคาบ'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, SessionModel s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบรายการ'),
        content: Text('ลบคาบ ${s.studentName} วันที่ ${_shortDate(s.date)}?'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตัดคาบเรียน'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<SessionModel>>(
        stream: FirestoreService.watchPendingCutSessions(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];
          final sessions = _filterDate == null
              ? all
              : all.where((s) => s.date == _filterDate).toList();

          return Column(children: [
            // Filter bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFF3E5F5),
              child: Row(children: [
                Icon(Icons.filter_list, size: 18, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text('รอตัดคาบ ${all.length} รายการ',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple.shade700)),
                const Spacer(),
                if (_filterDate != null)
                  TextButton(
                    onPressed: () => setState(() => _filterDate = null),
                    child: Text('ล้าง (${_shortDate(_filterDate!)})',
                        style: const TextStyle(fontSize: 12, color: Colors.red)),
                  ),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(_filterDate != null ? _shortDate(_filterDate!) : 'เลือกวันที่',
                      style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.purple.shade700,
                    side: BorderSide(color: Colors.purple.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ]),
            ),

            // List
            Expanded(
              child: sessions.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.content_cut, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(_filterDate != null ? 'ไม่มีรายการในวันที่เลือก' : 'ไม่มีคาบที่รอตัด',
                          style: const TextStyle(color: Colors.grey)),
                    ]))
                  : ListView.separated(
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
                                decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                                child: Center(child: Text('${i + 1}',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade700))),
                              ),
                              const SizedBox(width: 10),

                              // Info
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  const Icon(Icons.school_outlined, size: 14, color: Color(0xFF1565C0)),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(s.studentName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                    child: Text('เรียนแล้ว', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                                  ),
                                ]),
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.person_outlined, size: 14, color: Color(0xFF2E7D32)),
                                  const SizedBox(width: 4),
                                  Text(s.teacherName, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                ]),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(color: const Color(0xFF6A1B9A), borderRadius: BorderRadius.circular(4)),
                                    child: Text(_thaiDay(s.date), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(_shortDate(s.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                  const SizedBox(width: 2),
                                  Text(s.timeRange, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ]),
                              ])),

                              // Actions
                              Column(mainAxisSize: MainAxisSize.min, children: [
                                InkWell(
                                  onTap: () => _confirmCut(context, s),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6A1B9A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('✂ ตัดคาบ',
                                        style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () => _confirmDelete(context, s),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Text('ลบ', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ]),
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
