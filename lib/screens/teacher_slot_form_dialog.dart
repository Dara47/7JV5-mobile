import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../utils/date_format.dart';

const _kGreen = Color(0xFF2E7D32);

Future<void> showTeacherSlotForm(BuildContext context,
    {required UserModel teacher, TeacherSlotModel? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TeacherSlotSheet(teacher: teacher, existing: existing),
  );
}

class _TeacherSlotSheet extends StatefulWidget {
  final UserModel teacher;
  final TeacherSlotModel? existing;
  const _TeacherSlotSheet({required this.teacher, this.existing});
  @override
  State<_TeacherSlotSheet> createState() => _TeacherSlotSheetState();
}

class _TeacherSlotSheetState extends State<_TeacherSlotSheet> {
  final _notesCtrl = TextEditingController();
  List<SlotItem> _slots = [];
  List<PackageModel> _bookedPackages = []; // แพ็กเกจของครู (ใช้เช็คช่วงที่ถูกจองแล้ว)
  bool _saving = false;

  // แถวร่างสำหรับเพิ่มหลายช่วง — แต่ละแถวเลือกวันที่(ปฏิทิน)+เวลาเริ่ม/สิ้นสุดได้เอง
  final List<_DraftSlot> _drafts = [_DraftSlot()];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _slots = List.from(widget.existing!.slots);
      _notesCtrl.text = widget.existing!.notes ?? '';
    }
    // โหลดแพ็กเกจของครู เพื่อแสดงช่วงที่ "ถูกจองแล้ว" เป็นสีเทา
    FirestoreService.getPackagesForUser(widget.teacher.id, 'teacher').then((pkgs) {
      if (mounted) setState(() => _bookedPackages = pkgs);
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// slot ที่ระบุวันที่เจาะจง + เลยเวลาเริ่มไปแล้ว (recurring ไม่ถือว่าผ่าน)
  bool _isSlotPast(SlotItem s) {
    if (s.date == null || s.date!.isEmpty) return false;
    final d = parseDateStr(s.date!);
    if (d == null) return false;
    final p = s.startTime.split(':');
    if (p.length != 2) return false;
    final start = DateTime(d.year, d.month, d.day,
        int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0);
    return nowThai().isAfter(start);
  }

  /// เพิ่มทุกแถวร่างที่กรอกครบ เข้ารายการ "ช่วงเวลาสอน"
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
        final start = _fmt(d.start!);
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
          endTime: _fmt(d.end!),
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
      backgroundColor: _kGreen,
      duration: const Duration(seconds: 2),
    ));
  }

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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirestoreService.updateTeacherSlots(
        widget.teacher.id, widget.teacher.name, widget.teacher.code, _slots,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
        setState(() => _saving = false);
      }
    }
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) => showTimePicker(
        context: context,
        initialTime: initial,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );

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
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 10),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: [
            const Icon(Icons.schedule, color: _kGreen),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ตั้งเวลาว่าง', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Text('${widget.teacher.name} (${widget.teacher.code})',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1),

        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Teacher info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18, backgroundColor: _kGreen,
                    child: Text(
                      widget.teacher.name.isNotEmpty ? widget.teacher.name[0] : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.teacher.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(widget.teacher.code,
                        style: const TextStyle(fontSize: 12, color: _kGreen)),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),

              // ── Existing slots ───────────────────────────────────────────
              Row(children: [
                const Icon(Icons.calendar_month, size: 16, color: _kGreen),
                const SizedBox(width: 6),
                Text('ช่วงเวลาสอน (${_slots.length} ช่วง)',
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
                ...List.generate(_slots.length, (i) {
                  final s = _slots[i];
                  final past = _isSlotPast(s);
                  // ถูกจองโดยนักเรียนแล้ว → เทา (ตรงกับหน้าเพิ่มคาบ)
                  final taken = !past && slotTakenByPackages(_bookedPackages, s);
                  final dim = past || taken;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: dim ? Colors.grey.shade100 : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: dim ? Colors.grey.shade300 : Colors.green.shade200),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                            color: dim ? Colors.grey.shade400 : _kGreen, shape: BoxShape.circle),
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
                                  color: dim ? Colors.grey.shade500 : _kGreen,
                                  decoration: dim ? TextDecoration.lineThrough : null,
                                )),
                            if (past) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.history, size: 11, color: Colors.grey.shade600),
                                  const SizedBox(width: 2),
                                  Text('ผ่านไปแล้ว',
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ] else if (taken) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.block, size: 11, color: Colors.grey.shade600),
                                  const SizedBox(width: 2),
                                  Text('จองแล้ว',
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                ]),
                              ),
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
                }),

              const SizedBox(height: 16),

              // ── Add new slot ─────────────────────────────────────────────
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
              const SizedBox(height: 16),

              // Notes
              const Text('📝 หมายเหตุ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'บันทึกเพิ่มเติม...',
                  filled: true, fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    '${_saving ? 'กำลังบันทึก...' : 'บันทึก'} (${_slots.length} ช่วงเวลา)',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

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
