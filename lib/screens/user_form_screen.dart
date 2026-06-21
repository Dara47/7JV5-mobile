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

  String _role = 'student';
  String _generatedCode = '';
  bool _loadingCode = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final u = widget.existing!;
      _role = u.role;
      _generatedCode = u.code;
      _nameCtrl.text = u.name;
      _ageCtrl.text = u.age?.toString() ?? '';
      _meetCtrl.text = u.googleMeetLink ?? '';
      _sessionsCtrl.text = u.defaultSessions?.toString() ?? '';
    } else {
      _fetchCode('student');
    }
  }

  Future<void> _fetchCode(String role) async {
    setState(() => _loadingCode = true);
    final code = await FirestoreService.generateCode(role);
    if (mounted) setState(() { _generatedCode = code; _loadingCode = false; });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = {
      'code': _generatedCode,
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
        await FirestoreService.updateUser(widget.existing!.id, data);
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
    _nameCtrl.dispose(); _ageCtrl.dispose(); _meetCtrl.dispose(); _sessionsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        title: Text(_isEdit ? 'แก้ไขข้อมูล' : 'เพิ่มผู้ใช้ใหม่'),
        backgroundColor: const Color(0xFF1565C0),
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
              color: const Color(0xFF1565C0),
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

          // Auto code display
          _label('รหัสผู้ใช้ (อัตโนมัติ)'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(children: [
              Icon(Icons.badge_outlined, color: Colors.grey.shade500, size: 20),
              const SizedBox(width: 12),
              _loadingCode
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_generatedCode,
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5,
                        color: _role == 'student' ? const Color(0xFF1565C0) : const Color(0xFF2E7D32),
                      )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                child: Text('Auto', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ),
            ]),
          ),
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
                backgroundColor: const Color(0xFF1565C0),
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
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2)),
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
