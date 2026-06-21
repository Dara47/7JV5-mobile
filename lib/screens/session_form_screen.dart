import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

class SessionFormScreen extends StatefulWidget {
  final String userId;
  final String role;
  final SessionModel? existing;

  const SessionFormScreen({super.key, required this.userId, required this.role, this.existing});

  @override
  State<SessionFormScreen> createState() => _SessionFormScreenState();
}

class _SessionFormScreenState extends State<SessionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();

  List<PackageModel> _packages = [];
  PackageModel? _selectedPkg;
  bool _loadingPkgs = true;

  DateTime _date = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  String _status = 'scheduled';
  String? _language;
  String? _skill;
  bool _isLate = false;
  bool _isAbsent = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadPackages();
    if (_isEdit) _populateExisting();
  }

  void _populateExisting() {
    final s = widget.existing!;
    try { _date = DateTime.parse(s.date); } catch (_) {}
    final sp = s.startTime.split(':');
    final ep = s.endTime.split(':');
    if (sp.length == 2) _startTime = TimeOfDay(hour: int.parse(sp[0]), minute: int.parse(sp[1]));
    if (ep.length == 2) _endTime = TimeOfDay(hour: int.parse(ep[0]), minute: int.parse(ep[1]));
    _status = s.status;
    _language = s.language;
    _skill = s.skill;
    _isLate = s.isLate;
    _isAbsent = s.isAbsent;
    _notesCtrl.text = s.notes ?? '';
  }

  Future<void> _loadPackages() async {
    final pkgs = await FirestoreService.getPackagesForUser(widget.userId, widget.role);
    if (!mounted) return;
    setState(() {
      _packages = pkgs;
      if (_isEdit) {
        try { _selectedPkg = pkgs.firstWhere((p) => p.id == widget.existing!.packageId); } catch (_) {}
      } else if (pkgs.length == 1) {
        _selectedPkg = pkgs.first;
      }
      _loadingPkgs = false;
    });
  }

  int get _durationMinutes {
    final sm = _startTime.hour * 60 + _startTime.minute;
    final em = _endTime.hour * 60 + _endTime.minute;
    return em > sm ? em - sm : 0;
  }

  String get _durationLabel {
    final m = _durationMinutes;
    if (m <= 0) return '-';
    if (m % 60 == 0) return '${m ~/ 60} ชม';
    return '${m ~/ 60} ชม ${m % 60} น';
  }

  String _fmt2(int n) => n.toString().padLeft(2, '0');
  String get _timeStr => '${_fmt2(_startTime.hour)}:${_fmt2(_startTime.minute)} – ${_fmt2(_endTime.hour)}:${_fmt2(_endTime.minute)}';

  String get _dateStr {
    const thDays = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
    const thMonths = ['', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
    final day = thDays[_date.weekday - 1];
    return '$day ${_date.day} ${thMonths[_date.month]} ${_date.year + 543}';
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime(2020), lastDate: DateTime(2030),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final t = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t == null) return;
    setState(() {
      if (isStart) {
        _startTime = t;
        if (t.hour * 60 + t.minute >= _endTime.hour * 60 + _endTime.minute) {
          _endTime = TimeOfDay(hour: t.hour + 1, minute: t.minute);
        }
      } else {
        _endTime = t;
      }
    });
  }

  Future<void> _save() async {
    if (_selectedPkg == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกแพ็กเกจ')));
      return;
    }
    if (_durationMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เวลาสิ้นสุดต้องมากกว่าเวลาเริ่ม')));
      return;
    }

    setState(() => _saving = true);
    final pkg = _selectedPkg!;
    final dateStr = '${_date.year}-${_fmt2(_date.month)}-${_fmt2(_date.day)}';
    final startStr = '${_fmt2(_startTime.hour)}:${_fmt2(_startTime.minute)}';
    final endStr = '${_fmt2(_endTime.hour)}:${_fmt2(_endTime.minute)}';

    final data = {
      'packageId': pkg.id,
      'studentId': pkg.studentId, 'teacherId': pkg.teacherId,
      'studentName': pkg.studentName, 'teacherName': pkg.teacherName,
      'date': dateStr, 'startTime': startStr, 'endTime': endStr,
      'status': _status,
      if (_language != null) 'language': _language,
      if (_skill != null) 'skill': _skill,
      'isLate': _isLate, 'isAbsent': _isAbsent,
      if (_notesCtrl.text.isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    try {
      if (_isEdit) {
        await FirestoreService.updateSession(widget.existing!.id, data);
      } else {
        await FirestoreService.addSession(data);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: Text(_isEdit ? 'แก้ไขคาบเรียน' : 'เพิ่มคาบเรียน'),
        backgroundColor: const Color(0xFFB45309),
        foregroundColor: Colors.white,
        actions: [
          if (_saving)
            const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('บันทึก', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _loadingPkgs
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                // Package selector
                if (_packages.isEmpty) ...[
                  _ErrorCard(message: 'ไม่พบแพ็กเกจที่ใช้งานอยู่\nกรุณาสร้างแพ็กเกจก่อนเพิ่มคาบ'),
                  const SizedBox(height: 16),
                ] else if (_packages.length > 1) ...[
                  _SectionHeader(icon: Icons.inventory_2_outlined, label: 'แพ็กเกจ'),
                  const SizedBox(height: 8),
                  ...(_packages.map((pkg) => _PkgTile(
                    pkg: pkg,
                    selected: _selectedPkg?.id == pkg.id,
                    onTap: () => setState(() => _selectedPkg = pkg),
                    viewerRole: widget.role,
                  ))),
                  const SizedBox(height: 16),
                ] else ...[
                  _SelectedPackageInfo(pkg: _packages.first, role: widget.role),
                  const SizedBox(height: 16),
                ],

                // Date & Time
                _SectionHeader(icon: Icons.calendar_today, label: 'วันที่และเวลา'),
                const SizedBox(height: 8),
                _FormCard(children: [
                  _PickerRow(
                    icon: Icons.calendar_month,
                    label: 'วันที่',
                    value: _dateStr,
                    onTap: _pickDate,
                  ),
                  const Divider(height: 1),
                  _PickerRow(
                    icon: Icons.schedule,
                    label: 'เวลา',
                    value: _timeStr,
                    onTap: () {},
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      _TimeChip(label: _fmt2(_startTime.hour), sub: _fmt2(_startTime.minute), onTap: () => _pickTime(isStart: true)),
                      const Text(' – ', style: TextStyle(color: Colors.grey)),
                      _TimeChip(label: _fmt2(_endTime.hour), sub: _fmt2(_endTime.minute), onTap: () => _pickTime(isStart: false)),
                    ]),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.timelapse, size: 20, color: Color(0xFFB45309)),
                      const SizedBox(width: 12),
                      const Text('ระยะเวลา', style: TextStyle(fontSize: 15)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _durationMinutes > 0 ? const Color(0xFFE3F2FD) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_durationLabel, style: TextStyle(fontWeight: FontWeight.bold, color: _durationMinutes > 0 ? const Color(0xFFB45309) : Colors.grey)),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),

                // Language
                _SectionHeader(icon: Icons.language, label: 'ภาษาหลัก'),
                const SizedBox(height: 8),
                _ChipSelector(
                  items: SessionModel.languages,
                  selected: _language,
                  onSelect: (v) => setState(() => _language = _language == v ? null : v),
                  color: const Color(0xFFB45309),
                ),
                const SizedBox(height: 16),

                // Skill
                _SectionHeader(icon: Icons.school_outlined, label: 'ทักษะที่สอน'),
                const SizedBox(height: 8),
                _ChipSelector(
                  items: SessionModel.skills,
                  selected: _skill,
                  onSelect: (v) => setState(() => _skill = _skill == v ? null : v),
                  color: const Color(0xFF2E7D32),
                ),
                const SizedBox(height: 16),

                // Status
                _SectionHeader(icon: Icons.info_outline, label: 'สถานะ'),
                const SizedBox(height: 8),
                _FormCard(children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      _statusEntry('scheduled', 'รอเรียน', Colors.blue),
                      _statusEntry('completed', 'เรียนแล้ว', Colors.green),
                      _statusEntry('in_progress', 'กำลังเรียน', Colors.orange),
                      _statusEntry('cancelled', 'ยกเลิก', Colors.red),
                    ]),
                  ),
                ]),
                const SizedBox(height: 16),

                // Late / Absent
                _SectionHeader(icon: Icons.warning_amber_outlined, label: 'การขาด/สาย'),
                const SizedBox(height: 8),
                _FormCard(children: [
                  SwitchListTile(
                    dense: true,
                    secondary: Icon(Icons.alarm_off, color: _isLate ? Colors.orange : Colors.grey),
                    title: const Text('สาย'),
                    subtitle: const Text('นักเรียน/ครูมาสาย'),
                    value: _isLate,
                    activeThumbColor: Colors.orange,
                    onChanged: (v) => setState(() => _isLate = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    dense: true,
                    secondary: Icon(Icons.event_busy, color: _isAbsent ? Colors.red : Colors.grey),
                    title: const Text('ลา / ขาด'),
                    subtitle: const Text('ไม่ได้เรียนในคาบนี้'),
                    value: _isAbsent,
                    activeThumbColor: Colors.red,
                    onChanged: (v) => setState(() => _isAbsent = v),
                  ),
                ]),
                const SizedBox(height: 16),

                // Notes
                _SectionHeader(icon: Icons.notes, label: 'หมายเหตุ'),
                const SizedBox(height: 8),
                _FormCard(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'บันทึกเนื้อหา สรุปผล หรือข้อสังเกต...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_isEdit ? 'อัปเดตคาบเรียน' : 'บันทึกคาบเรียน', style: const TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB45309), foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
    );
  }

  Widget _statusEntry(String val, String label, Color color) {
    final selected = _status == val;
    return GestureDetector(
      onTap: () => setState(() => _status = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : color.withAlpha(80)),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : color, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: const Color(0xFFB45309)),
    const SizedBox(width: 6),
    Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
  ]);
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 6, offset: const Offset(0, 2))]),
    child: Column(children: children),
  );
}

class _PickerRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;
  const _PickerRow({required this.icon, required this.label, required this.value, required this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: trailing == null ? onTap : null,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(icon, size: 20, color: const Color(0xFFB45309)),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 15)),
        const Spacer(),
        trailing ?? Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
      ]),
    ),
  );
}

class _TimeChip extends StatelessWidget {
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _TimeChip({required this.label, required this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(10)),
      child: Text('$label:$sub', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
    ),
  );
}

class _ChipSelector extends StatelessWidget {
  final List<String> items;
  final String? selected;
  final void Function(String) onSelect;
  final Color color;
  const _ChipSelector({required this.items, required this.selected, required this.onSelect, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 6, offset: const Offset(0, 2))]),
    child: Wrap(
      spacing: 8, runSpacing: 8,
      children: items.map((item) {
        final sel = selected == item;
        return GestureDetector(
          onTap: () => onSelect(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: sel ? color : color.withAlpha(18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? color : color.withAlpha(70)),
            ),
            child: Text(item, style: TextStyle(fontSize: 13, color: sel ? Colors.white : color, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
          ),
        );
      }).toList(),
    ),
  );
}

class _PkgTile extends StatelessWidget {
  final PackageModel pkg;
  final bool selected;
  final VoidCallback onTap;
  final String viewerRole;
  const _PkgTile({required this.pkg, required this.selected, required this.onTap, required this.viewerRole});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE3F2FD) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? const Color(0xFFB45309) : Colors.grey.shade200, width: selected ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
      ),
      child: Row(children: [
        Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: selected ? const Color(0xFFB45309) : Colors.grey),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(viewerRole == 'student' ? 'ครู: ${pkg.teacherName}' : 'นักเรียน: ${pkg.studentName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('คงเหลือ ${pkg.remainingSessions} คาบ', style: TextStyle(fontSize: 12, color: pkg.isLowBalance ? Colors.orange : Colors.grey)),
        ])),
        if (pkg.isLowBalance) const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
      ]),
    ),
  );
}

class _SelectedPackageInfo extends StatelessWidget {
  final PackageModel pkg;
  final String role;
  const _SelectedPackageInfo({required this.pkg, required this.role});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade300)),
    child: Row(children: [
      const Icon(Icons.inventory_2_outlined, color: Colors.green, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(role == 'student' ? 'ครู: ${pkg.teacherName} (${pkg.teacherCode})' : 'นักเรียน: ${pkg.studentName} (${pkg.studentCode})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        Text('คงเหลือ ${pkg.remainingSessions}/${pkg.totalSessions} คาบ', style: const TextStyle(fontSize: 12, color: Colors.green)),
      ])),
    ]),
  );
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
    child: Row(children: [
      const Icon(Icons.warning_amber, color: Colors.orange),
      const SizedBox(width: 12),
      Expanded(child: Text(message, style: const TextStyle(color: Colors.orange))),
    ]),
  );
}
