import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../utils/date_format.dart';

const _kOrange = Color(0xFFF97316);

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  DateTimeRange? _range; // null = ทุกวัน (เลือกช่วง: จากวันที่ → ถึงวันที่)

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fullDate(String date) => thaiDateFromStr(date);
  String _fullDateTime(String date, String start, String end) =>
      thaiDateTimeFromStr(date, startTime: start, endTime: end);

  /// กรองตามช่วงวันที่ + คำค้น (ชื่อ/รหัส ครู+นักเรียน)
  List<SessionModel> _filter(List<SessionModel> all) {
    final q = _query.trim().toLowerCase();
    // วันที่เก็บเป็น 'YYYY-MM-DD' → เทียบ string ได้ตรงตามลำดับเวลา
    final fromStr = _range != null ? toStorageDateStr(_range!.start) : null;
    final toStr = _range != null ? toStorageDateStr(_range!.end) : null;
    return all.where((s) {
      if (fromStr != null && (s.date.compareTo(fromStr) < 0 || s.date.compareTo(toStr!) > 0)) {
        return false;
      }
      if (q.isEmpty) return true;
      final hay = '${s.studentName} ${s.teacherName} '
          '${s.studentCode ?? ''} ${s.teacherCode ?? ''}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _pickRange() async {
    final now = nowThai();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      helpText: 'เลือกช่วงวันที่ (จาก – ถึง)',
      saveText: 'ตกลง',
    );
    if (picked != null && mounted) {
      setState(() => _range = DateTimeRange(
            start: DateTime(picked.start.year, picked.start.month, picked.start.day),
            end: DateTime(picked.end.year, picked.end.month, picked.end.day),
          ));
    }
  }

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
        backgroundColor: _kOrange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<SessionModel>>(
        stream: FirestoreService.watchCompletedSessions(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];

          if (all.isEmpty) {
            return const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 8),
                Text('ยังไม่มีคาบที่เรียน/สอนเสร็จแล้ว', style: TextStyle(color: Colors.grey)),
              ]),
            );
          }

          final sessions = _filter(all);
          final isFiltering = _query.trim().isNotEmpty || _range != null;

          return Column(children: [
            // ── แถบค้นหา + เลือกวันที่ ──
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              color: Colors.white,
              child: Column(children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'ค้นหา ชื่อ หรือ รหัส (ครู/นักเรียน)',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() {
                              _searchCtrl.clear();
                              _query = '';
                            }),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range, size: 16),
                      label: Text(
                        _range != null
                            ? '${_fullDate(toStorageDateStr(_range!.start))}  ถึง  ${_fullDate(toStorageDateStr(_range!.end))}'
                            : 'ทุกวัน (แตะเลือกช่วงวันที่)',
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kOrange,
                        side: BorderSide(color: _kOrange.withAlpha(120)),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  if (_range != null) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => setState(() => _range = null),
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'ล้างช่วงวันที่',
                      style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100),
                    ),
                  ],
                ]),
              ]),
            ),

            // ── แถบสรุปจำนวน + ลบทั้งหมด ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green.shade50,
              child: Row(children: [
                Icon(Icons.check_circle, size: 18, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  isFiltering
                      ? 'พบ ${sessions.length} จาก ${all.length} รายการ'
                      : 'เรียน/สอนเสร็จแล้ว ${all.length} รายการ',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green.shade700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _confirmDeleteAll(context, all.length),
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('ลบทั้งหมด', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ]),
            ),

            // ── รายการ ──
            Expanded(
              child: sessions.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.search_off, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        const Text('ไม่พบรายการตามเงื่อนไข', style: TextStyle(color: Colors.grey)),
                      ]),
                    )
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
                              // ลำดับ
                              Container(
                                width: 30, height: 30,
                                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                                child: Center(child: Text('${i + 1}',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade700))),
                              ),
                              const SizedBox(width: 10),

                              // ข้อมูล
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  const Icon(Icons.school_outlined, size: 14, color: _kOrange),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(s.studentName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      overflow: TextOverflow.ellipsis)),
                                  if (s.studentCode != null && s.studentCode!.isNotEmpty)
                                    _codeChip(s.studentCode!, _kOrange),
                                ]),
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.person_outlined, size: 14, color: Color(0xFF2E7D32)),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(s.teacherName,
                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                      overflow: TextOverflow.ellipsis)),
                                  if (s.teacherCode != null && s.teacherCode!.isNotEmpty)
                                    _codeChip(s.teacherCode!, const Color(0xFF2E7D32)),
                                ]),
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.calendar_today, size: 12, color: _kOrange),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(
                                    '${_fullDate(s.date)}  ${s.startTime} - ${s.endTime} น.'
                                    '${s.language != null ? '  •  ${s.language}' : ''}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  )),
                                ]),
                              ])),

                              // ปุ่มลบ
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

  Widget _codeChip(String code, Color color) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: color.withAlpha(24), borderRadius: BorderRadius.circular(6)),
        child: Text(code, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      );
}
