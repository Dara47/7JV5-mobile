import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

class UserFormScreen extends StatefulWidget {
  final UserModel? existing;
  const UserFormScreen({super.key, this.existing});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _meetCtrl = TextEditingController();
  final _sessionsCtrl = TextEditingController();

  final _codeCtrl = TextEditingController();
  String _role = 'student';
  bool _loadingCode = false;
  bool _saving = false;
  String? _codeError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final u = widget.existing!;
      _role = u.role;
      _codeCtrl.text = u.code;
      _nameCtrl.text = u.name;
      _ageCtrl.text = u.age?.toString() ?? '';
      _meetCtrl.text = u.googleMeetLink ?? '';
      _sessionsCtrl.text = u.defaultSessions?.toString() ?? '';
    } else {
      _fetchCode('student');
    }
  }

  Future<void> _fetchCode(String role) async {
    setState(() { _loadingCode = true; _codeError = null; });
    final code = await FirestoreService.generateCode(role);
    if (mounted) setState(() { _codeCtrl.text = code; _loadingCode = false; });
  }

  /// เติมรหัสชุด "เพิ่มเอง" ไล่เลขเริ่มที่ 261000 (แยกจากชุดอัตโนมัติ 270000)
  Future<void> _fetchManualCode(String role) async {
    setState(() { _loadingCode = true; _codeError = null; });
    final code = await FirestoreService.generateManualCode(role);
    if (mounted) setState(() { _codeCtrl.text = code; _loadingCode = false; });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // ── ตรวจรหัส: รูปแบบ (S=นักเรียน / T=ครู) + กันซ้ำ ──
    final code = _codeCtrl.text.trim().toUpperCase();
    final expectedPrefix = _role == 'student' ? 'S' : 'T';
    final roleLabel = _role == 'student' ? 'นักเรียน' : 'ครู';
    if (code.isEmpty) {
      setState(() => _codeError = 'กรุณากรอกรหัสผู้ใช้');
      return;
    }
    if (!code.startsWith(expectedPrefix) || code.length < 2 ||
        int.tryParse(code.substring(1)) == null) {
      setState(() => _codeError = 'รหัส$roleLabelต้องเป็น "$expectedPrefix" ตามด้วยตัวเลข (เช่น ${expectedPrefix}260001)');
      return;
    }

    setState(() { _saving = true; _codeError = null; });

    final taken = await FirestoreService.isCodeTaken(code, excludeId: widget.existing?.id);
    if (taken) {
      if (mounted) setState(() { _codeError = 'รหัส "$code" ถูกใช้แล้ว'; _saving = false; });
      return;
    }

    final data = {
      'code': code,
      'name': _nameCtrl.text.trim(),
      'role': _role,
      'status': 'active',
      if (_ageCtrl.text.isNotEmpty) 'age': int.tryParse(_ageCtrl.text.trim()),
      if (_role == 'teacher' && _meetCtrl.text.isNotEmpty)
        'googleMeetLink': _meetCtrl.text.trim(),
      if (_role == 'student' && _sessionsCtrl.text.isNotEmpty)
        'defaultSessions': int.tryParse(_sessionsCtrl.text.trim()),
    };

    try {
      if (_isEdit) {
        await FirestoreService.updateUserCascade(
            widget.existing!.id, _role, data, oldName: widget.existing!.name);
      } else {
        await FirestoreService.addUser(data);
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
    _codeCtrl.dispose();
    _nameCtrl.dispose(); _ageCtrl.dispose(); _meetCtrl.dispose(); _sessionsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        title: Text(_isEdit ? 'แก้ไขข้อมูล' : 'เพิ่มผู้ใช้ใหม่'),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(20), children: [

          // Role selector
          _label('ประเภทผู้ใช้'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _RoleCard(
              label: 'นักเรียน', icon: Icons.school_outlined,
              selected: _role == 'student',
              color: const Color(0xFFF97316),
              onTap: _isEdit ? null : () {
                setState(() => _role = 'student');
                _fetchCode('student');
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: _RoleCard(
              label: 'ครู', icon: Icons.person_outlined,
              selected: _role == 'teacher',
              color: const Color(0xFF2E7D32),
              onTap: _isEdit ? null : () {
                setState(() => _role = 'teacher');
                _fetchCode('teacher');
              },
            )),
          ]),
          const SizedBox(height: 20),

          // รหัสผู้ใช้ — สร้างอัตโนมัติ หรือกรอกเอง (เช่น โอนย้ายข้อมูลเดิม S26xxxx)
          _label('รหัสผู้ใช้ *'),
          const SizedBox(height: 8),
          if (_isEdit)
            // โหมดแก้ไข: ล็อกรหัส (ผูกกับแพ็กเกจที่เก็บ studentCode/teacherCode ไว้)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(children: [
                Icon(Icons.lock_outline, color: Colors.grey.shade500, size: 20),
                const SizedBox(width: 12),
                Text(_codeCtrl.text,
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5,
                      color: _role == 'student' ? const Color(0xFFF97316) : const Color(0xFF2E7D32),
                    )),
                const Spacer(),
                Text('เปลี่ยนไม่ได้', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ]),
            )
          else ...[
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _codeCtrl,
                  enabled: !_loadingCode,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) { if (_codeError != null) setState(() => _codeError = null); },
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2,
                    color: _role == 'student' ? const Color(0xFFF97316) : const Color(0xFF2E7D32),
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.badge_outlined, size: 20, color: Colors.grey.shade500),
                    hintText: _role == 'student' ? 'เช่น S260001' : 'เช่น T260001',
                    filled: true, fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF97316), width: 2)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ปุ่มชุด "เพิ่มเอง" — เติมรหัสไล่เลขเริ่ม 261000
              SizedBox(
                height: 52, width: 52,
                child: OutlinedButton(
                  onPressed: _loadingCode ? null : () => _fetchManualCode(_role),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    '${_role == 'student' ? 'S' : 'T'}26',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ปุ่มชุด "อัตโนมัติ" — เติมรหัสไล่เลขเริ่ม 270000 (เหมือนเดิม)
              SizedBox(
                height: 52, width: 52,
                child: OutlinedButton(
                  onPressed: _loadingCode ? null : () => _fetchCode(_role),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: _loadingCode
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.autorenew, color: Color(0xFFF97316)),
                ),
              ),
            ]),
            if (_codeError != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.error_outline, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(child: Text(_codeError!, style: const TextStyle(color: Colors.red, fontSize: 12))),
              ]),
            ],
            const SizedBox(height: 6),
            Text('พิมพ์เองได้ · ปุ่ม "${_role == 'student' ? 'S' : 'T'}26" = สร้างรหัสมือไล่เลขเริ่ม ${_role == 'student' ? 'S' : 'T'}261000 · ปุ่ม ↻ = อัตโนมัติเริ่ม ${_role == 'student' ? 'S' : 'T'}270000',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
          const SizedBox(height: 20),

          // Name
          _label('ชื่อ-นามสกุล *'),
          const SizedBox(height: 8),
          _Field(
            controller: _nameCtrl,
            hint: 'กรอกชื่อ-นามสกุล',
            icon: Icons.person_outline,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อ' : null,
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 16),

          // Age
          _label('อายุ'),
          const SizedBox(height: 8),
          _Field(
            controller: _ageCtrl,
            hint: 'อายุ (ปี)',
            icon: Icons.cake_outlined,
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              final n = int.tryParse(v);
              if (n == null || n < 1 || n > 100) return 'อายุ 1–100 ปี';
              return null;
            },
          ),

          // จำนวนคาบ (student only)
          if (_role == 'student') ...[
            const SizedBox(height: 16),
            _label('จำนวนคาบทั้งหมด'),
            const SizedBox(height: 8),
            _Field(
              controller: _sessionsCtrl,
              hint: 'จำนวนคาบที่จะเรียน',
              icon: Icons.book_outlined,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                final n = int.tryParse(v);
                if (n == null || n < 1) return 'กรอกตัวเลข 1 ขึ้นไป';
                return null;
              },
            ),
          ],

          // Google Meet link (teacher only)
          if (_role == 'teacher') ...[
            const SizedBox(height: 16),
            _label('ลิงก์ Google Meet'),
            const SizedBox(height: 8),
            _Field(
              controller: _meetCtrl,
              hint: 'https://meet.google.com/xxx-xxxx-xxx',
              icon: Icons.video_call_outlined,
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!v.trim().startsWith('http')) return 'ลิงก์ต้องขึ้นต้นด้วย http';
                return null;
              },
            ),
          ],

          const SizedBox(height: 32),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving || _loadingCode ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_isEdit ? 'บันทึกการแก้ไข' : 'เพิ่มผู้ใช้', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87));
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({required this.controller, required this.hint, required this.icon, this.keyboardType, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF97316), width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;

  const _RoleCard({required this.label, required this.icon, required this.selected, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: color.withAlpha(60), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Column(children: [
          Icon(icon, size: 28, color: selected ? Colors.white : color),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: selected ? Colors.white : color)),
        ]),
      ),
    );
  }
}
