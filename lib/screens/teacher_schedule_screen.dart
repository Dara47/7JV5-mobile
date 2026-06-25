import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../utils/date_format.dart';
import 'teacher_slot_form_dialog.dart';
import 'schedule_calendar_screen.dart';
import '../widgets/load_more_footer.dart';

class TeacherScheduleScreen extends StatefulWidget {
  final String? filterTeacherId;
  const TeacherScheduleScreen({super.key, this.filterTeacherId});
  @override
  State<TeacherScheduleScreen> createState() => _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  static const _pageSize = 20;
  int _visible = _pageSize;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {
      _search = _searchCtrl.text.toLowerCase();
      _visible = _pageSize; // ค้นหาใหม่ → เริ่มนับ 20 ใหม่
    }));
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    // Teacher view: show only their own card
    if (widget.filterTeacherId != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ตารางสอนของฉัน'),
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month),
              tooltip: 'ปฏิทินคาบเรียน',
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => ScheduleCalendarScreen(
                  filterTeacherId: widget.filterTeacherId,
                  title: 'ปฏิทินสอนของฉัน',
                ),
              )),
            ),
          ],
        ),
        body: StreamBuilder<UserModel?>(
          stream: Stream.fromFuture(FirestoreService.getUser(widget.filterTeacherId!)),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final teacher = snap.data;
            if (teacher == null) return const Center(child: Text('ไม่พบข้อมูลครู'));
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [_TeacherCard(teacher: teacher, readOnly: true)],
            );
          },
        ),
      );
    }

    // Admin view: show all teachers
    return Scaffold(
      appBar: AppBar(
        title: const Text('เวลาว่างครู'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'ปฏิทินคาบเรียน',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ScheduleCalendarScreen(title: 'ปฏิทินคาบเรียน (ทั้งหมด)'),
            )),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อหรือรหัสครู...',
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
          child: StreamBuilder<List<UserModel>>(
            stream: FirestoreService.watchUsers(role: 'teacher'),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snap.data ?? [];
              final teachers = _search.isEmpty ? all : all.where((t) =>
                t.name.toLowerCase().contains(_search) ||
                t.code.toLowerCase().contains(_search)).toList();

              if (teachers.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_search, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(_search.isEmpty ? 'ยังไม่มีครูในระบบ' : 'ไม่พบผลการค้นหา',
                      style: const TextStyle(color: Colors.grey)),
                ]));
              }

              // แสดงทีละ 20 (กดโหลดเพิ่ม) — มีช่องค้นหาแล้ว
              final visible = _visible.clamp(0, teachers.length);
              final shown = teachers.take(visible).toList();
              final hasMore = teachers.length > visible;
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                itemCount: shown.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (i == shown.length) {
                    return LoadMoreFooter(
                      hasMore: hasMore,
                      remaining: teachers.length - visible,
                      total: teachers.length,
                      color: const Color(0xFF2E7D32),
                      onMore: () => setState(() => _visible += _pageSize),
                    );
                  }
                  return _TeacherCard(teacher: shown[i]);
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ── Teacher Card ─────────────────────────────────────────────────────────────

const _thaiDayFull = {
  'อา': 'อาทิตย์', 'จ': 'จันทร์', 'อ': 'อังคาร', 'พ': 'พุธ',
  'พฤ': 'พฤหัสบดี', 'ศ': 'ศุกร์', 'ส': 'เสาร์',
};

class _TeacherCard extends StatelessWidget {
  final UserModel teacher;
  final bool readOnly; // true = มุมมองครู (รายงานอ่านอย่างเดียว ไม่กระทบข้อมูล admin)
  const _TeacherCard({required this.teacher, this.readOnly = false});

  /// รวมคาบสอนจากนักเรียนทุกคน → "วันที่มีสอน" เรียงตามวันที่ (ข้ามที่ผ่านแล้ว)
  /// แยกคาบประจำสัปดาห์ (ไม่ระบุวันที่) ออกมาด้านบน
  Widget _teachingDates(List<PackageModel> packages) {
    final todayStr = todayThaiStr();
    final dated = <({String dateStr, String start, String end, String student})>[];
    final recurring = <({String day, String start, String end, String student})>[];
    for (final p in packages) {
      for (final s in p.effectiveSlots) {
        if (s.startTime.isEmpty) continue;
        if (s.date != null && s.date!.isNotEmpty) {
          if (s.date!.compareTo(todayStr) < 0) continue; // ผ่านแล้ว
          dated.add((dateStr: s.date!, start: s.startTime, end: s.endTime, student: p.studentName));
        } else {
          recurring.add((day: s.day, start: s.startTime, end: s.endTime, student: p.studentName));
        }
      }
    }
    if (dated.isEmpty && recurring.isEmpty) return const SizedBox.shrink();

    dated.sort((a, b) {
      final c = a.dateStr.compareTo(b.dateStr);
      return c != 0 ? c : a.start.compareTo(b.start);
    });
    const order = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];
    final seen = <String>{};
    final rec = recurring.where((r) => seen.add('${r.day}|${r.start}|${r.end}|${r.student}')).toList()
      ..sort((a, b) {
        final c = order.indexOf(a.day).compareTo(order.indexOf(b.day));
        return c != 0 ? c : a.start.compareTo(b.start);
      });

    const cap = 60;
    final shownDated = dated.take(cap).toList();
    final more = dated.length - shownDated.length;

    final rows = <Widget>[];
    String? lastDate;
    for (final e in shownDated) {
      if (e.dateStr != lastDate) {
        lastDate = e.dateStr;
        rows.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Row(children: [
            const Icon(Icons.event, size: 13, color: Color(0xFF2E7D32)),
            const SizedBox(width: 4),
            Text('${thaiDayAbbrFromStr(e.dateStr)} ${thaiShortDateFromStr(e.dateStr)}',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
          ]),
        ));
      }
      rows.add(Padding(
        padding: const EdgeInsets.only(left: 18, bottom: 1),
        child: Text('• ${e.start}–${e.end} น.  ${e.student}',
            style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ));
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.calendar_month, size: 15, color: Color(0xFF2E7D32)),
          const SizedBox(width: 6),
          Text('วันที่มีสอน${dated.isNotEmpty ? ' (${dated.length} คาบข้างหน้า)' : ''}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
        ]),
        if (rec.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('ประจำสัปดาห์', style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          ...rec.map((r) => Padding(
                padding: const EdgeInsets.only(left: 4, top: 1),
                child: Text('• ทุก${_thaiDayFull[r.day] ?? r.day} ${r.start}–${r.end} น.  ${r.student}',
                    style: const TextStyle(fontSize: 12, color: Colors.black87)),
              )),
        ],
        ...rows,
        if (more > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('… และอีก $more คาบ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TeacherSlotModel?>(
      stream: FirestoreService.watchTeacherSlot(teacher.id),
      builder: (context, slotSnap) {
        final slot = slotSnap.data;
        return StreamBuilder<List<PackageModel>>(
          stream: FirestoreService.watchPackagesForTeacher(teacher.id),
          builder: (context, pkgSnap) {
            final packages = pkgSnap.data ?? [];
            final totalSessions = packages.fold(0, (s, p) => s + p.totalSessions);
            final usedSessions = packages.fold(0, (s, p) => s + p.usedSessions);
            final remaining = totalSessions - usedSessions;
            final pct = totalSessions > 0 ? (remaining / totalSessions).clamp(0.0, 1.0) : 0.0;

            // Unique students
            final students = <String, String>{};
            for (final p in packages) {
              students[p.studentId] = '${p.studentName} (${p.studentCode})';
            }

            // Status
            final isTeaching = slot?.isCurrentlyTeaching ?? false;
            final Color statusColor;
            final String statusLabel;
            if (isTeaching) {
              statusColor = Colors.orange;
              statusLabel = '🟠 กำลังสอน';
            } else if (remaining <= 0 && totalSessions > 0) {
              statusColor = Colors.red;
              statusLabel = '🔴 หมดคาบ';
            } else if (remaining <= 3 && totalSessions > 0) {
              statusColor = Colors.orange.shade700;
              statusLabel = '🟡 ใกล้หมด';
            } else if (slot != null) {
              statusColor = Colors.green;
              statusLabel = '🟢 ใช้งานอยู่';
            } else {
              statusColor = Colors.grey;
              statusLabel = '⚪ ยังไม่ได้ตั้งเวลา';
            }

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(20),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(20)),
                      child: Text(statusLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showReport(context, packages),
                      icon: const Icon(Icons.bar_chart, size: 16),
                      label: const Text('รายงาน', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: Colors.blueGrey, padding: const EdgeInsets.symmetric(horizontal: 8)),
                    ),
                  ]),
                ),

                Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Teacher name
                    Row(children: [
                      const Icon(Icons.person_outlined, size: 18, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(teacher.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                      Text(teacher.code, style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600, fontSize: 13)),
                    ]),
                    const SizedBox(height: 8),

                    // Schedule slots
                    GestureDetector(
                      onTap: readOnly ? null : () => showTeacherSlotForm(context, teacher: teacher, existing: slot),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: (slot != null && slot.slots.isNotEmpty) ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (slot != null && slot.slots.isNotEmpty) ? Colors.green.shade300 : Colors.grey.shade300,
                          ),
                        ),
                        child: (slot != null && slot.slots.isNotEmpty)
                            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Icon(Icons.calendar_month, size: 14, color: Colors.green.shade700),
                                  const SizedBox(width: 6),
                                  Text('${slot.slots.length} ช่วงเวลา',
                                      style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  if (!readOnly) ...[
                                    Icon(Icons.edit_calendar, size: 14, color: Colors.green.shade600),
                                    const SizedBox(width: 4),
                                    Text('แก้ไข', style: TextStyle(fontSize: 11, color: Colors.green.shade600)),
                                  ],
                                ]),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6, runSpacing: 6,
                                  children: slot.slots.map((s) {
                                    final datePart = (s.date != null && s.date!.isNotEmpty)
                                        ? '${thaiShortDateFromStr(s.date!)} ' : '';
                                    // ถูกจองไปแล้ว → เทา (ตรงกับหน้าเพิ่มคาบ)
                                    final taken = slotTakenByPackages(packages, s);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: taken ? Colors.grey.shade400 : const Color(0xFF2E7D32),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        if (taken) ...[
                                          const Icon(Icons.block, size: 11, color: Colors.white),
                                          const SizedBox(width: 3),
                                        ],
                                        Text('$datePart${s.day}  ${s.startTime}–${s.endTime}',
                                            style: TextStyle(
                                              fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600,
                                              decoration: taken ? TextDecoration.lineThrough : null,
                                            )),
                                      ]),
                                    );
                                  }).toList(),
                                ),
                              ])
                            : Row(children: [
                                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(child: Text(readOnly ? 'ยังไม่ได้ตั้งวัน/เวลา' : 'แตะเพื่อตั้งวัน/เวลา',
                                    style: const TextStyle(fontSize: 13, color: Colors.grey))),
                                if (!readOnly) ...[
                                  const Icon(Icons.add_circle_outline, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text('ตั้งค่า', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ]),
                      ),
                    ),
                    if (slot?.notes != null && slot!.notes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.notes, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(child: Text(slot.notes!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
                      ]),
                    ],
                    const SizedBox(height: 10),

                    // วันที่มีสอน (รวมจากนักเรียนทุกคน) — เฉพาะมุมมองครู
                    if (readOnly) _teachingDates(packages),

                    // Students
                    if (students.isNotEmpty) ...[
                      Row(children: [
                        const Icon(Icons.groups_outlined, size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 6),
                        Text('นักเรียน ${students.length} คน', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                      ]),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 4, children: students.values.map((name) =>
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(12)),
                          child: Text(name, style: const TextStyle(fontSize: 11, color: Color(0xFFF97316))),
                        )).toList()),
                      const SizedBox(height: 10),
                    ] else ...[
                      const Text('ยังไม่มีนักเรียน', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 10),
                    ],

                    // Session counts
                    if (totalSessions > 0) ...[
                      Row(children: [
                        _CountBox(label: 'รวมคาบสอน', value: '$totalSessions', color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        _CountBox(label: 'สอนแล้ว', value: '$usedSessions', color: const Color(0xFF2E7D32)),
                        const SizedBox(width: 8),
                        _CountBox(label: 'เหลือ', value: '$remaining', color: statusColor, bold: true),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(value: pct, minHeight: 10, backgroundColor: Colors.grey.shade200, color: statusColor),
                        )),
                        const SizedBox(width: 8),
                        Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                        'สูตร: เหลือ = รวม − สอนแล้ว  ($totalSessions − $usedSessions = $remaining)',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: const Text('ยังไม่มีคาบสอน', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                )),

                // Action bar — เฉพาะ admin (มุมมองครูเป็นรายงานอ่านอย่างเดียว)
                if (!readOnly)
                  Container(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200)), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14))),
                    child: Row(children: [
                      _ActionBtn(icon: Icons.edit_outlined, label: 'Edit', color: const Color(0xFF2E7D32),
                          onTap: () => showTeacherSlotForm(context, teacher: teacher, existing: slot)),
                      _vDivider(),
                      _ActionBtn(icon: Icons.delete_outline, label: 'ลบ', color: Colors.red,
                          onTap: () => _confirmDelete(context, slot)),
                    ]),
                  )
                else
                  const SizedBox(height: 6),
              ]),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, TeacherSlotModel? slot) {
    if (slot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ยังไม่มีข้อมูลเวลาว่างที่จะลบ')));
      return;
    }
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('ลบเวลาว่าง'),
      content: Text('ลบข้อมูลเวลาว่างของ "${teacher.name}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            await FirestoreService.deleteTeacherSlot(teacher.id);
          },
          child: const Text('ลบ', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }

  void _showReport(BuildContext context, List<PackageModel> packages) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _TeacherReportScreen(teacher: teacher, packages: packages)));
  }

  Widget _vDivider() => Container(width: 1, height: 48, color: Colors.grey.shade200);
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _CountBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _CountBox({required this.label, required this.value, required this.color, this.bold = false});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withAlpha(50))),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Column(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ])),
    ),
  );
}

// ── Teacher Report ────────────────────────────────────────────────────────────

class _TeacherReportScreen extends StatelessWidget {
  final UserModel teacher;
  final List<PackageModel> packages;
  const _TeacherReportScreen({required this.teacher, required this.packages});

  @override
  Widget build(BuildContext context) {
    final totalSessions = packages.fold(0, (s, p) => s + p.totalSessions);
    final usedSessions = packages.fold(0, (s, p) => s + p.usedSessions);
    final remaining = totalSessions - usedSessions;

    return Scaffold(
      appBar: AppBar(
        title: Text('รายงาน: ${teacher.name}'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Summary
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.person_outlined, color: Color(0xFF2E7D32)),
              const SizedBox(width: 8),
              Text('${teacher.name} (${teacher.code})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _RStat(label: 'รวมคาบสอน', value: '$totalSessions', color: Colors.blueGrey),
              _RStat(label: 'สอนแล้ว', value: '$usedSessions', color: const Color(0xFF2E7D32)),
              _RStat(label: 'เหลือ', value: '$remaining', color: remaining <= 3 ? Colors.orange : const Color(0xFF2E7D32)),
            ]),
          ]),
        )),
        const SizedBox(height: 12),

        // Per-student packages
        Text('นักเรียน ${packages.length} คน', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        ...packages.map((pkg) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.school_outlined, size: 16, color: Color(0xFFF97316)),
              const SizedBox(width: 6),
              Expanded(child: Text('${pkg.studentName} (${pkg.studentCode})', style: const TextStyle(fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: pkg.isLowBalance ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text(pkg.statusLabel, style: TextStyle(fontSize: 11, color: pkg.isLowBalance ? Colors.orange : Colors.green)),
              ),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              _mini('รวม', '${pkg.totalSessions}', Colors.blueGrey),
              _mini('สอนแล้ว', '${pkg.usedSessions}', const Color(0xFF2E7D32)),
              _mini('เหลือ', '${pkg.remainingSessions}', pkg.statusColor),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pkg.totalSessions > 0 ? (pkg.remainingSessions / pkg.totalSessions).clamp(0.0, 1.0) : 0,
                minHeight: 6, backgroundColor: Colors.grey.shade200, color: pkg.statusColor,
              ),
            ),
          ])),
        )),
      ]),
    );
  }

  Widget _mini(String label, String val, Color color) => Expanded(child: Column(children: [
    Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]));
}

class _RStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _RStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
  ]));
}
