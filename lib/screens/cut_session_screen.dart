import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../utils/date_format.dart';
import 'schedule_calendar_screen.dart';

const _kPurple = Color(0xFF6A1B9A);

class CutSessionScreen extends StatefulWidget {
  const CutSessionScreen({super.key});
  @override
  State<CutSessionScreen> createState() => _CutSessionScreenState();
}

class _CutSessionScreenState extends State<CutSessionScreen> {
  bool _calendarView = false;

  String _todayLabel() => thaiDateFull(nowThai());

  void _confirmCut(BuildContext context, PendingCut item) {
    final now = nowThai();
    final pkg = item.pkg;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ตัดคาบเรียน'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('นักเรียน: ${pkg.studentName}'),
          Text('ครู: ${pkg.teacherName}'),
          Text(thaiDateTimeFull(now, startTime: item.slot.startTime, endTime: item.slot.endTime)),
          const SizedBox(height: 8),
          Text('คงเหลือก่อนตัด ${pkg.remainingSessions} คาบ → จะเหลือ ${pkg.remainingSessions - 1} คาบ',
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService.cutSlot(pkg, item.slot);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('ตัดคาบ ${pkg.studentName} เรียบร้อย'),
                  backgroundColor: Colors.green,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _kPurple, foregroundColor: Colors.white),
            child: const Text('ยืนยันตัดคาบ'),
          ),
        ],
      ),
    );
  }

  void _confirmCutAll(BuildContext context, List<PendingCut> items) {
    if (items.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ตัดคาบทั้งหมด'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ยืนยันตัดคาบทั้งหมด ${items.length} คาบ ในคลิกเดียว?'),
          const SizedBox(height: 8),
          const Text('ระบบจะ:\n• บันทึกผลการเรียนทุกคาบ\n• หักโควตาคาบที่เหลือคาบละ 1',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final n = await FirestoreService.cutAllSlots(items);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('ตัดคาบทั้งหมด $n คาบเรียบร้อย'),
                  backgroundColor: Colors.green,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _kPurple, foregroundColor: Colors.white),
            child: const Text('ยืนยันตัดทั้งหมด'),
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
        backgroundColor: _kPurple,
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _calendarView = !_calendarView),
            icon: Icon(_calendarView ? Icons.view_list_rounded : Icons.calendar_month,
                color: Colors.white, size: 18),
            label: Text(_calendarView ? 'รายการ' : 'ปฏิทิน',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      body: _calendarView
          ? const ScheduleCalendarBody(enableCut: true)
          : StreamBuilder<List<PendingCut>>(
        stream: FirestoreService.watchPendingCuts(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          final pendingCount = items.length;

          return Column(children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFF3E5F5),
              child: Row(children: [
                Icon(Icons.content_cut, size: 18, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _todayLabel(),
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.purple.shade700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                )),
                const SizedBox(width: 8),
                if (pendingCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.notifications_active, size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('รอตัด $pendingCount',
                          style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                    ]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle, size: 13, color: Colors.white),
                      SizedBox(width: 4),
                      Text('ตัดครบแล้ว',
                          style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                    ]),
                  ),
              ]),
            ),

            // ปุ่มตัดคาบทั้งหมด (คลิกเดียว)
            if (pendingCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmCutAll(context, items),
                    icon: const Icon(Icons.done_all, size: 18),
                    label: Text('ตัดคาบทั้งหมด ($pendingCount คาบ)',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),

            // List
            Expanded(
              child: items.isEmpty
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
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        final pkg = item.pkg;
                        final slot = item.slot;
                        return Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(children: [
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                                child: Center(
                                  child: Text('${i + 1}',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade700)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    const Icon(Icons.school_outlined, size: 14, color: Color(0xFFF97316)),
                                    const SizedBox(width: 4),
                                    Expanded(child: Text(pkg.studentName,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                                  ]),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    const Icon(Icons.person_outlined, size: 14, color: Color(0xFF2E7D32)),
                                    const SizedBox(width: 4),
                                    Text(pkg.teacherName, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                  ]),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(color: _kPurple, borderRadius: BorderRadius.circular(4)),
                                      child: Text(slot.day,
                                          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                    const SizedBox(width: 2),
                                    Text('${slot.startTime}–${slot.endTime}',
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
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _confirmCut(context, item),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(color: _kPurple, borderRadius: BorderRadius.circular(8)),
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
