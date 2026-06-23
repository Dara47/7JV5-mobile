import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'audit_log_screen.dart';

const String kAdminProfilePasscode = 'ATAL190314';

/// หน้าโปรไฟล์ผู้ดูแล — ล็อกด้วยรหัส เปิดดูได้เฉพาะเจ้าของระบบ
/// (ตั้งชื่อผู้ดูแล + บันทึกการใช้งาน "ใครทำอะไร")
class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});
  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _savingName = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = FirestoreService.currentUser?.name ?? '';
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อผู้ดูแล')));
      return;
    }
    setState(() => _savingName = true);
    try {
      await FirestoreService.saveAdminName(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกชื่อผู้ดูแลแล้ว'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirestoreService.currentUser?.email ?? '';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('โปรไฟล์ผู้ดูแล'),
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Row(children: [
            Icon(Icons.badge_outlined, color: Color(0xFF37474F)),
            SizedBox(width: 8),
            Text('ชื่อผู้ดูแลของบัญชีนี้', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text(
            'ใช้แสดงในบันทึกการใช้งาน ว่าใครทำอะไร'
            '${email.isNotEmpty ? '\nบัญชี: $email' : ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline),
                  hintText: 'ชื่อผู้ดูแล',
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _savingName ? null : _saveName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF37474F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _savingName
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('บันทึกชื่อ'),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Row(children: [
            Icon(Icons.history, color: Color(0xFF37474F)),
            SizedBox(width: 8),
            Text('บันทึกการใช้งาน', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text('ดูว่าผู้ดูแลคนไหนทำอะไร เมื่อไหร่ (ตัดคาบ/อนุมัติใบลา/เพิ่ม-ลบผู้ใช้/นำเข้า)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuditLogScreen())),
              icon: const Icon(Icons.history, color: Color(0xFF37474F)),
              label: const Text('เปิดบันทึกการใช้งาน (ใครทำอะไร)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF37474F))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF37474F)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// แสดง dialog ขอรหัสผ่านก่อนเข้าหน้าโปรไฟล์ผู้ดูแล — รหัสถูกถึงจะเปิด
Future<void> openAdminProfileLocked(BuildContext context) async {
  final ctrl = TextEditingController();
  String? error;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.lock_outline, color: Color(0xFF37474F)),
          SizedBox(width: 8),
          Text('เมนูเฉพาะเจ้าของระบบ'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('กรอกรหัสเพื่อเปิดโปรไฟล์ผู้ดูแล'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) {
              if (ctrl.text.trim() == kAdminProfilePasscode) {
                Navigator.pop(ctx, true);
              } else {
                setD(() => error = 'รหัสไม่ถูกต้อง');
              }
            },
            decoration: InputDecoration(
              hintText: 'รหัส',
              errorText: error,
              filled: true, fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim() == kAdminProfilePasscode) {
                Navigator.pop(ctx, true);
              } else {
                setD(() => error = 'รหัสไม่ถูกต้อง');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF37474F), foregroundColor: Colors.white),
            child: const Text('เปิด'),
          ),
        ],
      ),
    ),
  );
  if (ok == true && context.mounted) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminProfileScreen()));
  }
}
