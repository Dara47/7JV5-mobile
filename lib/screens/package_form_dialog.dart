import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../utils/date_format.dart';
import '../widgets/user_search_field.dart';

Future<void> showPackageForm(BuildContext context, {PackageModel? existing, String? preselectedStudentId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PackageFormSheet(existing: existing, preselectedStudentId: preselectedStudentId),
  );
}

class _PackageFormSheet extends StatefulWidget {
  final PackageModel? existing;
  final String? preselectedStudentId;
  const _PackageFormSheet({this.existing, this.preselectedStudentId});
  @override
  State<_PackageFormSheet> createState() => _PackageFormSheetState();
}

class _PackageFormSheetState extends State<_PackageFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _totalCtrl = TextEditingController();
  final _usedCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<UserModel> _students = [];
  List<UserModel> _teachers = [];
  UserModel? _student;
  UserModel? _teacher;

  // รายการช่วงเวลาที่เลือกแล้ว (หลายช่วงได้)
  List<SlotItem> _slots = [];
  // แถวร่างสำหรับเพิ่มหลายช่วง — แต่ละแถวเลือกวันที่(ปฏิทิน)+เวลาเริ่ม/สิ้นสุดได้เอง
  final List<_DraftSlot> _drafts = [_DraftSlot()];

  TeacherSlotModel? _teacherSlot;
  List<PackageModel> _takenSlotPackages = [];
  PackageModel? _existingPkg; // แพ็กเกจเดิมของนักเรียน+ครูคู่นี้ (โควตาร่วม)
  bool _loadingUsers = true;
  bool _loadingSlot = false;
  bool _saving = false;
  bool _isGroup = false; // คลาสกลุ่ม — อนุญาตจองเวลาซ้ำกับนักเรียนคนอื่นของครูคนเดียวกัน

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    if (_isEdit) {
      final p = widget.existing!;
      _totalCtrl.text = p.totalSessions.toString();
      _usedCtrl.text = p.usedSessions.toString();
      _notesCtrl.text = p.notes ?? '';
      _slots = List.from(p.effectiveSlots);
      _isGroup = p.isGroup;
    }
  }

  Future<void> _loadTeacherSlot(String teacherId) async {
    setState(() => _loadingSlot = true);
    final doc = await FirebaseFirestore.instance.collection('teacherSlots').doc(teacherId).get();
    if (!mounted) return;
    setState(() {
      _teacherSlot = doc.exists ? TeacherSlotModel.fromDoc(doc) : null;
      _loadingSlot = false;
    });
    await _loadTakenSlots();
  }

  Future<void> _loadTakenSlots() async {
    if (_teacher == null) return;
    // โหลด "ทุกแพ็กเกจของครูคนนี้" (ทุกนักเรียน) เพื่อกันจองเวลาชนกัน
    final pkgs = await FirestoreService.getPackagesForUser(_teacher!.id, 'teacher');
    if (!mounted) return;
    // หาแพ็กเกจเดิมของนักเรียน+ครูคู่นี้ (เพื่อเพิ่ม slot ใช้โควตาร่วม)
    PackageModel? existing;
    if (!_isEdit && _student != null) {
      for (final p in pkgs) {
        if (p.studentId == _student!.id) { existing = p; break; }
      }
    }
    setState(() {
      _takenSlotPackages = pkgs
          .where((p) => !_isEdit || p.id != widget.existing!.id) // ไม่นับตัวเองตอนแก้ไข
          .toList();
      _existingPkg = existing;
      // ถ้ามีแพ็กเกจเดิม → ใช้โควตาเดิม (read-only)
      if (existing != null) {
        _totalCtrl.text = existing.totalSessions.toString();
        _usedCtrl.text = existing.usedSessions.toString();
      }
    });
  }

  bool _isSlotTaken(SlotItem s) {
    return _takenSlotPackages.any((p) => _conflicts(p, s.day, s.date, s.startTime, s.endTime));
  }

  /// เวลา 2 ช่วงทับซ้อนกันไหม ('HH:mm')
  bool _timeOverlap(String s1, String e1, String s2, String e2) {
    int m(String t) {
      final p = t.split(':');
      if (p.length != 2) return -1;
      return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
    }
    final a1 = m(s1), b1 = m(e1.isEmpty ? s1 : e1);
    final a2 = m(s2), b2 = m(e2.isEmpty ? s2 : e2);
    if (a1 < 0 || a2 < 0) return false;
    return a1 < b2 && a2 < b1;
  }

  /// แพ็กเกจ p (ทุก slot) ชนกับช่วง (day, date, start–end) ไหม
  /// - ต้องวันเดียวกัน + เวลาทับซ้อน
  /// - วันที่: ถ้าทั้งคู่ระบุวันที่เจาะจง ต้องตรงกันถึงชน / ถ้าฝ่ายใดเป็น recurring ถือว่าคลุมทุกสัปดาห์ = ชน
  bool _conflicts(PackageModel p, String day, String? dateStr, String start, String end) {
    final nDate = dateStr ?? '';
    for (final sl in p.effectiveSlots) {
      if (sl.day != day) continue;
      final pDate = sl.date ?? '';
      if (pDate.isNotEmpty && nDate.isNotEmpty && pDate != nDate) continue;
      if (_timeOverlap(sl.startTime, sl.endTime, start, end)) return true;
    }
    return false;
  }

  bool _isSlotPast(SlotItem s) {
    final now = nowThai();
    // slot ที่ระบุวันที่เจาะจง
    if (s.date != null && s.date!.isNotEmpty) {
      final d = parseDateStr(s.date!);
      if (d == null) return false;
      final today = DateTime(now.year, now.month, now.day);
      final slotDay = DateTime(d.year, d.month, d.day);
      if (slotDay.isBefore(today)) return true;   // วันที่ผ่านมาแล้ว
      if (slotDay.isAfter(today)) return false;    // ยังไม่ถึง
      // วันนี้ → เทียบเวลา
    } else {
      const dayMap = {'อา': 7, 'จ': 1, 'อ': 2, 'พ': 3, 'พฤ': 4, 'ศ': 5, 'ส': 6};
      if (dayMap[s.day] != now.weekday) return false;
    }
    try {
      final ref = s.endTime.isNotEmpty ? s.endTime : s.startTime;
      final p = ref.split(':');
      final slotEndMinutes = int.parse(p[0]) * 60 + int.parse(p[1]);
      final nowMinutes = now.hour * 60 + now.minute;
      return nowMinutes >= slotEndMinutes;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadUsers() async {
    final db = FirebaseFirestore.instance;
    final sSnap = await db.collection('users').where('role', isEqualTo: 'student').get();
    final tSnap = await db.collection('users').where('role', isEqualTo: 'teacher').get();
    if (!mounted) return;
    final students = sSnap.docs.map(UserModel.fromDoc).toList()..sort((a, b) => a.code.compareTo(b.code));
    final teachers = tSnap.docs.map(UserModel.fromDoc).toList()..sort((a, b) => a.code.compareTo(b.code));
    setState(() {
      _students = students;
      _teachers = teachers;
      if (_isEdit) {
        try { _student = students.firstWhere((u) => u.id == widget.existing!.studentId); } catch (_) {}
        try { _teacher = teachers.firstWhere((u) => u.id == widget.existing!.teacherId); } catch (_) {}
      } else if (widget.preselectedStudentId != null) {
        try {
          final s = students.firstWhere((u) => u.id == widget.preselectedStudentId);
          _student = s;
          if (s.defaultSessions != null) _totalCtrl.text = s.defaultSessions.toString();
        } catch (_) {}
      }
      _loadingUsers = false;
    });
    if (_isEdit && _teacher != null) _loadTeacherSlot(_teacher!.id);
  }

  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) => showTimePicker(
        context: context,
        initialTime: initial,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );

  Future<void> _pickDraftDate(_DraftSlot draft) async {
    final now = nowThai();
    final d = await showDatePicker(
      context: context,
      initialDate: draft.date ?? now,
      firstDate: DateTime(now.year, now.month, now.day), // ห้ามเลือกวันในอดีต
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => draft.date = d);
  }

  /// เพิ่มทุกแถวร่างที่กรอกครบ เข้ารายการ "คาบเรียนที่เลือก"
  void _commitDrafts() {
    final now = nowThai();
    int added = 0, skipped = 0;
    String? error;

    // ตรวจก่อน: ทุกแถวที่ "เริ่มกรอกแล้ว" ต้องครบ (วันที่ + เริ่ม + สิ้นสุด)
    for (final d in _drafts) {
      if (d.isEmpty) continue;
      if (!d.isComplete) {
        error = 'มีแถวที่กรอกไม่ครบ — ต้องเลือกวันที่ เวลาเริ่ม และเวลาสิ้นสุด';
        break;
      }
    }
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() {
      for (final d in _drafts) {
        if (!d.isComplete) continue;
        final dt = d.date!;
        final start = _fmtTime(d.start!);
        final startDt = DateTime(dt.year, dt.month, dt.day, d.start!.hour, d.start!.minute);
        // ข้ามวัน/เวลาที่ผ่านไปแล้ว
        if (now.isAfter(startDt)) { skipped++; continue; }
        final dateStr = toStorageDateStr(dt);
        // กันซ้ำกับช่วงที่มีอยู่แล้ว (วันที่ + เวลาเริ่ม เหมือนกัน)
        if (_slots.any((s) => s.date == dateStr && s.startTime == start)) {
          skipped++; continue;
        }
        _slots.add(SlotItem(
          day: thaiDayAbbr(dt),
          startTime: start,
          endTime: _fmtTime(d.end!),
          date: dateStr,
        ));
        added++;
      }
      // รีเซ็ตเหลือแถวว่าง 1 แถว
      _drafts
        ..clear()
        ..add(_DraftSlot());
    });

    if (added == 0 && skipped == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ยังไม่มีแถวที่กรอก — เลือกวันที่และเวลาก่อน')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(skipped > 0
          ? 'เพิ่ม $added ช่วง (ข้ามที่ซ้ำ/ผ่านแล้ว $skipped ช่วง)'
          : 'เพิ่ม $added ช่วง'),
      backgroundColor: const Color(0xFF2E7D32),
      duration: const Duration(seconds: 2),
    ));
  }

  /// แตะชิป "เวลาว่างของครู" → เพิ่มเข้ารายการทันที
  void _addSlotFromTeacher(SlotItem s) {
    final dateStr = (s.date != null && s.date!.isNotEmpty) ? s.date : null;
    if (_slots.any((x) => x.date == dateStr && x.startTime == s.startTime && x.day == s.day)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('ช่วงเวลานี้อยู่ในรายการแล้ว')));
      return;
    }
    setState(() => _slots.add(SlotItem(
      day: s.day, startTime: s.startTime, endTime: s.endTime, date: dateStr)));
  }

  // Auto-calculate remaining = total - used
  int get _calcRemaining {
    final total = int.tryParse(_totalCtrl.text) ?? 0;
    final used = int.tryParse(_usedCtrl.text) ?? 0;
    return (total - used).clamp(0, 9999);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_student == null) { _snack('กรุณาเลือกนักเรียน'); return; }
    if (_teacher == null) { _snack('กรุณาเลือกครู'); return; }

    // มีแถวช่วงเวลาที่กรอกค้าง (เริ่มกรอกแล้วแต่ยังไม่ครบ วันที่/เริ่ม/สิ้นสุด) → บันทึกไม่ได้
    // ป้องกันกรณีเลือกเวลาเริ่มแต่ไม่ลงเวลาสิ้นสุดแล้วกดบันทึกเลย (ข้อมูลจะหายเงียบ)
    if (_drafts.any((d) => !d.isEmpty && !d.isComplete)) {
      _snack('มีช่วงเวลาที่กรอกไม่ครบ — ต้องเลือกทั้งวันที่ เวลาเริ่ม และเวลาสิ้นสุด แล้วกด "เพิ่มเข้ารายการ"');
      return;
    }

    setState(() => _saving = true);

    // ── กันจองเวลาชนกัน (double-booking) — เช็คทุกช่วงในรายการ ──
    // โหมดเรียนกลุ่ม: ข้ามการบล็อก (ตั้งใจให้เวลาซ้ำกับนักเรียนคนอื่นของครูคนเดียวกันได้)
    if (!_isGroup && _slots.isNotEmpty) {
      try {
        final teacherPkgs = await FirestoreService.getPackagesForUser(_teacher!.id, 'teacher');
        for (final slot in _slots) {
          PackageModel? conflict;
          for (final p in teacherPkgs) {
            if (_isEdit && p.id == widget.existing!.id) continue; // ข้ามตัวเอง
            if (_existingPkg != null && p.id == _existingPkg!.id) continue; // ข้ามแพ็กเกจที่กำลังเพิ่มเข้าไป
            if (_conflicts(p, slot.day, slot.date, slot.startTime, slot.endTime)) { conflict = p; break; }
          }
          if (conflict != null) {
            if (mounted) {
              setState(() => _saving = false);
              final dp = (slot.date != null && slot.date!.isNotEmpty) ? '${thaiShortDateFromStr(slot.date!)} ' : '';
              _snack('ช่วง $dp${slot.day} ${slot.startTime} ถูกจองโดย ${conflict.studentName} แล้ว');
            }
            return;
          }
        }
      } catch (_) {/* ถ้าเช็คไม่ได้ ปล่อยให้บันทึกต่อ */}
    }

    // ── โหมดเพิ่มช่วงเวลาในแพ็กเกจเดิม (ใช้โควตาคาบร่วมกัน ไม่สร้างโควตาใหม่) ──
    if (_existingPkg != null) {
      if (_slots.isEmpty) {
        setState(() => _saving = false);
        _snack('กรุณาเลือกวันและเวลาที่จะเพิ่ม');
        return;
      }
      final merged = [..._existingPkg!.effectiveSlots, ..._slots];
      try {
        await FirestoreService.updatePackageFields(_existingPkg!.id, {
          'slots': merged.map((s) => s.toMap()).toList(),
          if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
          'isGroup': _isGroup || _existingPkg!.isGroup,
        });
        await FirestoreService.resyncPackageSchedule(_existingPkg!.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) { _snack('เกิดข้อผิดพลาด: $e'); setState(() => _saving = false); }
      }
      return;
    }

    final total = int.tryParse(_totalCtrl.text) ?? 0;
    // ช่วงแรกใช้เป็น scheduled* เพื่อความเข้ากันได้กับการแสดงผลเดิม
    final first = _slots.isNotEmpty ? _slots.first : null;

    final data = {
      'studentId': _student!.id, 'teacherId': _teacher!.id,
      'studentName': _student!.name, 'teacherName': _teacher!.name,
      'studentCode': _student!.code, 'teacherCode': _teacher!.code,
      'totalSessions': total,
      'remainingSessions': _calcRemaining,
      'status': 'active',
      if (first != null) 'scheduledDay': first.day,
      if (first != null && first.date != null && first.date!.isNotEmpty)
        'scheduledDate': first.date
      else if (_isEdit && widget.existing!.scheduledDate != null)
        'scheduledDate': FieldValue.delete(), // ช่วงแรกไม่มีวันที่เจาะจง → ลบค่าเดิม
      if (first != null) 'scheduledTime': first.startTime,
      if (first != null) 'scheduledEndTime': first.endTime,
      if (_slots.isNotEmpty) 'slots': _slots.map((s) => s.toMap()).toList(),
      if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
      'isGroup': _isGroup,
    };

    try {
      if (_isEdit) {
        await FirestoreService.updatePackageFields(widget.existing!.id, data);
        await FirestoreService.resyncPackageSchedule(widget.existing!.id);
      } else {
        await FirestoreService.addPackage(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('เกิดข้อผิดพลาด: $e');
      setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _totalCtrl.dispose(); _usedCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),

        // Title bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: [
            Icon(_isEdit ? Icons.edit_outlined : Icons.add_circle_outline, color: const Color(0xFFF97316)),
            const SizedBox(width: 10),
            Text(_isEdit ? 'แก้ไขคาบเรียน' : 'เพิ่มคาบเรียนใหม่',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1),

        // Form content (scrollable)
        Flexible(
          child: _loadingUsers
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // ── นักเรียน ──
                      _label('👤 นักเรียน', required: !_isEdit && widget.preselectedStudentId == null),
                      const SizedBox(height: 6),
                      UserSearchField(
                        users: _students,
                        currentName: _student?.name,
                        currentCode: _student?.code,
                        hint: 'เลือกนักเรียน...',
                        title: 'ค้นหานักเรียน',
                        enabled: !_isEdit && widget.preselectedStudentId == null,
                        color: const Color(0xFFF97316),
                        onSelected: (u) {
                          setState(() {
                            _student = u;
                            _takenSlotPackages = [];
                            if (u.defaultSessions != null && _totalCtrl.text.isEmpty) {
                              _totalCtrl.text = u.defaultSessions.toString();
                            }
                          });
                          if (_teacher != null) _loadTakenSlots();
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── ครู ──
                      _label('🎓 ครู', required: !_isEdit),
                      const SizedBox(height: 6),
                      UserSearchField(
                        users: _teachers,
                        currentName: _teacher?.name,
                        currentCode: _teacher?.code,
                        hint: 'เลือกครู...',
                        title: 'ค้นหาครู',
                        enabled: !_isEdit,
                        color: const Color(0xFF2E7D32),
                        onSelected: (u) {
                          setState(() { _teacher = u; _teacherSlot = null; });
                          _loadTeacherSlot(u.id);
                        },
                      ),
                      // ── เวลาว่างครู ──
                      if (_teacher != null) ...[
                        const SizedBox(height: 8),
                        // โหมดเรียนกลุ่ม — เปิดเพื่อจองเวลาซ้ำกับนักเรียนคนอื่นของครูคนเดียวกัน
                        Container(
                          decoration: BoxDecoration(
                            color: _isGroup ? const Color(0xFFF3E5F5) : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _isGroup ? const Color(0xFF8E24AA) : Colors.grey.shade300),
                          ),
                          child: SwitchListTile(
                            value: _isGroup,
                            onChanged: (v) => setState(() => _isGroup = v),
                            activeThumbColor: const Color(0xFF6A1B9A),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            secondary: Icon(Icons.groups,
                                color: _isGroup ? const Color(0xFF6A1B9A) : Colors.grey),
                            title: const Text('เรียนกลุ่ม',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              _isGroup
                                  ? 'ลงเวลาซ้ำกับนักเรียนคนอื่นของครูคนนี้ได้'
                                  : 'ปิด = กันเวลาชน (1 ช่วง 1 คน)',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_loadingSlot)
                          const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                        else if (_teacherSlot != null && _teacherSlot!.slots.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Row(children: [
                                Icon(Icons.schedule, size: 14, color: Color(0xFF2E7D32)),
                                SizedBox(width: 6),
                                Text('เวลาว่างของครู — กดเพื่อเพิ่มเข้ารายการ',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                              ]),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6, runSpacing: 6,
                                children: _teacherSlot!.slots.map((s) {
                                  final taken = _isSlotTaken(s);
                                  final past = _isSlotPast(s);
                                  // โหมดกลุ่ม: ช่วงที่ถูกจองแล้วเลือกได้ (เป็นกลุ่ม) ไม่บล็อก
                                  final group = taken && _isGroup;
                                  final disabled = past || (taken && !_isGroup);
                                  final bg = group
                                      ? const Color(0xFF6A1B9A)
                                      : taken
                                          ? Colors.grey.shade300
                                          : past
                                              ? Colors.orange.shade100
                                              : const Color(0xFF2E7D32);
                                  return GestureDetector(
                                    onTap: disabled ? null : () => _addSlotFromTeacher(s),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: bg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: past && !taken
                                            ? Border.all(color: Colors.orange.shade300)
                                            : null,
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        if (group)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 4),
                                            child: Icon(Icons.groups, size: 12, color: Colors.white),
                                          )
                                        else if (taken)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 4),
                                            child: Icon(Icons.block, size: 12, color: Colors.grey),
                                          )
                                        else if (past)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 4),
                                            child: Icon(Icons.history, size: 12, color: Colors.orange),
                                          )
                                        else
                                          const Padding(
                                            padding: EdgeInsets.only(right: 4),
                                            child: Icon(Icons.add, size: 12, color: Colors.white),
                                          ),
                                        Text(
                                            '${(s.date != null && s.date!.isNotEmpty) ? '${thaiShortDateFromStr(s.date!)} ' : ''}${s.day}  ${s.startTime}–${s.endTime}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: group
                                                  ? Colors.white
                                                  : taken
                                                      ? Colors.grey.shade600
                                                      : past
                                                          ? Colors.orange.shade700
                                                          : Colors.white,
                                              fontWeight: FontWeight.w600,
                                              decoration: (taken && !group) ? TextDecoration.lineThrough : null,
                                            )),
                                      ]),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ]),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(children: [
                              Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Text('ครูยังไม่ได้ตั้งเวลาว่าง', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ]),
                          ),
                        const SizedBox(height: 6),
                      ],
                      const SizedBox(height: 14),

                      // ── ช่วงเวลาที่เลือกแล้ว ──
                      Row(children: [
                        const Icon(Icons.calendar_month, size: 16, color: Color(0xFFF97316)),
                        const SizedBox(width: 6),
                        Text('คาบเรียนที่เลือก (${_slots.length} ช่วง)',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 8),
                      if (_slots.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Center(
                            child: Text('ยังไม่มีช่วงเวลา — เพิ่มด้านล่าง',
                                style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ),
                        )
                      else
                        ...List.generate(_slots.length, _buildSlotRow),
                      const SizedBox(height: 12),

                      // ── เพิ่มช่วงเวลา (หลายแถว) ──
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Row(children: [
                            Icon(Icons.add_circle_outline, size: 16, color: Color(0xFFF97316)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text('เพิ่มช่วงเวลา (เลือกวันที่ + เวลา ได้หลายแถว)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFF97316))),
                            ),
                          ]),
                          const SizedBox(height: 12),

                          // แถวร่าง — แต่ละแถว = วันที่(ปฏิทิน) + เวลาเริ่ม/สิ้นสุด
                          ...List.generate(_drafts.length, _buildDraftRow),

                          // ปุ่มเพิ่มแถว
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(() => _drafts.add(_DraftSlot())),
                              icon: const Icon(Icons.add, size: 18, color: Color(0xFFF97316)),
                              label: const Text('เพิ่มวัน/เวลา',
                                  style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.w600)),
                              style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // ปุ่มยืนยันเข้ารายการ
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _commitDrafts,
                              icon: const Icon(Icons.playlist_add_check, size: 18),
                              label: const Text('เพิ่มเข้ารายการ'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF97316),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),

                      // ── จำนวนคาบ ──
                      _label('📊 จำนวนคาบ'),
                      const SizedBox(height: 8),
                      if (_existingPkg != null) ...[
                        // โหมดเพิ่ม slot — ใช้โควตาเดิม (read-only)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(children: [
                            const Icon(Icons.link, size: 18, color: Color(0xFFF97316)),
                            const SizedBox(width: 8),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('นักเรียนคนนี้มีแพ็กเกจอยู่แล้ว — เพิ่มเป็นช่วงเวลาใหม่ ใช้โควตาคาบร่วมกัน',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE65100))),
                              const SizedBox(height: 4),
                              Text('โควตารวม ${_existingPkg!.totalSessions} • เรียนแล้ว ${_existingPkg!.usedSessions} • เหลือ ${_existingPkg!.remainingSessions} คาบ',
                                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                            ])),
                          ]),
                        ),
                      ] else ...[
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: _numField(_totalCtrl, 'รวมทั้งหมด', onChanged: (_) => setState(() {}))),
                          const SizedBox(width: 10),
                          Expanded(child: _numField(_usedCtrl, 'เรียนแล้ว', onChanged: (_) => setState(() {}))),
                          const SizedBox(width: 10),
                          Expanded(child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F8E9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text('$_calcRemaining', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                              const Text('เหลือ (auto)', style: TextStyle(fontSize: 9, color: Colors.grey)),
                            ]),
                          )),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          'สูตร: เหลือ = รวม − เรียนแล้ว  (${_totalCtrl.text.isEmpty ? 0 : _totalCtrl.text} − ${_usedCtrl.text.isEmpty ? 0 : _usedCtrl.text} = $_calcRemaining)',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // ── หมายเหตุ (เช่น ชื่อคอร์ส) — แสดงในหน้าจัดการผู้ใช้ด้วย ──
                      _label('📝 หมายเหตุ / ชื่อคอร์ส'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notesCtrl,
                        minLines: 4,
                        maxLines: 8,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'เช่น คอร์ส9-4 หรือบันทึกเพิ่มเติม...\n(หมายเหตุนี้จะแสดงในหน้าจัดการผู้ใช้)',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                          filled: true, fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFF97316), width: 2)),
                          contentPadding: const EdgeInsets.all(14),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Save button
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            '${_isEdit ? 'อัปเดต' : 'บันทึกคาบเรียน'} (${_slots.length} ช่วงเวลา)',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
        ),
      ]),
    );
  }

  /// แถวของช่วงเวลาที่เลือกแล้ว (ลบได้)
  Widget _buildSlotRow(int i) {
    final s = _slots[i];
    final past = _isSlotPast(s);
    final taken = !past && _isSlotTaken(s);
    final group = taken && _isGroup; // เวลาซ้ำแบบตั้งใจ (คลาสกลุ่ม)
    final dim = past || (taken && !_isGroup);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dim ? Colors.grey.shade100 : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dim ? Colors.grey.shade300 : Colors.orange.shade200),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
              color: dim ? Colors.grey.shade400 : const Color(0xFFF97316), shape: BoxShape.circle),
          child: Center(
            child: Text(s.day,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text('${s.startTime} – ${s.endTime}',
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: dim ? Colors.grey.shade500 : const Color(0xFFE65100),
                    decoration: dim ? TextDecoration.lineThrough : null,
                  )),
              if (past) ...[
                const SizedBox(width: 8),
                _badge(Icons.history, 'ผ่านไปแล้ว'),
              ] else if (group) ...[
                const SizedBox(width: 8),
                _badge(Icons.groups, 'กลุ่ม', color: const Color(0xFF6A1B9A)),
              ] else if (taken) ...[
                const SizedBox(width: 8),
                _badge(Icons.block, 'จองแล้ว'),
              ],
            ]),
            if (s.date != null && s.date!.isNotEmpty)
              Text(thaiDateFromStr(s.date!),
                  style: TextStyle(
                      fontSize: 11,
                      color: dim ? Colors.grey.shade500 : const Color(0xFF558B2F))),
          ],
        )),
        IconButton(
          onPressed: () => setState(() => _slots.removeAt(i)),
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  Widget _badge(IconData icon, String text, {Color? color}) {
    final c = color ?? Colors.grey.shade600;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color != null ? color.withAlpha(30) : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: 2),
          Text(text, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
        ]),
      );
  }

  /// แถวร่าง — วันที่(ปฏิทิน) + เวลาเริ่ม/สิ้นสุด
  Widget _buildDraftRow(int i) {
    final d = _drafts[i];
    final hasDate = d.date != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle),
            child: Center(
              child: Text('${i + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDraftDate(d),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: hasDate ? const Color(0xFFE3F2FD) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: hasDate ? const Color(0xFFF97316).withAlpha(100) : Colors.grey.shade300),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_month, size: 16,
                      color: hasDate ? const Color(0xFFF97316) : Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasDate ? thaiDateFull(d.date!) : 'แตะเลือกวันที่',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
                        color: hasDate ? const Color(0xFFF97316) : Colors.grey,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          if (_drafts.length > 1)
            IconButton(
              onPressed: () => setState(() => _drafts.removeAt(i)),
              icon: const Icon(Icons.close, color: Colors.red, size: 18),
              padding: const EdgeInsets.only(left: 4),
              constraints: const BoxConstraints(),
            ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _TimeTile(
            label: 'เริ่ม',
            time: d.start,
            onTap: () async {
              final t = await _pickTime(d.start ?? const TimeOfDay(hour: 9, minute: 0));
              if (t != null) setState(() {
                d.start = t;
                d.end ??= TimeOfDay(hour: (t.hour + 1) % 24, minute: t.minute);
              });
            },
          )),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('–', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ),
          Expanded(child: _TimeTile(
            label: 'สิ้นสุด',
            time: d.end,
            onTap: () async {
              final t = await _pickTime(d.end ?? const TimeOfDay(hour: 10, minute: 0));
              if (t != null) setState(() => d.end = t);
            },
          )),
        ]),
      ]),
    );
  }

  Widget _label(String text, {bool required = false}) => Row(children: [
    Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    if (required) const Text(' *', style: TextStyle(color: Colors.red)),
  ]);

  Widget _numField(TextEditingController ctrl, String label, {void Function(String)? onChanged}) => TextFormField(
    controller: ctrl,
    keyboardType: TextInputType.number,
    onChanged: onChanged,
    validator: (v) => (v == null || v.isEmpty) ? 'กรอก' : null,
    decoration: InputDecoration(
      labelText: label, labelStyle: const TextStyle(fontSize: 12),
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    ),
  );
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// แถวร่างสำหรับกรอกช่วงเวลาใหม่ (วันที่ + เวลาเริ่ม/สิ้นสุด)
class _DraftSlot {
  DateTime? date;
  TimeOfDay? start;
  TimeOfDay? end;
  bool get isEmpty => date == null && start == null && end == null;
  bool get isComplete => date != null && start != null && end != null;
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
      height: 60,
      decoration: BoxDecoration(
        color: time != null ? const Color(0xFFE3F2FD) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: time != null ? const Color(0xFFF97316).withAlpha(100) : Colors.grey.shade300),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          time != null
              ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
              : 'แตะเลือก',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: time != null ? const Color(0xFFF97316) : Colors.grey,
          ),
        ),
      ]),
    ),
  );
}
