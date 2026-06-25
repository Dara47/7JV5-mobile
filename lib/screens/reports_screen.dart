import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../utils/date_format.dart';
import '../utils/excel_export.dart';
import '../widgets/load_more_footer.dart';

const _kOrange = Color(0xFFF97316);
const _kExportPass = 'ATAL190314'; // รหัสผ่านก่อนดาวน์โหลดไฟล์ Excel (ข้อมูลสำคัญ)

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  DateTimeRange? _range; // null = ทุกวัน (เลือกช่วง: จากวันที่ → ถึงวันที่)
  Map<String, String> _idToCode = {}; // userId → code (เติมรหัสให้ session เก่าที่ไม่มีรหัสฝังไว้)
  static const _pageSize = 20;
  int _visible = _pageSize; // แสดงทีละ 20 (กดโหลดเพิ่ม)

  @override
  void initState() {
    super.initState();
    // โหลด map รหัสผู้ใช้ เพื่อเติมรหัสให้ session ที่ยังไม่มี studentCode/teacherCode
    FirestoreService.userIndexByCode().then((idx) {
      if (!mounted) return;
      final m = <String, String>{};
      idx.forEach((code, rec) => m[rec.id] = code);
      setState(() => _idToCode = m);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _fullDate(String date) => thaiDateFromStr(date);
  String _fullDateTime(String date, String start, String end) =>
      thaiDateTimeFromStr(date, startTime: start, endTime: end);

  /// รหัสนักเรียน/ครู — ใช้ที่ฝังใน session ก่อน ถ้าไม่มีค่อย lookup จาก id
  String? _sCode(SessionModel s) =>
      (s.studentCode != null && s.studentCode!.isNotEmpty) ? s.studentCode : _idToCode[s.studentId];
  String? _tCode(SessionModel s) =>
      (s.teacherCode != null && s.teacherCode!.isNotEmpty) ? s.teacherCode : _idToCode[s.teacherId];

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
          '${_sCode(s) ?? ''} ${_tCode(s) ?? ''}'.toLowerCase();
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
      setState(() {
        _range = DateTimeRange(
          start: DateTime(picked.start.year, picked.start.month, picked.start.day),
          end: DateTime(picked.end.year, picked.end.month, picked.end.day),
        );
        _visible = _pageSize;
      });
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

  /// ขอรหัสผ่านก่อน แล้วค่อยส่งออก (ไฟล์เป็นข้อมูลสำคัญ)
  Future<void> _promptExportPassword(List<SessionModel> all) async {
    final ctrl = TextEditingController();
    bool obscure = true;
    bool error = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          void submit() {
            if (ctrl.text.trim() == _kExportPass) {
              Navigator.pop(ctx, true);
            } else {
              setS(() => error = true);
            }
          }
          return AlertDialog(
            title: const Row(children: [
              Icon(Icons.lock_outline, color: _kOrange),
              SizedBox(width: 8),
              Text('ใส่รหัสผ่าน'),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('ไฟล์นี้เป็นข้อมูลสำคัญ — กรุณาใส่รหัสผ่านเพื่อดาวน์โหลด',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                autofocus: true,
                onSubmitted: (_) => submit(),
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setS(() => obscure = !obscure),
                  ),
                  errorText: error ? 'รหัสผ่านไม่ถูกต้อง' : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
              ElevatedButton(
                onPressed: submit,
                style: ElevatedButton.styleFrom(backgroundColor: _kOrange, foregroundColor: Colors.white),
                child: const Text('ดาวน์โหลด'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true) _exportWeek(all);
  }

  /// ส่งออก Excel "คาบที่สอนแล้ว" ของสัปดาห์ปัจจุบัน (อา.–ส.)
  /// 2 ชีต: สรุปรายครู + รายคาบละเอียด พร้อมยอดรวม
  void _exportWeek(List<SessionModel> all) {
    final now = nowThai();
    // สัปดาห์เริ่มวันอาทิตย์: weekday Mon=1..Sun=7 → Sun%7=0
    final startSun = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday % 7));
    final endSat = startSun.add(const Duration(days: 6));
    final fromStr = toStorageDateStr(startSun);
    final toStr = toStorageDateStr(endSat);

    final week = all
        .where((s) => s.date.compareTo(fromStr) >= 0 && s.date.compareTo(toStr) <= 0)
        .toList()
      ..sort((a, b) {
        final d = a.date.compareTo(b.date);
        return d != 0 ? d : a.startTime.compareTo(b.startTime);
      });

    if (week.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('สัปดาห์นี้ (${_fullDate(fromStr)} – ${_fullDate(toStr)}) ยังไม่มีคาบที่สอนเสร็จ')));
      return;
    }

    // ── ชีต 1: สรุปรายครู ──
    final byTeacher = <String, ({String name, String code, int count})>{};
    for (final s in week) {
      final code = _tCode(s) ?? '';
      final key = '${s.teacherName}|$code';
      final cur = byTeacher[key];
      byTeacher[key] = (name: s.teacherName, code: code, count: (cur?.count ?? 0) + 1);
    }
    final sortedTeachers = byTeacher.values.toList()
      ..sort((a, b) => b.count != a.count ? b.count.compareTo(a.count) : a.name.compareTo(b.name));
    final teacherRows = <List<dynamic>>[];
    for (var i = 0; i < sortedTeachers.length; i++) {
      final t = sortedTeachers[i];
      teacherRows.add([i + 1, t.name, t.code, t.count]);
    }
    teacherRows.add(['', 'รวม', '', week.length]);

    // ── ชีต 2: รายคาบละเอียด ──
    final detailRows = <List<dynamic>>[];
    for (var i = 0; i < week.length; i++) {
      final s = week[i];
      final status = s.isAbsent ? 'ขาด' : (s.isLate ? 'สาย' : 'ปกติ');
      detailRows.add([
        i + 1, _fullDate(s.date), s.startTime, s.endTime,
        s.teacherName, _tCode(s) ?? '',
        s.studentName, _sCode(s) ?? '',
        s.language ?? '', status,
      ]);
    }

    exportXlsxSheets(
      filename: '7J_คาบที่สอนแล้ว_${fromStr}_ถึง_$toStr.xlsx',
      sheets: [
        (
          name: 'สรุปรายครู',
          headers: ['ลำดับ', 'ครู', 'รหัสครู', 'จำนวนคาบที่สอน'],
          rows: teacherRows,
        ),
        (
          name: 'รายคาบละเอียด',
          headers: ['ลำดับ', 'วันที่', 'เริ่ม', 'สิ้นสุด', 'ครู', 'รหัสครู',
            'นักเรียน', 'รหัสนักเรียน', 'ภาษา', 'สถานะ'],
          rows: detailRows,
        ),
      ],
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('ส่งออก ${week.length} คาบ (${_fullDate(fromStr)} – ${_fullDate(toStr)}) เป็น Excel แล้ว'),
      backgroundColor: Colors.green,
    ));
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
          // แสดงทีละ 20 (กดโหลดเพิ่ม)
          final visible = _visible.clamp(0, sessions.length);
          final shown = sessions.take(visible).toList();
          final hasMore = sessions.length > visible;

          return Column(children: [
            // ── แถบค้นหา + เลือกวันที่ ──
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              color: Colors.white,
              child: Column(children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() { _query = v; _visible = _pageSize; }),
                  decoration: InputDecoration(
                    hintText: 'ค้นหา ชื่อ หรือ รหัส (ครู/นักเรียน)',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() {
                              _searchCtrl.clear();
                              _query = '';
                              _visible = _pageSize;
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
                      onPressed: () => setState(() { _range = null; _visible = _pageSize; }),
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
                  onPressed: () => _promptExportPassword(all),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Excel สัปดาห์นี้', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(foregroundColor: Colors.green.shade800),
                ),
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
                      itemCount: shown.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        if (i == shown.length) {
                          return LoadMoreFooter(
                            hasMore: hasMore,
                            remaining: sessions.length - visible,
                            total: sessions.length,
                            color: const Color(0xFF00897B),
                            onMore: () => setState(() => _visible += _pageSize),
                          );
                        }
                        final s = shown[i];
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
                                  if (_sCode(s) != null && _sCode(s)!.isNotEmpty)
                                    _codeChip(_sCode(s)!, _kOrange),
                                ]),
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.person_outlined, size: 14, color: Color(0xFF2E7D32)),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(s.teacherName,
                                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                                      overflow: TextOverflow.ellipsis)),
                                  if (_tCode(s) != null && _tCode(s)!.isNotEmpty)
                                    _codeChip(_tCode(s)!, const Color(0xFF2E7D32)),
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
