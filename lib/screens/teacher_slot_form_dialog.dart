import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

Future<void> showTeacherSlotForm(BuildContext context, {required UserModel teacher, TeacherSlotModel? existing}) {
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
  String? _day;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final s = widget.existing!;
      _day = s.scheduledDay;
      if (s.scheduledTime != null) _startTime = _parseTime(s.scheduledTime!);
      if (s.scheduledEndTime != null) _endTime = _parseTime(s.scheduledEndTime!);
      _notesCtrl.text = s.notes ?? '';
    }
  }

  TimeOfDay _parseTime(String t) {
    final p = t.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    setState(() => _saving = true);
    final data = {
      'teacherName': widget.teacher.name,
      'teacherCode': widget.teacher.code,
      if (_day != null) 'scheduledDay': _day,
      if (_startTime != null) 'scheduledTime': _fmtTime(_startTime!),
      if (_endTime != null) 'scheduledEndTime': _fmtTime(_endTime!),
      if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };
    try {
      await FirestoreService.saveTeacherSlot(widget.teacher.id, data);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

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
        Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),

        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(children: [
            const Icon(Icons.schedule, color: Color(0xFF2E7D32)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isEdit ? 'แก้ไขเวลาว่าง' : 'ตั้งเวลาว่าง', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Text('${widget.teacher.name} (${widget.teacher.code})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1),

        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Teacher info (read-only)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade200)),
              child: Row(children: [
                CircleAvatar(radius: 18, backgroundColor: const Color(0xFF2E7D32),
                    child: Text(widget.teacher.name.isNotEmpty ? widget.teacher.name[0] : '?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.teacher.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(widget.teacher.code, style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32))),
                ]),
              ]),
            ),
            const SizedBox(height: 16),

            // วัน
            const Text('📅 วันที่ว่าง', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: PackageModel.days.map((d) =>
              GestureDetector(
                onTap: () => setState(() => _day = _day == d ? null : d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _day == d ? const Color(0xFF2E7D32) : Colors.grey.shade100,
                    shape: BoxShape.circle,
                    border: Border.all(color: _day == d ? const Color(0xFF2E7D32) : Colors.grey.shade300),
                  ),
                  child: Center(child: Text(d, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _day == d ? Colors.white : Colors.black87))),
                ),
              )).toList()),
            const SizedBox(height: 16),

            // เวลา
            const Text('⏰ เวลาสอน', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _TimeTile(label: 'เริ่มสอน', time: _startTime, color: const Color(0xFF2E7D32),
                onTap: () async {
                  final t = await showTimePicker(context: context,
                    initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
                    builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!));
                  if (t != null) setState(() {
                    _startTime = t;
                    if (_endTime == null) _endTime = TimeOfDay(hour: t.hour + 1, minute: t.minute);
                  });
                },
              )),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('–', style: TextStyle(fontSize: 20, color: Colors.grey))),
              Expanded(child: _TimeTile(label: 'สิ้นสุด', time: _endTime, color: const Color(0xFF2E7D32),
                onTap: () async {
                  final t = await showTimePicker(context: context,
                    initialTime: _endTime ?? const TimeOfDay(hour: 10, minute: 0),
                    builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!));
                  if (t != null) setState(() => _endTime = t);
                },
              )),
            ]),
            const SizedBox(height: 16),

            // หมายเหตุ
            const Text('📝 หมายเหตุ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'บันทึกเพิ่มเติม...',
                filled: true, fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 20),

            // Save
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isEdit ? 'อัปเดตเวลาว่าง' : 'บันทึกเวลาว่าง', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final Color color;
  final VoidCallback onTap;
  const _TimeTile({required this.label, required this.time, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 64,
      decoration: BoxDecoration(
        color: time != null ? color.withAlpha(18) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: time != null ? color.withAlpha(100) : Colors.grey.shade300),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          time != null ? '${time!.hour.toString().padLeft(2,'0')}:${time!.minute.toString().padLeft(2,'0')}' : 'แตะเพื่อเลือก',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: time != null ? color : Colors.grey),
        ),
      ]),
    ),
  );
}
