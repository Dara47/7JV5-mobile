import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

class CutSessionScreen extends StatelessWidget {
  const CutSessionScreen({super.key});

  String _todayLabel() {
    final now = DateTime.now();
    const thaiDays = {1: 'จ', 2: 'อ', 3: 'พ', 4: 'พฤ', 5: 'ศ', 6: 'ส', 7: 'อา'};
    final day = thaiDays[now.weekday] ?? '';
    return 'วัน$day ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  void _confirmCut(BuildContext context, PackageModel pkg) {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ตัดคาบเรียน'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('นักเรียน: ${pkg.studentName}'),
          Text('ครู: ${pkg.teacherName}'),
          Text('วันที่: $dateStr'),
          Text('เวลา: ${pkg.scheduledTime ?? ''} – ${pkg.scheduledEndTime ?? ''}'),
          const SizedBox(height: 8),
          const Text('ยืนยันตัดคาบ? ระบบจะ:\n• บันทึกผลการเรียน\n• หักคาบที่เหลือ 1 คาบ',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService.cutPackageSession(pkg);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('ตัดคาบ ${pkg.studentName} เรียบร้อย'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A1B9A),
              foregroundColor: Colors.white,
            ),
            child: const Text('ยืนยันตัดคาบ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตัดคาบเรียน'),
        backgroundColor: const Color(0xFF6A1B9A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<PackageModel>>(
        stream: FirestoreService.watchPendingCutPackages(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final packages = snap.data ?? [];

          return Column(children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFF3E5F5),
              child: Row(children: [
                Icon(Icons.content_cut, size: 18, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text(
                  '${_todayLabel()} — รอตัดคาบ ${packages.length} รายการ',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple.shade700, fontSize: 13),
                ),
              ]),
            ),

            // List
            Expanded(
              child: packages.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.content_cut, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        const Text('ไม่มีคาบที่ต้องตัดวันนี้', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        const Text(
                          'คาบที่แสดงคือคาบที่กำหนดวันนี้\nและเวลาสิ้นสุดได้ผ่านไปแล้ว',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ]),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: packages.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final pkg = packages[i];
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
                                child: Center(
                                  child: Text('${i + 1}',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Info
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    const Icon(Icons.school_outlined, size: 14, color: Color(0xFF1565C0)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(pkg.studentName,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('เรียนแล้ว',
                                          style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                                    ),
                                  ]),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    const Icon(Icons.person_outlined, size: 14, color: Color(0xFF2E7D32)),
                                    const SizedBox(width: 4),
                                    Text(pkg.teacherName,
                                        style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                  ]),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6A1B9A),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(pkg.scheduledDay ?? '',
                                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                    const SizedBox(width: 2),
                                    Text('${pkg.scheduledTime ?? ''}–${pkg.scheduledEndTime ?? ''}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: pkg.statusColor.withAlpha(20),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('เหลือ ${pkg.remainingSessions}',
                                          style: TextStyle(fontSize: 10, color: pkg.statusColor)),
                                    ),
                                  ]),
                                ]),
                              ),

                              // Cut button or done badge
                              const SizedBox(width: 8),
                              pkg.lastCutDate == todayStr
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green.shade300),
                                      ),
                                      child: Text('✓ ตัดคาบแล้ว',
                                          style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                                    )
                                  : InkWell(
                                      onTap: () => _confirmCut(context, pkg),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6A1B9A),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text('✂ ตัดคาบ',
                                            style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                                      ),
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
