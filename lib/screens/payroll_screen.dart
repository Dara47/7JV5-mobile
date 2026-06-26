import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../utils/date_format.dart';
import '../utils/excel_export.dart';
import '../widgets/user_search_field.dart';

const _kPass = 'ATAL190314';

String _fmt(double n) {
  final s = n.toStringAsFixed(2);
  final parts = s.split('.');
  final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return '฿$intPart.${parts[1]}';
}

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});
  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen>
    with SingleTickerProviderStateMixin {
  // ── Lock ─────────────────────────────────────────────────────────────────
  bool _unlocked = false;
  final _passCtrl = TextEditingController();
  bool _passError = false;
  bool _passObscure = true;

  // ── Tab ──────────────────────────────────────────────────────────────────
  late final TabController _tab;

  // ── Data ─────────────────────────────────────────────────────────────────
  List<TeacherPayrollModel> _teachers = [];
  List<AdminPayrollModel> _admins = [];
  bool _loading = false;
  String _tSearch = '';
  String _aSearch = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([
        FirestoreService.getTeacherPayrolls(),
        FirestoreService.getAdminPayrolls(),
      ]);
      if (mounted) setState(() {
        _teachers = r[0] as List<TeacherPayrollModel>;
        _admins   = r[1] as List<AdminPayrollModel>;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _unlock() {
    if (_passCtrl.text.trim() == _kPass) {
      setState(() { _unlocked = true; _passError = false; });
      _load();
    } else {
      setState(() => _passError = true);
    }
  }

  Future<void> _toggleStatus(String id, String current, String type) async {
    final next = current == 'paid' ? 'pending' : 'paid';
    final data = <String, dynamic>{'status': next};
    if (next == 'paid') data['paidAt'] = nowThaiIso();
    if (type == 'teacher') {
      await FirestoreService.updateTeacherPayroll(id, data);
    } else {
      await FirestoreService.updateAdminPayroll(id, data);
    }
    _load();
  }

  Future<void> _delete(String id, String type) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('ยืนยันการลบ?'),
      content: const Text('รายการนี้จะถูกลบถาวร'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('ลบ', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
    if (ok != true) return;
    if (type == 'teacher') {
      await FirestoreService.deleteTeacherPayroll(id);
    } else {
      await FirestoreService.deleteAdminPayroll(id);
    }
    _load();
  }

  void _openForm({TeacherPayrollModel? teacher, AdminPayrollModel? admin, required String mode}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayrollFormSheet(
        mode: mode,
        teacher: teacher,
        admin: admin,
        existingTeachers: _teachers,
        existingAdmins: _admins,
        onSaved: _load,
      ),
    );
  }

  // ── Lock screen ───────────────────────────────────────────────────────────
  Widget _lockScreen() => Scaffold(
    appBar: AppBar(
      title: const Text('บัญชีค่าจ้าง'),
      backgroundColor: const Color(0xFFF97316),
      foregroundColor: Colors.white,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Card(
          margin: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFFF97316).withAlpha(20),
                child: const Icon(Icons.lock_rounded, size: 32, color: Color(0xFFF97316)),
              ),
              const SizedBox(height: 16),
              const Text('บัญชีค่าจ้าง',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('กรุณาใส่รหัสผ่านเพื่อเข้าถึง',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),
              TextField(
                controller: _passCtrl,
                obscureText: _passObscure,
                onSubmitted: (_) => _unlock(),
                decoration: InputDecoration(
                  labelText: 'รหัสผ่าน',
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_passObscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _passObscure = !_passObscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  errorText: _passError ? 'รหัสผ่านไม่ถูกต้อง' : null,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton.icon(
                  onPressed: _unlock,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('เข้าสู่ระบบ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    ),
  );

  // ── Main screen ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!_unlocked) return _lockScreen();

    final tFiltered = _tSearch.isEmpty ? _teachers
        : _teachers.where((e) => e.teacherName.toLowerCase().contains(_tSearch.toLowerCase())).toList();
    final aFiltered = _aSearch.isEmpty ? _admins
        : _admins.where((e) => e.adminName.toLowerCase().contains(_aSearch.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('บัญชีค่าจ้าง'),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.person_outlined, size: 18), text: 'ค่าจ้างครู'),
            Tab(icon: Icon(Icons.admin_panel_settings_outlined, size: 18), text: 'ค่าจ้างแอดมิน'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load, tooltip: 'รีเฟรช'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                // ── Teacher tab ──────────────────────────────────────────
                _TabContent(
                  entries: tFiltered,
                  allEntries: _teachers,
                  type: 'teacher',
                  search: _tSearch,
                  onSearchChange: (v) => setState(() => _tSearch = v),
                  onAdd: () => _openForm(mode: 'teacher'),
                  onEdit: (e) => _openForm(teacher: e as TeacherPayrollModel, mode: 'teacher'),
                  onToggle: (id, status) => _toggleStatus(id, status, 'teacher'),
                  onDelete: (id) => _delete(id, 'teacher'),
                ),
                // ── Admin tab ────────────────────────────────────────────
                _TabContent(
                  entries: aFiltered,
                  allEntries: _admins,
                  type: 'admin',
                  search: _aSearch,
                  onSearchChange: (v) => setState(() => _aSearch = v),
                  onAdd: () => _openForm(mode: 'admin'),
                  onEdit: (e) => _openForm(admin: e as AdminPayrollModel, mode: 'admin'),
                  onToggle: (id, status) => _toggleStatus(id, status, 'admin'),
                  onDelete: (id) => _delete(id, 'admin'),
                ),
              ],
            ),
    );
  }
}

// ── Tab content ───────────────────────────────────────────────────────────────

class _TabContent extends StatelessWidget {
  final List<dynamic> entries;
  final List<dynamic> allEntries;
  final String type;
  final String search;
  final ValueChanged<String> onSearchChange;
  final VoidCallback onAdd;
  final ValueChanged<dynamic> onEdit;
  final void Function(String id, String status) onToggle;
  final ValueChanged<String> onDelete;

  const _TabContent({
    required this.entries, required this.allEntries, required this.type,
    required this.search, required this.onSearchChange,
    required this.onAdd, required this.onEdit,
    required this.onToggle, required this.onDelete,
  });

  double get _totalAmount => allEntries.fold(0, (s, e) =>
      s + (type == 'teacher' ? (e as TeacherPayrollModel).totalAmount : (e as AdminPayrollModel).totalAmount));
  double get _paid => allEntries.where((e) => type == 'teacher'
      ? (e as TeacherPayrollModel).isPaid
      : (e as AdminPayrollModel).isPaid).fold(0, (s, e) =>
      s + (type == 'teacher' ? (e as TeacherPayrollModel).totalAmount : (e as AdminPayrollModel).totalAmount));
  double get _pending => _totalAmount - _paid;

  static String _num(double n) => n % 1 == 0 ? n.toInt().toString() : n.toString();

  /// ส่งออกรายการที่กำลังแสดง (ตามตัวกรองค้นหา) เป็นไฟล์ Excel
  void _export(BuildContext context) {
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่มีรายการให้ส่งออก')));
      return;
    }
    final isTeacher = type == 'teacher';
    final headers = <String>[
      'ลำดับ', isTeacher ? 'ชื่อครู' : 'ชื่อแอดมิน',
      'ตั้งแต่วันที่', 'ถึงวันที่', 'สัปดาห์/ช่วง', 'รายการค่าจ้าง',
      if (isTeacher) 'จำนวนคาบ',
      'รวมค่าจ้าง', 'รายการหักเงิน', 'หักเงิน', 'จ่ายสุทธิ', 'สถานะ', 'หมายเหตุ',
    ];

    final rows = <List<dynamic>>[];
    double sumGross = 0, sumDeduct = 0, sumNet = 0, sumSessions = 0;
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final name = isTeacher ? (e as TeacherPayrollModel).teacherName : (e as AdminPayrollModel).adminName;
      final roles = isTeacher ? (e as TeacherPayrollModel).roles : (e as AdminPayrollModel).roles;
      final deds = isTeacher ? (e as TeacherPayrollModel).deductions : (e as AdminPayrollModel).deductions;
      final dateFrom = isTeacher ? (e as TeacherPayrollModel).dateFrom : (e as AdminPayrollModel).dateFrom;
      final dateTo = isTeacher ? (e as TeacherPayrollModel).dateTo : (e as AdminPayrollModel).dateTo;
      final week = isTeacher ? (e as TeacherPayrollModel).weekLabel : (e as AdminPayrollModel).weekLabel;
      final note = isTeacher ? (e as TeacherPayrollModel).note : (e as AdminPayrollModel).note;
      final net = isTeacher ? (e as TeacherPayrollModel).totalAmount : (e as AdminPayrollModel).totalAmount;
      final totalDed = isTeacher ? (e as TeacherPayrollModel).totalDeductions : (e as AdminPayrollModel).totalDeductions;
      final isPaid = isTeacher ? (e as TeacherPayrollModel).isPaid : (e as AdminPayrollModel).isPaid;
      final sessions = isTeacher ? (e as TeacherPayrollModel).totalSessions : 0.0;
      final gross = net + totalDed;
      final rolesStr = roles.map((r) => '${r.role} ${_num(r.count)}×${_num(r.rate)}=${_num(r.total)}').join(' | ');
      final dedsStr = deds.map((d) => '${d.label}=${_num(d.amount)}').join(' | ');

      rows.add([
        i + 1, name,
        dateFrom ?? '', dateTo ?? '', week ?? '', rolesStr,
        if (isTeacher) sessions,
        gross, dedsStr, totalDed, net,
        isPaid ? 'จ่ายแล้ว' : 'รอจ่าย',
        note ?? '',
      ]);
      sumGross += gross; sumDeduct += totalDed; sumNet += net; sumSessions += sessions;
    }
    // แถวรวมยอด
    rows.add([
      '', 'รวม', '', '', '', '',
      if (isTeacher) sumSessions,
      sumGross, '', sumDeduct, sumNet, '', '',
    ]);

    exportXlsx(
      filename: '${isTeacher ? 'payroll_teacher' : 'payroll_admin'}_${todayThaiStr()}.xlsx',
      sheetName: isTeacher ? 'ค่าจ้างครู' : 'ค่าจ้างแอดมิน',
      headers: headers,
      rows: rows,
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('ส่งออก ${entries.length} รายการเป็น Excel แล้ว'),
      backgroundColor: Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    // ── Summary row ────────────────────────────────────────────────────────
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(children: [
        _SumCard(label: 'รอจ่าย', amount: _pending, color: Colors.orange),
        const SizedBox(width: 8),
        _SumCard(label: 'จ่ายแล้ว', amount: _paid, color: Colors.green),
        const SizedBox(width: 8),
        _SumCard(label: 'รวม', amount: _totalAmount, color: Colors.blueGrey),
      ]),
    ),
    // ── Search + Add ───────────────────────────────────────────────────────
    Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(children: [
        Expanded(child: TextField(
          onChanged: onSearchChange,
          decoration: InputDecoration(
            hintText: type == 'teacher' ? 'ค้นหาชื่อครู...' : 'ค้นหาชื่อแอดมิน...',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300)),
          ),
        )),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () => _export(context),
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: const Text('Excel'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green.shade700,
            side: BorderSide(color: Colors.green.shade400),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('เพิ่ม'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF97316),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ]),
    ),
    // ── List ───────────────────────────────────────────────────────────────
    Expanded(
      child: entries.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.receipt_long_outlined, size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(search.isEmpty ? 'ยังไม่มีรายการ' : 'ไม่พบผลการค้นหา',
                  style: const TextStyle(color: Colors.grey)),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _EntryCard(
                entry: entries[i],
                type: type,
                onEdit: () => onEdit(entries[i]),
                onToggle: () {
                  final e = entries[i];
                  final id = type == 'teacher' ? (e as TeacherPayrollModel).id : (e as AdminPayrollModel).id;
                  final st = type == 'teacher' ? (e as TeacherPayrollModel).status : (e as AdminPayrollModel).status;
                  onToggle(id, st);
                },
                onDelete: () {
                  final id = type == 'teacher' ? (entries[i] as TeacherPayrollModel).id : (entries[i] as AdminPayrollModel).id;
                  onDelete(id);
                },
              ),
            ),
    ),
  ]);
}

class _SumCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _SumCard({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(_fmt(amount),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ]),
    ),
  );
}

// ── Entry card ────────────────────────────────────────────────────────────────

class _EntryCard extends StatefulWidget {
  final dynamic entry;
  final String type;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _EntryCard({required this.entry, required this.type,
      required this.onEdit, required this.onToggle, required this.onDelete});
  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final isPaid = widget.type == 'teacher'
        ? (e as TeacherPayrollModel).isPaid
        : (e as AdminPayrollModel).isPaid;
    final name = widget.type == 'teacher'
        ? (e as TeacherPayrollModel).teacherName
        : (e as AdminPayrollModel).adminName;
    final amount = widget.type == 'teacher'
        ? (e as TeacherPayrollModel).totalAmount
        : (e as AdminPayrollModel).totalAmount;
    final roles = widget.type == 'teacher'
        ? (e as TeacherPayrollModel).roles
        : (e as AdminPayrollModel).roles;
    final deductions = widget.type == 'teacher'
        ? (e as TeacherPayrollModel).deductions
        : (e as AdminPayrollModel).deductions;
    final dateFrom = widget.type == 'teacher' ? (e as TeacherPayrollModel).dateFrom : (e as AdminPayrollModel).dateFrom;
    final dateTo = widget.type == 'teacher' ? (e as TeacherPayrollModel).dateTo : (e as AdminPayrollModel).dateTo;
    final weekLabel = widget.type == 'teacher' ? (e as TeacherPayrollModel).weekLabel : (e as AdminPayrollModel).weekLabel;
    final note = widget.type == 'teacher' ? (e as TeacherPayrollModel).note : (e as AdminPayrollModel).note;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isPaid ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header row ──────────────────────────────────────────────
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Row(children: [
                Text(_fmt(amount),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPaid ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(isPaid ? 'จ่ายแล้ว' : 'รอจ่าย',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
              if (weekLabel != null && weekLabel.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(weekLabel, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
              if (dateFrom != null || dateTo != null) ...[
                const SizedBox(height: 2),
                Text('${dateFrom ?? '...'} – ${dateTo ?? '...'}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(note, style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ])),
            // Action buttons
            Column(children: [
              IconButton(
                icon: Icon(isPaid ? Icons.hourglass_empty : Icons.check_circle_outline,
                    color: isPaid ? Colors.orange : Colors.green, size: 22),
                tooltip: isPaid ? 'ยกเลิกการจ่าย' : 'ทำเครื่องหมายจ่ายแล้ว',
                onPressed: widget.onToggle,
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: widget.onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                onPressed: widget.onDelete,
              ),
            ]),
          ]),
          // ── Expand roles ─────────────────────────────────────────────
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 16),
            label: Text('${roles.length} รายการ', style: const TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          if (_expanded) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(180),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                // Header
                const Row(children: [
                  Expanded(child: Text('รายการ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600))),
                  SizedBox(width: 60, child: Text('จำนวน', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600))),
                  SizedBox(width: 70, child: Text('อัตรา', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600))),
                  SizedBox(width: 70, child: Text('รวม', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600))),
                ]),
                const Divider(height: 8),
                ...roles.map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text(r.role, style: const TextStyle(fontSize: 12))),
                    SizedBox(width: 60, child: Text('${r.count % 1 == 0 ? r.count.toInt() : r.count}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                    SizedBox(width: 70, child: Text(_fmt(r.rate), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12))),
                    SizedBox(width: 70, child: Text(_fmt(r.total), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  ]),
                )),
                if (deductions.isNotEmpty) ...[
                  const Divider(height: 8),
                  ...deductions.map((d) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(child: Text('- ${d.label}', style: const TextStyle(fontSize: 12, color: Colors.red))),
                      SizedBox(width: 70, child: Text('-${_fmt(d.amount)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600))),
                    ]),
                  )),
                  const Divider(height: 8),
                  Row(children: [
                    const Expanded(child: Text('จ่ายสุทธิ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    Text(_fmt(amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ]),
                ],
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Add/Edit form sheet ───────────────────────────────────────────────────────

class _PayrollFormSheet extends StatefulWidget {
  final String mode;
  final TeacherPayrollModel? teacher;
  final AdminPayrollModel? admin;
  final List<TeacherPayrollModel> existingTeachers;
  final List<AdminPayrollModel> existingAdmins;
  final VoidCallback onSaved;
  const _PayrollFormSheet({required this.mode, this.teacher, this.admin,
      this.existingTeachers = const [], this.existingAdmins = const [],
      required this.onSaved});
  @override
  State<_PayrollFormSheet> createState() => _PayrollFormSheetState();
}

class _PayrollFormSheetState extends State<_PayrollFormSheet> {
  final _nameCtrl = TextEditingController();
  final _weekCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl   = TextEditingController();

  List<_RoleRow> _roles = [_RoleRow()];
  List<_DeductRow> _deducts = [];
  bool _saving = false;

  // รายชื่อครู (สำหรับช่องค้นหาในโหมดครู)
  List<UserModel> _teacherUsers = [];
  String? _teacherCode; // รหัสครูที่เลือก (ไว้แสดงในช่อง)

  bool get _isEdit => widget.teacher != null || widget.admin != null;

  // แสดงแบนเนอร์เมื่อเพิ่งดึงข้อมูลครั้งก่อนมาเติม
  bool _prefilled = false;

  /// งวดล่าสุดก่อนหน้าของชื่อที่ระบุ (ใช้เป็นต้นแบบอัตรา/หมายเหตุ) — null ถ้าไม่มี
  dynamic _lastEntryFor(String name) {
    if (name.trim().isEmpty) return null;
    if (widget.mode == 'teacher') {
      final m = widget.existingTeachers
          .where((t) => t.teacherName.trim() == name.trim() &&
              (!_isEdit || t.id != widget.teacher!.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return m.isEmpty ? null : m.first;
    }
    final m = widget.existingAdmins
        .where((a) => a.adminName.trim() == name.trim() &&
            (!_isEdit || a.id != widget.admin!.id))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return m.isEmpty ? null : m.first;
  }

  /// ดึงรายการ/อัตรา/หักเงิน/หมายเหตุ จากงวดล่าสุดมาเติมในฟอร์ม (ไม่แตะวันที่/ชื่อ)
  void _applyPreviousData() {
    final last = _lastEntryFor(_nameCtrl.text);
    if (last == null) return;
    final List<PayrollRole> roles = last.roles;
    final List<PayrollDeduction> deds = last.deductions;
    final String? note = last.note;
    setState(() {
      _roles = roles
          .map((r) => _RoleRow(role: r.role, rate: _numStr(r.rate), count: _numStr(r.count)))
          .toList();
      if (_roles.isEmpty) _roles = [_RoleRow()];
      _deducts = deds.map((d) => _DeductRow(label: d.label, amount: _numStr(d.amount))).toList();
      if (note != null && note.isNotEmpty) _noteCtrl.text = note;
      _prefilled = true;
    });
  }

  static String _numStr(double n) => n % 1 == 0 ? n.toInt().toString() : n.toString();

  /// เปิดปฏิทินเลือกวันที่ให้ช่อง from/to
  Future<void> _pickDate(TextEditingController ctrl) async {
    final initial = parseDateStr(ctrl.text) ?? nowThai();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => ctrl.text = toStorageDateStr(picked));
  }

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'teacher') _loadTeachers();
    if (widget.teacher != null) {
      final t = widget.teacher!;
      _nameCtrl.text = t.teacherName;
      _weekCtrl.text = t.weekLabel ?? '';
      _noteCtrl.text = t.note ?? '';
      _fromCtrl.text = t.dateFrom ?? '';
      _toCtrl.text   = t.dateTo ?? '';
      _roles   = t.roles.map((r) => _RoleRow(role: r.role, rate: r.rate.toString(), count: r.count.toString())).toList();
      _deducts = t.deductions.map((d) => _DeductRow(label: d.label, amount: d.amount.toString())).toList();
    } else if (widget.admin != null) {
      final a = widget.admin!;
      _nameCtrl.text = a.adminName;
      _weekCtrl.text = a.weekLabel ?? '';
      _noteCtrl.text = a.note ?? '';
      _fromCtrl.text = a.dateFrom ?? '';
      _toCtrl.text   = a.dateTo ?? '';
      _roles   = a.roles.map((r) => _RoleRow(role: r.role, rate: r.rate.toString(), count: r.count.toString())).toList();
      _deducts = a.deductions.map((d) => _DeductRow(label: d.label, amount: d.amount.toString())).toList();
    }
  }

  Future<void> _loadTeachers() async {
    try {
      final users = await FirestoreService.watchUsers(role: 'teacher').first;
      if (!mounted) return;
      setState(() {
        _teacherUsers = users;
        // เติมรหัสครูให้ช่องที่เลือกอยู่ (โหมดแก้ไข) จากชื่อที่ตรงกัน
        if (_nameCtrl.text.isNotEmpty) {
          for (final u in users) {
            if (u.name == _nameCtrl.text) { _teacherCode = u.code; break; }
          }
        }
      });
    } catch (_) {/* โหลดไม่ได้ → ยังพิมพ์เองได้ */}
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _weekCtrl.dispose(); _noteCtrl.dispose();
    _fromCtrl.dispose(); _toCtrl.dispose();
    super.dispose();
  }

  double get _gross => _roles.fold(0, (s, r) => s + (double.tryParse(r.rate) ?? 0) * (double.tryParse(r.count) ?? 0));
  double get _totalDeducts => _deducts.fold(0, (s, d) => s + (double.tryParse(d.amount) ?? 0));
  double get _net => _gross - _totalDeducts;

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาระบุชื่อ')));
      return;
    }
    final validRoles = _roles.where((r) => r.role.trim().isNotEmpty).map((r) => PayrollRole(
      role: r.role.trim(),
      rate: double.tryParse(r.rate) ?? 0,
      count: double.tryParse(r.count) ?? 0,
    )).toList();
    if (validRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเพิ่มอย่างน้อย 1 รายการ')));
      return;
    }
    final validDeducts = _deducts.where((d) => d.label.trim().isNotEmpty && (double.tryParse(d.amount) ?? 0) > 0)
        .map((d) => PayrollDeduction(label: d.label.trim(), amount: double.tryParse(d.amount) ?? 0)).toList();

    final gross = validRoles.fold(0.0, (s, r) => s + r.total);
    final totalDeductsAmt = validDeducts.fold(0.0, (s, d) => s + d.amount);
    final totalAmount = gross - totalDeductsAmt;
    final totalSessions = validRoles.fold(0.0, (s, r) => s + r.count);
    final now = nowThaiIso();

    setState(() => _saving = true);
    try {
      if (widget.mode == 'teacher') {
        final data = <String, dynamic>{
          'teacherName': _nameCtrl.text.trim(),
          'roles': validRoles.map((r) => r.toMap()).toList(),
          if (validDeducts.isNotEmpty) 'deductions': validDeducts.map((d) => d.toMap()).toList() else 'deductions': [],
          'totalSessions': totalSessions, 'totalAmount': totalAmount, 'totalDeductions': totalDeductsAmt,
          if (_fromCtrl.text.isNotEmpty) 'dateFrom': _fromCtrl.text,
          if (_toCtrl.text.isNotEmpty) 'dateTo': _toCtrl.text,
          if (_weekCtrl.text.trim().isNotEmpty) 'weekLabel': _weekCtrl.text.trim(),
          if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
          'status': 'pending', 'createdAt': now,
        };
        if (_isEdit) {
          await FirestoreService.updateTeacherPayroll(widget.teacher!.id, data);
        } else {
          await FirestoreService.addTeacherPayroll(data);
        }
      } else {
        final data = <String, dynamic>{
          'adminName': _nameCtrl.text.trim(),
          'roles': validRoles.map((r) => r.toMap()).toList(),
          if (validDeducts.isNotEmpty) 'deductions': validDeducts.map((d) => d.toMap()).toList() else 'deductions': [],
          'totalAmount': totalAmount, 'totalDeductions': totalDeductsAmt,
          if (_fromCtrl.text.isNotEmpty) 'dateFrom': _fromCtrl.text,
          if (_toCtrl.text.isNotEmpty) 'dateTo': _toCtrl.text,
          if (_weekCtrl.text.trim().isNotEmpty) 'weekLabel': _weekCtrl.text.trim(),
          if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
          'status': 'pending', 'createdAt': now,
        };
        if (_isEdit) {
          await FirestoreService.updateAdminPayroll(widget.admin!.id, data);
        } else {
          await FirestoreService.addAdminPayroll(data);
        }
      }
      if (mounted) Navigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกล้มเหลว: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit ? 'แก้ไขรายการ' : 'เพิ่มรายการ';
    final sub = widget.mode == 'teacher' ? 'ค่าจ้างครู' : 'ค่าจ้างแอดมิน';

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // Handle
        Center(child: Container(margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$title — $sub', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ])),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1),
        // Form
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Name — โหมดครูใช้ช่องค้นหารายชื่อ (ชื่อ/รหัส), โหมดแอดมินพิมพ์เอง
            if (widget.mode == 'teacher') ...[
              const Text('ชื่อครู', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              UserSearchField(
                users: _teacherUsers,
                currentName: _nameCtrl.text.isEmpty ? null : _nameCtrl.text,
                currentCode: _teacherCode,
                hint: 'ค้นหา/เลือกครู...',
                title: 'ค้นหาครู',
                color: const Color(0xFFF97316),
                onSelected: (u) {
                  setState(() {
                    _nameCtrl.text = u.name;
                    _teacherCode = u.code;
                  });
                  if (!_isEdit) _applyPreviousData();
                },
              ),
            ] else
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'ชื่อแอดมิน',
                  prefixIcon: const Icon(Icons.person_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            const SizedBox(height: 12),

            // ── ใช้ข้อมูลครั้งก่อน (จำอัตรา/หมายเหตุ) ──────────────────────
            if (!_isEdit && _lastEntryFor(_nameCtrl.text) != null) ...[
              OutlinedButton.icon(
                onPressed: _applyPreviousData,
                icon: const Icon(Icons.history, size: 18),
                label: const Text('ใช้อัตรา/หมายเหตุครั้งก่อน'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF97316),
                  side: const BorderSide(color: Color(0xFFF97316)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_prefilled) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(child: Text('ดึงอัตรา/หมายเหตุจากงวดก่อนมาให้แล้ว — แก้ "จำนวน" และวันที่ได้เลย',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900))),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            // Role rows
            const Text('รายการค่าจ้าง', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _rolesSection(),
            const SizedBox(height: 16),

            // Deductions
            const Text('รายการหักเงิน', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 8),
            _deductsSection(),
            const SizedBox(height: 16),

            // Net summary
            if (_gross > 0) Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(children: [
                _SumRow('รวมค่าจ้าง', _fmt(_gross)),
                if (_totalDeducts > 0) _SumRow('หักเงิน', '-${_fmt(_totalDeducts)}', color: Colors.red),
                if (_totalDeducts > 0) const Divider(height: 8),
                _SumRow('จ่ายสุทธิ', _fmt(_net), bold: true),
              ]),
            ),
            const SizedBox(height: 16),

            // Date range — แตะเพื่อเลือกจากปฏิทิน
            Row(children: [
              Expanded(child: _dateField(_fromCtrl, 'ตั้งแต่วันที่')),
              const SizedBox(width: 8),
              Expanded(child: _dateField(_toCtrl, 'ถึงวันที่')),
            ]),
            const SizedBox(height: 10),

            // Week label
            TextField(
              controller: _weekCtrl,
              decoration: InputDecoration(
                labelText: 'สัปดาห์/ช่วงเวลา (ไม่บังคับ)',
                hintText: 'เช่น สัปดาห์ที่ 1 มิ.ย. 69',
                prefixIcon: const Icon(Icons.date_range_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),

            // Note
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'หมายเหตุ (ไม่บังคับ)',
                prefixIcon: const Icon(Icons.notes_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('บันทึก', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        )),
      ]),
    );
  }

  Widget _rolesSection() => Column(children: [
    // Header
    const Row(children: [
      Expanded(child: Text('รายการ/บทบาท', style: TextStyle(fontSize: 11, color: Colors.grey))),
      SizedBox(width: 80, child: Text('อัตรา (฿)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey))),
      SizedBox(width: 70, child: Text('จำนวน', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey))),
      SizedBox(width: 36),
    ]),
    const SizedBox(height: 4),
    ..._roles.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(child: _miniField(hint: 'เช่น สอนรายชั่วโมง', init: e.value.role,
            onChange: (v) { _roles[e.key].role = v; })),
        const SizedBox(width: 6),
        SizedBox(width: 80, child: _miniField(hint: '0', init: e.value.rate, numpad: true,
            onChange: (v) => setState(() => _roles[e.key].rate = v))),
        const SizedBox(width: 6),
        SizedBox(width: 70, child: _miniField(hint: '0', init: e.value.count, numpad: true,
            onChange: (v) => setState(() => _roles[e.key].count = v))),
        SizedBox(width: 36, child: IconButton(
          padding: EdgeInsets.zero, iconSize: 18,
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () => setState(() {
            if (_roles.length > 1) _roles.removeAt(e.key); else _roles[e.key] = _RoleRow();
          }),
        )),
      ]),
    )),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      TextButton.icon(
        onPressed: () => setState(() => _roles.add(_RoleRow())),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('เพิ่มรายการ', style: TextStyle(fontSize: 13)),
        style: TextButton.styleFrom(foregroundColor: const Color(0xFFF97316)),
      ),
      Text('รวม: ${_fmt(_gross)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    ]),
  ]);

  Widget _deductsSection() => Column(children: [
    ..._deducts.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(child: _miniField(hint: 'เช่น ขาดงาน, ปรับ', init: e.value.label,
            onChange: (v) { _deducts[e.key].label = v; })),
        const SizedBox(width: 6),
        SizedBox(width: 100, child: _miniField(hint: '0.00', init: e.value.amount, numpad: true,
            onChange: (v) => setState(() => _deducts[e.key].amount = v))),
        SizedBox(width: 36, child: IconButton(
          padding: EdgeInsets.zero, iconSize: 18,
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () => setState(() => _deducts.removeAt(e.key)),
        )),
      ]),
    )),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => setState(() => _deducts.add(_DeductRow())),
        icon: const Icon(Icons.add, size: 16),
        label: const Text('เพิ่มรายการหัก', style: TextStyle(fontSize: 13)),
        style: TextButton.styleFrom(foregroundColor: Colors.red),
      ),
    ),
  ]);

  Widget _dateField(TextEditingController ctrl, String label) => TextField(
    controller: ctrl,
    readOnly: true,
    onTap: () => _pickDate(ctrl),
    decoration: InputDecoration(
      labelText: label,
      hintText: 'แตะเพื่อเลือก',
      prefixIcon: const Icon(Icons.calendar_today, size: 18),
      suffixIcon: ctrl.text.isEmpty ? null : IconButton(
        icon: const Icon(Icons.clear, size: 18),
        onPressed: () => setState(() => ctrl.clear()),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  Widget _miniField({required String hint, required String init,
      required ValueChanged<String> onChange, bool numpad = false}) {
    final ctrl = TextEditingController(text: init);
    ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    return TextField(
      controller: ctrl,
      keyboardType: numpad ? const TextInputType.numberWithOptions(decimal: true) : null,
      onChanged: onChange,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
    );
  }
}

class _SumRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;
  const _SumRow(this.label, this.value, {this.color, this.bold = false});
  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: color ?? Colors.black87))),
    Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87)),
  ]);
}

// ── Simple mutable row models ─────────────────────────────────────────────────

class _RoleRow {
  String role; String rate; String count;
  _RoleRow({this.role = '', this.rate = '', this.count = ''});
}

class _DeductRow {
  String label; String amount;
  _DeductRow({this.label = '', this.amount = ''});
}
