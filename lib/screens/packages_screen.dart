import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../utils/date_format.dart';
import 'package_form_dialog.dart';

class PackagesScreen extends StatefulWidget {
  final String? filterStudentId;
  final String? filterStudentName;
  final String? filterTeacherId;
  final String? filterTeacherName;
  final bool teacherViewOnly; // เมนู "ตามครู": แสดงเฉพาะกลุ่มครู→นักเรียน (ไม่มีรายการ/จัดการคาบ)
  const PackagesScreen({super.key, this.filterStudentId, this.filterStudentName, this.filterTeacherId, this.filterTeacherName, this.teacherViewOnly = false});
  @override
  State<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends State<PackagesScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  bool _byTeacherView = false;

  @override
  void initState() {
    super.initState();
    _byTeacherView = widget.teacherViewOnly; // เมนูตามครู: เริ่ม (และล็อก) ที่มุมมองกลุ่มครู
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _openForm({PackageModel? pkg}) {
    showPackageForm(context, existing: pkg,
        preselectedStudentId: pkg == null ? widget.filterStudentId : null);
  }

  @override
  Widget build(BuildContext context) {
    final isStudentFilter = widget.filterStudentId != null;
    final isTeacherFilter = widget.filterTeacherId != null;
    final isFiltered = isStudentFilter || isTeacherFilter;
    final viewerRole = isTeacherFilter ? 'teacher' : 'student';
    final filterTitle = isStudentFilter
        ? (widget.filterStudentName ?? 'คาบเรียน')
        : isTeacherFilter
            ? (widget.filterTeacherName ?? 'ตารางสอน')
            : widget.teacherViewOnly
                ? 'ครู–ศิษย์'
                : 'จัดการคาบเรียน';

    const canEdit = true;

    return Scaffold(
      appBar: AppBar(
        title: Text(filterTitle),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        actions: [
          if (!isFiltered && !widget.teacherViewOnly)
            TextButton.icon(
              onPressed: () => setState(() => _byTeacherView = !_byTeacherView),
              icon: Icon(_byTeacherView ? Icons.list_rounded : Icons.people_rounded,
                  color: Colors.white, size: 18),
              label: Text(_byTeacherView ? 'รายการ' : 'ตามครู',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
        ],
      ),
      floatingActionButton: (canEdit && !widget.teacherViewOnly)
          ? FloatingActionButton.extended(
              heroTag: 'add_pkg',
              onPressed: () => _openForm(),
              backgroundColor: const Color(0xFFF97316),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มคาบ'),
            )
          : null,
      body: Column(children: [
        if (!isFiltered) Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อนักเรียน ครู หรือรหัส...',
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
          child: StreamBuilder<List<PackageModel>>(
            stream: isStudentFilter
                ? FirestoreService.watchPackagesForUser(widget.filterStudentId!, 'student')
                : isTeacherFilter
                    ? FirestoreService.watchPackagesForUser(widget.filterTeacherId!, 'teacher')
                    : FirestoreService.watchAllPackages(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snap.data ?? [];
              final list = (isFiltered || _search.isEmpty) ? all : all.where((p) =>
                p.studentName.toLowerCase().contains(_search) ||
                p.teacherName.toLowerCase().contains(_search) ||
                p.studentCode.toLowerCase().contains(_search) ||
                p.teacherCode.toLowerCase().contains(_search)).toList();

              if (list.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(_search.isEmpty ? 'ยังไม่มีคาบเรียน' : 'ไม่พบผลการค้นหา',
                      style: const TextStyle(color: Colors.grey)),
                ]));
              }

              if (_byTeacherView && !isFiltered) {
                return _TeacherGroupView(packages: list);
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => PackageCard(
                pkg: list[i],
                onEdit: () => _openForm(pkg: list[i]),
                viewerRole: viewerRole,
                isStudentView: isStudentFilter,
                canEdit: canEdit,
              ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ── Package Card ─────────────────────────────────────────────────────────────

class PackageCard extends StatelessWidget {
  final PackageModel pkg;
  final VoidCallback onEdit;
  final String viewerRole;
  final bool isStudentView;
  final bool canEdit;
  const PackageCard({super.key, required this.pkg, required this.onEdit, this.viewerRole = 'admin', this.isStudentView = false, this.canEdit = true});

  String get _statusLabel {
    if (viewerRole == 'teacher') {
      if (pkg.isExpired) return 'สอนเสร็จแล้ว';
      if (pkg.isLowBalance) return 'ใกล้เสร็จ';
      if (pkg.isCurrentlyInSession) return 'กำลังสอน';
      return 'รอสอน';
    }
    if (pkg.isCurrentlyInSession) return 'กำลังเรียน';
    return pkg.statusLabel;
  }

  void _confirmDelete(BuildContext context) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('ลบคาบเรียน'),
      content: Text('ลบคาบของ "${pkg.studentName}" กับ "${pkg.teacherName}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        TextButton(
          onPressed: () async { Navigator.pop(context); await FirestoreService.deletePackage(pkg.id); },
          child: const Text('ลบ', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }

  void _showAdjustDialog(BuildContext context, {required bool isAdd}) {
    final ctrl = TextEditingController(text: '1');
    showDialog(context: context, builder: (dialogCtx) => AlertDialog(
      title: Text(isAdd ? '➕ เพิ่มคาบ' : '➖ ลบคาบ'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(isAdd ? 'เพิ่มจำนวนคาบในคอร์ส (รวมทั้งหมด)' : 'ลดจำนวนคาบในคอร์ส (รวมทั้งหมด)',
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'จำนวนคาบ',
            suffixText: 'คาบ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('ยกเลิก')),
        ElevatedButton(
          onPressed: () async {
            final n = int.tryParse(ctrl.text) ?? 1;
            if (n <= 0) return;
            Navigator.pop(dialogCtx);
            try {
              if (isAdd) {
                await FirestoreService.adjustSessions(pkg.id, totalDelta: n, remainingDelta: n, studentId: pkg.studentId);
              } else {
                final deduct = n.clamp(1, pkg.remainingSessions > 0 ? pkg.remainingSessions : n);
                await FirestoreService.adjustSessions(pkg.id, totalDelta: -deduct, remainingDelta: -deduct, studentId: pkg.studentId);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: isAdd ? Colors.green : Colors.orange, foregroundColor: Colors.white),
          child: Text(isAdd ? 'เพิ่ม' : 'ลบ'),
        ),
      ],
    ));
  }

  void _tapReschedule(BuildContext context) => _showReschedule(context);

  /// ตัวจัดการหลายช่วงเวลา — ย้าย/ลบ แต่ละ slot, ล็อกเฉพาะช่วงที่เลยเวลาแล้ว
  void _showReschedule(BuildContext context) {
    List<SlotItem> slots = List.from(pkg.effectiveSlots);
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('📅 ย้ายวัน/เวลาเรียน'),
      content: SizedBox(
        width: double.maxFinite,
        child: slots.isEmpty
            ? const Padding(padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('ยังไม่มีช่วงเวลา', style: TextStyle(color: Colors.grey)))
            : Column(mainAxisSize: MainAxisSize.min, children: List.generate(slots.length, (i) {
                final s = slots[i];
                final past = _slotStarted(s);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: past ? Colors.grey.shade100 : const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: past ? Colors.grey.shade300 : const Color(0xFFF97316).withAlpha(80)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: past ? Colors.grey.shade400 : const Color(0xFFF97316), shape: BoxShape.circle),
                      child: Center(child: Text(s.day, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('${s.startTime}–${s.endTime}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                              color: past ? Colors.grey.shade600 : const Color(0xFFF97316))),
                      if (s.date != null && s.date!.isNotEmpty)
                        Text(thaiShortDateFromStr(s.date!), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                    ])),
                    if (past)
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.lock_clock, size: 13, color: Colors.grey.shade500),
                            const SizedBox(width: 2),
                            Text('เลยเวลา', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                          ]))
                    else
                      IconButton(
                        tooltip: 'ย้ายช่วงนี้',
                        icon: const Icon(Icons.edit_calendar, size: 18, color: Color(0xFFF97316)),
                        onPressed: () async {
                          final edited = await _editSlotDialog(ctx, s);
                          if (edited != null) setS(() => slots[i] = edited);
                        },
                      ),
                    IconButton(
                      tooltip: 'ลบช่วงนี้',
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () => setS(() => slots.removeAt(i)),
                    ),
                  ]),
                );
              })),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final Map<String, dynamic> data;
            if (slots.isEmpty) {
              data = {
                'slots': <Map<String, dynamic>>[],
                'scheduledDay': FieldValue.delete(),
                'scheduledTime': FieldValue.delete(),
                'scheduledEndTime': FieldValue.delete(),
                'scheduledDate': FieldValue.delete(),
              };
            } else {
              final f = slots.first;
              data = {
                'slots': slots.map((s) => s.toMap()).toList(),
                'scheduledDay': f.day,
                'scheduledTime': f.startTime,
                'scheduledEndTime': f.endTime,
                'scheduledDate': (f.date != null && f.date!.isNotEmpty) ? f.date : FieldValue.delete(),
              };
            }
            await FirestoreService.updatePackageFields(pkg.id, data);
            await FirestoreService.resyncPackageSchedule(pkg.id);
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white),
          child: const Text('บันทึก'),
        ),
      ],
    )));
  }

  /// แก้ไขช่วงเวลา 1 slot (วัน/วันที่/เวลา) — คืน SlotItem ใหม่หรือ null ถ้ายกเลิก
  Future<SlotItem?> _editSlotDialog(BuildContext context, SlotItem initial) {
    String? day = initial.day.isNotEmpty ? initial.day : null;
    DateTime? date = (initial.date != null && initial.date!.isNotEmpty) ? parseDateStr(initial.date!) : null;
    TimeOfDay? startTime = initial.startTime.isNotEmpty ? _parseTime(initial.startTime) : null;
    TimeOfDay? endTime = initial.endTime.isNotEmpty ? _parseTime(initial.endTime) : null;

    return showDialog<SlotItem>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: const Text('ย้ายช่วงเวลา'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('วันที่ (ถ้าระบุ วันจะคำนวณให้)', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(context: ctx, initialDate: date ?? nowThai(),
                firstDate: DateTime(2020), lastDate: DateTime(2030));
            if (d != null) setS(() { date = d; day = thaiDayAbbr(d); });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: date != null ? const Color(0xFFE3F2FD) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: date != null ? const Color(0xFFF97316) : Colors.grey.shade300),
            ),
            child: Row(children: [
              Icon(Icons.calendar_month, size: 18, color: date != null ? const Color(0xFFF97316) : Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Text(date != null ? thaiDateFull(date!) : 'แตะเพื่อเลือกวันที่ (ไม่บังคับ)',
                  style: TextStyle(fontSize: 13, fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                      color: date != null ? const Color(0xFFF97316) : Colors.grey))),
              if (date != null)
                GestureDetector(onTap: () => setS(() => date = null), child: const Icon(Icons.clear, size: 18, color: Colors.grey)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        const Text('วัน', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: PackageModel.days.map((d) => ChoiceChip(
          label: Text(d),
          selected: day == d,
          onSelected: (_) => setS(() { day = d; date = null; }),
          selectedColor: const Color(0xFFF97316),
          labelStyle: TextStyle(color: day == d ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
        )).toList()),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _TimeTile(label: 'เริ่ม', time: startTime, onTap: () async {
            final t = await showTimePicker(context: ctx, initialTime: startTime ?? const TimeOfDay(hour: 9, minute: 0),
                builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!));
            if (t != null) setS(() => startTime = t);
          })),
          const SizedBox(width: 8),
          Expanded(child: _TimeTile(label: 'สิ้นสุด', time: endTime, onTap: () async {
            final t = await showTimePicker(context: ctx, initialTime: endTime ?? const TimeOfDay(hour: 10, minute: 0),
                builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!));
            if (t != null) setS(() => endTime = t);
          })),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
        ElevatedButton(
          onPressed: () {
            if (day == null || startTime == null) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('กรุณาเลือกวันและเวลาเริ่ม')));
              return;
            }
            Navigator.pop(ctx, SlotItem(
              day: day!,
              startTime: _fmtTime(startTime!),
              endTime: endTime != null ? _fmtTime(endTime!) : _fmtTime(startTime!),
              date: date != null ? toStorageDateStr(date!) : null,
            ));
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white),
          child: const Text('ตกลง'),
        ),
      ],
    )));
  }

  void _showReport(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PackageReportScreen(pkg: pkg)));
  }

  TimeOfDay _parseTime(String t) {
    final p = t.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  /// ช่วงเวลานี้ถึง/เลยเวลาเริ่มแล้วหรือยัง — ใช้ล็อกการย้ายเฉพาะ slot ที่เลยเวลา
  bool _slotStarted(SlotItem s) {
    final now = nowThai();
    final sp = s.startTime.split(':');
    if (sp.length != 2) return false;
    final startMin = (int.tryParse(sp[0]) ?? 0) * 60 + (int.tryParse(sp[1]) ?? 0);

    // วันที่เจาะจง → เทียบวันที่+เวลาตรงๆ
    if (s.date != null && s.date!.isNotEmpty) {
      final d = parseDateStr(s.date!);
      if (d == null) return false;
      final lessonStart = DateTime(d.year, d.month, d.day, startMin ~/ 60, startMin % 60);
      return !now.isBefore(lessonStart);
    }
    // ตารางประจำสัปดาห์ → ล็อกเฉพาะวันเรียนวันนี้ที่เลยเวลาเริ่มแล้ว (วันอื่นย้ายได้)
    const dayMap = {'อา': 7, 'จ': 1, 'อ': 2, 'พ': 3, 'พฤ': 4, 'ศ': 5, 'ส': 6};
    if (dayMap[s.day] != now.weekday) return false;
    return (now.hour * 60 + now.minute) >= startMin;
  }

  /// แพ็กเกจมีช่วงที่ยังย้ายได้ไหม (ยังไม่เลยเวลาอย่างน้อย 1 ช่วง)
  bool get _hasMovableSlot => pkg.effectiveSlots.any((s) => !_slotStarted(s));

  @override
  Widget build(BuildContext context) {
    final pct = pkg.totalSessions > 0 ? (pkg.remainingSessions / pkg.totalSessions).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Header row: status + report button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: pkg.statusColor.withAlpha(20),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: pkg.statusColor, borderRadius: BorderRadius.circular(20)),
              child: Text(
                _statusLabel,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showReport(context),
              icon: const Icon(Icons.bar_chart, size: 16),
              label: const Text('รายงาน', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: Colors.blueGrey, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2)),
            ),
          ]),
        ),

        Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 0), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student + Teacher
            // Primary person (student when teacher views, teacher when student/admin views)
            Row(children: [
              Icon(viewerRole == 'teacher' ? Icons.school_outlined : Icons.school_outlined,
                  size: 16, color: const Color(0xFFF97316)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                viewerRole == 'teacher' ? pkg.studentName : pkg.studentName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              Text(
                viewerRole == 'teacher' ? pkg.studentCode : pkg.studentCode,
                style: const TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.person_outlined, size: 16, color: Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                viewerRole == 'teacher' ? 'ครู: ${pkg.teacherName}' : pkg.teacherName,
                style: const TextStyle(fontSize: 14, color: Colors.black87))),
              Text(pkg.teacherCode, style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 13)),
            ]),
            const SizedBox(height: 8),

            // Schedule row
            GestureDetector(
              onTap: canEdit ? () => _tapReschedule(context) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFFF97316)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(pkg.scheduleLabel,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFF97316), fontWeight: FontWeight.w600))),
                  if (canEdit) ...[
                    const SizedBox(width: 6),
                    Icon(_hasMovableSlot ? Icons.edit_calendar : Icons.lock_clock,
                        size: 14, color: _hasMovableSlot ? const Color(0xFFF97316) : Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(_hasMovableSlot ? 'จัดการ' : 'เลยเวลา',
                        style: TextStyle(fontSize: 11,
                            color: _hasMovableSlot ? const Color(0xFFF97316) : Colors.grey.shade500)),
                  ],
                ]),
              ),
            ),
            if (pkg.notes != null && pkg.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.notes, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(child: Text(pkg.notes!, style: const TextStyle(fontSize: 12, color: Colors.black54))),
              ]),
            ],
            // ── Google Meet link (student view only) ─────────────────
            if (isStudentView) ...[
              const SizedBox(height: 8),
              StreamBuilder<UserModel?>(
                stream: FirestoreService.watchUser(pkg.teacherId),
                builder: (context, snap) {
                  final link = snap.data?.googleMeetLink;
                  if (link == null || link.trim().isEmpty) return const SizedBox.shrink();
                  return InkWell(
                    onTap: () => web.window.open(link.trim(), '_blank'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withAlpha(60), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: const Row(children: [
                        Icon(Icons.video_call_rounded, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text('เข้าเรียน Google Meet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        Spacer(),
                        Icon(Icons.open_in_new, size: 14, color: Colors.white70),
                      ]),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 12),

            // Session counts
            Row(children: [
              _CountBox(label: 'จำนวนคาบ', value: '${pkg.totalSessions}', color: Colors.blueGrey),
              const SizedBox(width: 8),
              _CountBox(label: viewerRole == 'teacher' ? 'สอนแล้ว' : 'เรียนแล้ว', value: '${pkg.usedSessions}', color: Colors.green),
              const SizedBox(width: 8),
              _CountBox(label: 'คงเหลือ', value: '${pkg.remainingSessions}', color: pkg.statusColor, bold: true),
            ]),
            const SizedBox(height: 8),

            // Progress bar with formula label
            Row(children: [
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  color: pkg.statusColor,
                ),
              )),
              const SizedBox(width: 8),
              Text('${(pct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: pkg.statusColor, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Text(
              'เหลือ = รวม − เรียนแล้ว  (${pkg.totalSessions} − ${pkg.usedSessions} = ${pkg.remainingSessions})',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 10),
          ],
        )),

        // Action buttons row (admin only)
        if (canEdit)
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(children: [
              _ActionBtn(icon: Icons.remove_circle_outline, label: 'ลบคาบ', color: Colors.orange, onTap: () => _showAdjustDialog(context, isAdd: false)),
              _vDivider(),
              _ActionBtn(icon: Icons.add_circle_outline, label: 'เพิ่มคาบ', color: Colors.green, onTap: () => _showAdjustDialog(context, isAdd: true)),
              _vDivider(),
              _ActionBtn(icon: Icons.edit_outlined, label: 'Edit', color: const Color(0xFFF97316), onTap: onEdit),
              _vDivider(),
              _ActionBtn(icon: Icons.delete_outline, label: 'ลบ', color: Colors.red, onTap: () => _confirmDelete(context)),
            ]),
          ),
      ]),
    );
  }

  Widget _vDivider() => Container(width: 1, height: 48, color: Colors.grey.shade200);
}

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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );
}

// ── Teacher-grouped view ──────────────────────────────────────────────────────

class _TeacherGroupView extends StatelessWidget {
  final List<PackageModel> packages;
  const _TeacherGroupView({required this.packages});

  // ใช้ตัวย่อตรงกับที่เก็บใน Firestore (PackageModel.days)
  static const _dayOrder = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];
  static const _dayWeekday = {
    'จ':  DateTime.monday,
    'อ':  DateTime.tuesday,
    'พ':  DateTime.wednesday,
    'พฤ': DateTime.thursday,
    'ศ':  DateTime.friday,
    'ส':  DateTime.saturday,
    'อา': DateTime.sunday,
  };
  static const _dayFull = {
    'จ':  'จันทร์',
    'อ':  'อังคาร',
    'พ':  'พุธ',
    'พฤ': 'พฤหัสบดี',
    'ศ':  'ศุกร์',
    'ส':  'เสาร์',
    'อา': 'อาทิตย์',
  };

  DateTime _nextDate(String day) {
    final target = _dayWeekday[day]!;
    final now = nowThai();
    var diff = target - now.weekday;
    if (diff < 0) diff += 7;
    return now.add(Duration(days: diff));
  }

  String _formatDate(String? day) {
    if (day == null || !_dayWeekday.containsKey(day)) return 'ยังไม่กำหนดวัน';
    final d = _nextDate(day);
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '${_dayFull[day]}ที่ $dd/$mm/${d.year + 543}'; // พ.ศ.
  }

  @override
  Widget build(BuildContext context) {
    // Group by teacherId
    final grouped = <String, List<PackageModel>>{};
    for (final pkg in packages) {
      grouped.putIfAbsent(pkg.teacherId, () => []).add(pkg);
    }

    // Sort teachers by name
    final teachers = grouped.entries.toList()
      ..sort((a, b) => a.value.first.teacherName.compareTo(b.value.first.teacherName));

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      itemCount: teachers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final pkgs = teachers[i].value;
        final teacherName = pkgs.first.teacherName;
        final teacherCode = pkgs.first.teacherCode;

        // Sort students by day order then time
        final sorted = List<PackageModel>.from(pkgs)..sort((a, b) {
          final ai = a.scheduledDay != null ? _dayOrder.indexOf(a.scheduledDay!) : 99;
          final bi = b.scheduledDay != null ? _dayOrder.indexOf(b.scheduledDay!) : 99;
          if (ai != bi) return ai.compareTo(bi);
          return (a.scheduledTime ?? '').compareTo(b.scheduledTime ?? '');
        });

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ExpansionTile(
            initiallyExpanded: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFF97316).withAlpha(20),
              child: const Icon(Icons.person_rounded, color: Color(0xFFF97316), size: 20),
            ),
            title: Text(teacherName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Row(children: [
              Text(teacherCode,
                  style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text('${sorted.length} นักเรียน',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
            children: sorted.asMap().entries.map((e) => _StudentScheduleRow(
              index: e.key + 1,
              pkg: e.value,
              dateLabel: (e.value.scheduledDate != null && e.value.scheduledDate!.isNotEmpty)
                  ? thaiDateFromStr(e.value.scheduledDate!)
                  : _formatDate(e.value.scheduledDay),
            )).toList(),
          ),
        );
      },
    );
  }
}

class _StudentScheduleRow extends StatelessWidget {
  final int index;
  final PackageModel pkg;
  final String dateLabel;
  const _StudentScheduleRow({required this.index, required this.pkg, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    final timeLabel = pkg.scheduledTime != null
        ? '${pkg.scheduledTime}${pkg.scheduledEndTime != null ? ' – ${pkg.scheduledEndTime}' : ''} น.'
        : 'ยังไม่กำหนดเวลา';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── ลำดับ ────────────────────────────────────────────────────
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFFF97316).withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text('$index',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  color: Color(0xFFF97316)))),
        ),
        const SizedBox(width: 12),
        // ── ข้อมูลนักเรียน ──────────────────────────────────────────
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.school_outlined, size: 14, color: Color(0xFF1565C0)),
            const SizedBox(width: 4),
            Expanded(child: Text(pkg.studentName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            Text(pkg.studentCode,
                style: const TextStyle(color: Color(0xFF1565C0), fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.calendar_today, size: 12, color: Color(0xFFF97316)),
            const SizedBox(width: 4),
            Text(dateLabel,
                style: const TextStyle(fontSize: 12, color: Color(0xFFF97316))),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.access_time, size: 12, color: Colors.blueGrey),
            const SizedBox(width: 4),
            Text(timeLabel,
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
          ]),
        ])),
      ]),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;
  const _TimeTile({required this.label, required this.time, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          time != null ? '${time!.hour.toString().padLeft(2,'0')}:${time!.minute.toString().padLeft(2,'0')}' : '--:--',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF97316)),
        ),
      ]),
    ),
  );
}

// ── Package Report Screen ────────────────────────────────────────────────────

class PackageReportScreen extends StatelessWidget {
  final PackageModel pkg;
  const PackageReportScreen({super.key, required this.pkg});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('รายงาน: ${pkg.studentName}'),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<SessionModel>>(
        stream: FirestoreService.watchSessionsForUser(pkg.studentId, 'student'),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final sessions = (snap.data ?? []).where((s) => s.packageId == pkg.id).toList();

          return ListView(padding: const EdgeInsets.all(16), children: [
            // Summary card
            Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${pkg.studentName} (${pkg.studentCode})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('ครู: ${pkg.teacherName} (${pkg.teacherCode})', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 12),
                Row(children: [
                  _ReportStat(label: 'รวมคาบ', value: '${pkg.totalSessions}', color: Colors.blueGrey),
                  _ReportStat(label: 'เรียนแล้ว', value: '${pkg.usedSessions}', color: Colors.green),
                  _ReportStat(label: 'เหลือ', value: '${pkg.remainingSessions}', color: pkg.statusColor),
                ]),
              ]),
            )),
            const SizedBox(height: 12),
            Text('ประวัติคาบเรียน (${sessions.length} คาบ)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('ยังไม่มีประวัติ', style: TextStyle(color: Colors.grey))))
            else
              ...sessions.asMap().entries.map((e) {
                final s = e.value;
                final i = e.key;
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFF97316).withAlpha(20),
                      child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFFF97316), fontWeight: FontWeight.bold)),
                    ),
                    title: Text(thaiDateTimeFromStr(s.date, startTime: s.startTime, endTime: s.endTime)),
                    subtitle: Text([
                      if (s.language != null) s.language!,
                      if (s.skill != null) s.skill!,
                      if (s.isLate) 'สาย',
                      if (s.isAbsent) 'ขาด',
                    ].join(' · '), style: const TextStyle(fontSize: 12)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _sColor(s.status).withAlpha(25), borderRadius: BorderRadius.circular(10)),
                      child: Text(SessionModel.statusLabel(s.status), style: TextStyle(fontSize: 11, color: _sColor(s.status), fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              }),
          ]);
        },
      ),
    );
  }

  Color _sColor(String s) {
    switch (s) {
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'in_progress': return Colors.orange;
      default: return Colors.blue;
    }
  }
}

class _ReportStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ReportStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
  ]));
}
