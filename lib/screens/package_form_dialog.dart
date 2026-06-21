import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

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

  String? _scheduledDay;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  TeacherSlotModel? _teacherSlot;
  List<PackageModel> _takenSlotPackages = [];
  bool _loadingUsers = true;
  bool _loadingSlot = false;
  bool _saving = false;

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
      _scheduledDay = p.scheduledDay;
      if (p.scheduledTime != null) _startTime = _parseTime(p.scheduledTime!);
      if (p.scheduledEndTime != null) _endTime = _parseTime(p.scheduledEndTime!);
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
    if (_student == null || _teacher == null) return;
    final pkgs = await FirestoreService.getPackagesForUser(_student!.id, 'student');
    if (!mounted) return;
    setState(() {
      _takenSlotPackages = pkgs.where((p) => p.teacherId == _teacher!.id).toList();
    });
  }

  bool _isSlotTaken(SlotItem s) {
    return _takenSlotPackages.any((p) =>
        p.scheduledDay == s.day &&
        p.scheduledTime == s.startTime &&
        p.scheduledEndTime == s.endTime);
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

  TimeOfDay _parseTime(String t) {
    final p = t.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

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

    setState(() => _saving = true);
    final total = int.tryParse(_totalCtrl.text) ?? 0;

    final data = {
      'studentId': _student!.id, 'teacherId': _teacher!.id,
      'studentName': _student!.name, 'teacherName': _teacher!.name,
      'studentCode': _student!.code, 'teacherCode': _teacher!.code,
      'totalSessions': total,
      'remainingSessions': _calcRemaining,
      'status': 'active',
      if (_scheduledDay != null) 'scheduledDay': _scheduledDay,
      if (_startTime != null) 'scheduledTime': _fmtTime(_startTime!),
      if (_endTime != null) 'scheduledEndTime': _fmtTime(_endTime!),
      if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    try {
      if (_isEdit) {
        await FirestoreService.updatePackageFields(widget.existing!.id, data);
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
                      _UserDropdown(
                        users: _students,
                        selected: _student,
                        hint: 'เลือกนักเรียน...',
                        enabled: !_isEdit && widget.preselectedStudentId == null,
                        color: const Color(0xFFF97316),
                        onChanged: (u) {
                          setState(() {
                            _student = u;
                            _takenSlotPackages = [];
                            if (u?.defaultSessions != null && _totalCtrl.text.isEmpty) {
                              _totalCtrl.text = u!.defaultSessions.toString();
                            }
                          });
                          if (u != null && _teacher != null) _loadTakenSlots();
                        },
                      ),
                      const SizedBox(height: 14),

                      // ── ครู ──
                      _label('🎓 ครู', required: !_isEdit),
                      const SizedBox(height: 6),
                      _UserDropdown(
                        users: _teachers,
                        selected: _teacher,
                        hint: 'เลือกครู...',
                        enabled: !_isEdit,
                        color: const Color(0xFF2E7D32),
                        onChanged: (u) {
                          setState(() { _teacher = u; _teacherSlot = null; });
                          if (u != null) _loadTeacherSlot(u.id);
                        },
                      ),
                      // ── เวลาว่างครู ──
                      if (_teacher != null) ...[
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
                                Text('เวลาว่างของครู — กดเลือกช่วงเวลา',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                              ]),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6, runSpacing: 6,
                                children: _teacherSlot!.slots.map((s) {
                                  final taken = _isSlotTaken(s);
                                  return GestureDetector(
                                    onTap: taken ? null : () => setState(() {
                                      _scheduledDay = s.day;
                                      _startTime = _parseTime(s.startTime);
                                      _endTime = _parseTime(s.endTime);
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: taken ? Colors.grey.shade300 : const Color(0xFF2E7D32),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        if (taken) const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(Icons.block, size: 12, color: Colors.grey),
                                        ),
                                        Text('${s.day}  ${s.startTime}–${s.endTime}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: taken ? Colors.grey.shade600 : Colors.white,
                                              fontWeight: FontWeight.w600,
                                              decoration: taken ? TextDecoration.lineThrough : null,
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

                      // ── วัน ──
                      _label('📅 วันเรียนประจำ'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 6,
                        children: PackageModel.days.map((d) => GestureDetector(
                          onTap: () => setState(() => _scheduledDay = _scheduledDay == d ? null : d),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: _scheduledDay == d ? const Color(0xFFF97316) : Colors.grey.shade100,
                              shape: BoxShape.circle,
                              border: Border.all(color: _scheduledDay == d ? const Color(0xFFF97316) : Colors.grey.shade300),
                            ),
                            child: Center(child: Text(d, style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13,
                              color: _scheduledDay == d ? Colors.white : Colors.black87,
                            ))),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 14),

                      // ── เวลา ──
                      _label('⏰ เวลาเรียน'),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: _TimePicker(
                          label: 'เริ่ม', time: _startTime,
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
                              builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
                            );
                            if (t != null) setState(() {
                              _startTime = t;
                              if (_endTime == null) _endTime = TimeOfDay(hour: t.hour + 1, minute: t.minute);
                            });
                          },
                        )),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–', style: TextStyle(fontSize: 18, color: Colors.grey))),
                        Expanded(child: _TimePicker(
                          label: 'สิ้นสุด', time: _endTime,
                          onTap: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: _endTime ?? const TimeOfDay(hour: 10, minute: 0),
                              builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
                            );
                            if (t != null) setState(() => _endTime = t);
                          },
                        )),
                      ]),
                      const SizedBox(height: 14),

                      // ── จำนวนคาบ ──
                      _label('📊 จำนวนคาบ'),
                      const SizedBox(height: 8),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: _numField(_totalCtrl, 'รวมทั้งหมด', onChanged: (_) => setState(() {}))),
                        const SizedBox(width: 10),
                        Expanded(child: _numField(_usedCtrl, 'เรียนแล้ว', onChanged: (_) => setState(() {}))),
                        const SizedBox(width: 10),
                        // เหลือ = auto
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
                      const SizedBox(height: 14),

                      // ── หมายเหตุ ──
                      _label('📝 หมายเหตุ'),
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

                      // Save button
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.check_circle_outline),
                          label: Text(_isEdit ? 'อัปเดต' : 'บันทึกคาบเรียน', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

class _UserDropdown extends StatelessWidget {
  final List<UserModel> users;
  final UserModel? selected;
  final String hint;
  final bool enabled;
  final Color color;
  final void Function(UserModel?) onChanged;
  const _UserDropdown({required this.users, required this.selected, required this.hint, required this.enabled, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<UserModel>(
    value: selected,
    hint: Text(hint, style: const TextStyle(fontSize: 14)),
    isExpanded: true,
    validator: enabled ? (v) => v == null ? 'กรุณาเลือก' : null : null,
    onChanged: enabled ? onChanged : null,
    decoration: InputDecoration(
      filled: true,
      fillColor: enabled ? Colors.white : Colors.grey.shade100,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    items: users.map((u) => DropdownMenuItem(
      value: u,
      child: Row(children: [
        Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
            child: Center(child: Text(u.code.substring(0, 1), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)))),
        const SizedBox(width: 8),
        Expanded(child: Text('${u.name}  ', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
        Text(u.code, style: TextStyle(fontSize: 12, color: color)),
      ]),
    )).toList(),
  );
}

class _TimePicker extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;
  const _TimePicker({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        color: time != null ? const Color(0xFFE3F2FD) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: time != null ? const Color(0xFFF97316).withAlpha(100) : Colors.grey.shade300),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          time != null ? '${time!.hour.toString().padLeft(2,'0')}:${time!.minute.toString().padLeft(2,'0')}' : 'แตะเพื่อเลือก',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: time != null ? const Color(0xFFF97316) : Colors.grey),
        ),
      ]),
    ),
  );
}
