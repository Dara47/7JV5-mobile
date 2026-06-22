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
  bool _saving = false;

  // New slot form state
  String? _newDay;
  DateTime? _newDate;
  TimeOfDay? _newStart;
  TimeOfDay? _newEnd;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _slots = List.from(widget.existing!.slots);
      _notesCtrl.text = widget.existing!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _addSlot() {
    if (_newDay == null || _newStart == null || _newEnd == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณาเลือกวันและเวลาให้ครบ')));
      return;
    }
    setState(() {
      _slots.add(SlotItem(
        day: _newDay!,
        startTime: _fmt(_newStart!),
        endTime: _fmt(_newEnd!),
        date: _newDate != null ? toStorageDateStr(_newDate!) : null,
      ));
      _newDay = null;
      _newDate = null;
      _newStart = null;
      _newEnd = null;
    });
  }

  Future<void> _pickNewDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _newDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) {
      setState(() {
        _newDate = d;
        _newDay = thaiDayAbbr(d); // วันคำนวณอัตโนมัติจากวันที่
      });
    }
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
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: _kGreen, shape: BoxShape.circle),
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
                          Text('${s.startTime} – ${s.endTime}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kGreen)),
                          if (s.date != null && s.date!.isNotEmpty)
                            Text(thaiDateFromStr(s.date!),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF558B2F))),
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
                    Text('เพิ่มช่วงเวลาใหม่',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFF97316))),
                  ]),
                  const SizedBox(height: 12),

                  // Date picker (optional — เลือกวันที่แล้ววันจะคำนวณให้)
                  const Text('วันที่ (ถ้าระบุ วันจะคำนวณให้อัตโนมัติ)',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _pickNewDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: _newDate != null ? const Color(0xFFE3F2FD) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _newDate != null
                                ? const Color(0xFFF97316).withAlpha(100)
                                : Colors.grey.shade300),
                      ),
                      child: Row(children: [
                        Icon(Icons.calendar_month,
                            size: 18,
                            color: _newDate != null ? const Color(0xFFF97316) : Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _newDate != null ? thaiDateFull(_newDate!) : 'แตะเพื่อเลือกวันที่ (ไม่บังคับ)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _newDate != null ? FontWeight.w600 : FontWeight.normal,
                              color: _newDate != null ? const Color(0xFFF97316) : Colors.grey,
                            ),
                          ),
                        ),
                        if (_newDate != null)
                          GestureDetector(
                            onTap: () => setState(() => _newDate = null),
                            child: const Icon(Icons.clear, size: 18, color: Colors.grey),
                          ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Day selector
                  const Text('วัน', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: PackageModel.days.map((d) => GestureDetector(
                      onTap: () => setState(() {
                        _newDay = _newDay == d ? null : d;
                        _newDate = null; // เลือกวันเองแบบประจำ → ล้างวันที่เจาะจง
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _newDay == d ? const Color(0xFFF97316) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _newDay == d ? const Color(0xFFF97316) : Colors.grey.shade300),
                        ),
                        child: Center(child: Text(d,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _newDay == d ? Colors.white : Colors.black87,
                            ))),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Time pickers
                  const Text('เวลา', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: _TimeTile(
                      label: 'เริ่ม',
                      time: _newStart,
                      onTap: () async {
                        final t = await _pickTime(_newStart ?? const TimeOfDay(hour: 9, minute: 0));
                        if (t != null) setState(() {
                          _newStart = t;
                          _newEnd ??= TimeOfDay(hour: t.hour + 1, minute: t.minute);
                        });
                      },
                    )),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('–', style: TextStyle(fontSize: 20, color: Colors.grey)),
                    ),
                    Expanded(child: _TimeTile(
                      label: 'สิ้นสุด',
                      time: _newEnd,
                      onTap: () async {
                        final t = await _pickTime(_newEnd ?? const TimeOfDay(hour: 10, minute: 0));
                        if (t != null) setState(() => _newEnd = t);
                      },
                    )),
                  ]),
                  const SizedBox(height: 12),

                  // Add button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _addSlot,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('เพิ่มช่วงเวลานี้'),
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
