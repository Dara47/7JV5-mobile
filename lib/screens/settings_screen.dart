import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;
import '../services/firestore_service.dart';
import '../utils/web_file_picker.dart';
import 'payroll_screen.dart';
import 'import_users_screen.dart';
import 'admin_profile_screen.dart';
import 'session_health_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _lineCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _qrUpload = ''; // รูป QR ที่อัปโหลด (เก็บเป็น data URI base64)
  bool _qrProcessing = false;
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _lineCtrl.dispose();
    _qrCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _fillFromData(Map<String, dynamic> data) {
    if (_loaded) return;
    _loaded = true;
    _lineCtrl.text = data['lineLink'] ?? '';
    _notesCtrl.text = data['notes'] ?? '';
    final qr = (data['qrImageUrl'] ?? '') as String;
    // รูปที่อัปโหลด (ฝัง base64) แยกจาก URL ปกติ
    if (qr.startsWith('data:')) {
      _qrUpload = qr;
    } else {
      _qrCtrl.text = qr;
    }
  }

  /// เลือกรูปจากเครื่อง → ย่อ ≤700px → เก็บเป็น base64 (ไม่ต้องใช้ Firebase Storage)
  Future<void> _pickQrImage() async {
    setState(() => _qrProcessing = true);
    try {
      final picked = await pickWebFile(accept: 'image/*');
      if (picked == null) {
        setState(() => _qrProcessing = false);
        return;
      }
      final decoded = img.decodeImage(picked.bytes);
      if (decoded == null) {
        _snack('อ่านไฟล์รูปไม่ได้ — ลองไฟล์อื่น', error: true);
        setState(() => _qrProcessing = false);
        return;
      }
      // ย่อด้านยาวสุดไม่เกิน 700px (พอสำหรับสแกน QR และเก็บใน Firestore ได้)
      final resized = (decoded.width > 700 || decoded.height > 700)
          ? img.copyResize(decoded,
              width: decoded.width >= decoded.height ? 700 : null,
              height: decoded.height > decoded.width ? 700 : null)
          : decoded;
      final jpg = img.encodeJpg(resized, quality: 88);
      setState(() {
        _qrUpload = 'data:image/jpeg;base64,${base64Encode(jpg)}';
        _qrProcessing = false;
      });
    } catch (e) {
      _snack('ประมวลผลรูปไม่สำเร็จ: $e', error: true);
      setState(() => _qrProcessing = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null));
  }

  /// พรีวิวรูป QR — รองรับทั้ง data URI (อัปโหลด) และ URL ปกติ
  Widget _qrImagePreview(String value) {
    if (value.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.qr_code_2, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text('อัปโหลดรูป หรือวาง URL', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
      );
    }
    Widget errorBox() => Container(
          height: 100,
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.broken_image_outlined, color: Colors.red.shade300),
            const SizedBox(width: 8),
            Text('โหลดภาพไม่ได้', style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
          ]),
        );
    final image = value.startsWith('data:')
        ? Image.memory(base64Decode(value.substring(value.indexOf(',') + 1)),
            height: 200, fit: BoxFit.contain, errorBuilder: (_, __, ___) => errorBox())
        : Image.network(value,
            height: 200, fit: BoxFit.contain, errorBuilder: (_, __, ___) => errorBox());
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: image);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // อัปโหลดรูปมาก่อน (base64) ถ้าไม่มีค่อยใช้ URL ที่พิมพ์
      final qrValue = _qrUpload.isNotEmpty ? _qrUpload : _qrCtrl.text.trim();
      await FirestoreService.saveSettings({
        'lineLink': _lineCtrl.text.trim(),
        'qrImageUrl': qrValue,
        'notes': _notesCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกเรียบร้อยแล้ว'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่า'),
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: FirestoreService.watchSettings(),
        builder: (context, snap) {
          if (snap.hasData) _fillFromData(snap.data!);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [

              // ── โปรไฟล์ผู้ดูแล (ล็อกด้วยรหัส — เฉพาะเจ้าของระบบ) ──────
              _SectionHeader(icon: Icons.lock_outline, label: 'โปรไฟล์ผู้ดูแล', color: const Color(0xFF37474F)),
              const SizedBox(height: 4),
              Text(
                'เมนูเฉพาะเจ้าของระบบ — ต้องใส่รหัสก่อนเปิด (ตั้งชื่อผู้ดูแล + บันทึกการใช้งาน ใครทำอะไร)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => openAdminProfileLocked(context),
                  icon: const Icon(Icons.lock_outline, color: Color(0xFF37474F)),
                  label: const Text('เปิดโปรไฟล์ผู้ดูแล (ใส่รหัส)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF37474F))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF37474F)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // ── LINE ──────────────────────────────────────────────────
              _SectionHeader(icon: Icons.chat_bubble_outline, label: 'ลิงก์ LINE', color: const Color(0xFF00C300)),
              const SizedBox(height: 8),
              _Field(
                controller: _lineCtrl,
                hint: 'https://line.me/ti/p/...',
                icon: Icons.link,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 6),
              _PreviewUrl(ctrl: _lineCtrl, prefix: 'line.me'),
              const SizedBox(height: 24),

              // ── QR ธนาคาร ───────────────────────────────────────────
              _SectionHeader(icon: Icons.qr_code_2, label: 'ภาพ QR ธนาคาร', color: const Color(0xFFF97316)),
              const SizedBox(height: 8),
              if (_qrUpload.isNotEmpty) ...[
                // โหมดรูปที่อัปโหลด (ฝังในระบบ)
                _qrImagePreview(_qrUpload),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: _qrProcessing ? null : _pickQrImage,
                    icon: const Icon(Icons.image_outlined, size: 18, color: Color(0xFFF97316)),
                    label: const Text('เปลี่ยนรูป', style: TextStyle(color: Color(0xFFF97316))),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFF97316))),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => setState(() => _qrUpload = ''),
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    label: const Text('ลบรูป', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  )),
                ]),
                const SizedBox(height: 6),
                Text('ใช้รูปที่อัปโหลด (ฝังในระบบ) — กดบันทึกเพื่อยืนยัน',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ] else ...[
                // ปุ่มอัปโหลดรูปจากเครื่อง
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _qrProcessing ? null : _pickQrImage,
                    icon: _qrProcessing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF97316)))
                        : const Icon(Icons.upload_file, color: Color(0xFFF97316)),
                    label: Text(_qrProcessing ? 'กำลังประมวลผล...' : 'อัปโหลดรูป QR จากเครื่อง',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFF97316))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFF97316)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('หรือวางลิงก์รูป (URL)', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ]),
                const SizedBox(height: 10),
                _Field(
                  controller: _qrCtrl,
                  hint: 'https://example.com/qr.png',
                  icon: Icons.link,
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                _qrImagePreview(_qrCtrl.text.trim()),
              ],
              const SizedBox(height: 24),

              // ── หมายเหตุ ─────────────────────────────────────────────
              _SectionHeader(icon: Icons.notes, label: 'หมายเหตุ', color: Colors.blueGrey),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'ข้อความหมายเหตุ / ข้อมูลติดต่อ...',
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 32),

              // ── บันทึก ───────────────────────────────────────────────
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: const Text('บันทึกการตั้งค่า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF37474F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── บัญชีค่าจ้าง ─────────────────────────────────────────
              const Divider(),
              const SizedBox(height: 8),
              _SectionHeader(icon: Icons.account_balance_wallet_outlined, label: 'บัญชีค่าจ้าง', color: const Color(0xFFF97316)),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollScreen())),
                  icon: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFF97316)),
                  label: const Text('เปิดหน้าบัญชีค่าจ้าง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF97316))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF97316)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── นำเข้าผู้ใช้ (Bulk Import) ────────────────────────────
              const Divider(),
              const SizedBox(height: 8),
              _SectionHeader(icon: Icons.group_add_outlined, label: 'นำเข้าข้อมูล (Bulk Import)', color: const Color(0xFF2E7D32)),
              const SizedBox(height: 4),
              Text(
                'อัปโหลด CSV / JSON: นำเข้าครู-นักเรียน และความสัมพันธ์ครู-นักเรียน (แพ็กเกจ+ตาราง) ทีละหลายคน — โอนย้ายข้อมูลจาก V4.1.2 คงรหัสเดิม S26xxxx ได้',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ImportUsersScreen())),
                  icon: const Icon(Icons.upload_file, color: Color(0xFF2E7D32)),
                  label: const Text('เปิดหน้านำเข้าข้อมูล', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2E7D32)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── ตรวจสุขภาพข้อมูลคาบ ──────────────────────────────────
              const Divider(),
              const SizedBox(height: 8),
              _SectionHeader(icon: Icons.health_and_safety_outlined, label: 'ตรวจสุขภาพข้อมูลคาบ', color: const Color(0xFF00897B)),
              const SizedBox(height: 4),
              Text(
                'ตรวจว่า "เรียนแล้ว (รวม−เหลือ)" ของทุกแพ็กตรงกับจำนวนคาบที่เรียนจริงไหม — อ่านอย่างเดียว ไม่แก้ไขข้อมูล',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SessionHealthScreen())),
                  icon: const Icon(Icons.health_and_safety_outlined, color: Color(0xFF00897B)),
                  label: const Text('ตรวจสุขภาพข้อมูลคาบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00897B))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00897B)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── ออกจากระบบ ───────────────────────────────────────────
              const Divider(),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('ออกจากระบบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('ยืนยันออกจากระบบ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ออก', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) FirebaseAuth.instance.signOut();
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: color),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
  ]);
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _Field({required this.controller, required this.hint, required this.icon, this.keyboardType, this.onChanged});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );
}

class _PreviewUrl extends StatefulWidget {
  final TextEditingController ctrl;
  final String prefix;
  const _PreviewUrl({required this.ctrl, required this.prefix});
  @override
  State<_PreviewUrl> createState() => _PreviewUrlState();
}

class _PreviewUrlState extends State<_PreviewUrl> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.ctrl.text.trim();
    if (url.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const Icon(Icons.check_circle, size: 14, color: Color(0xFF00C300)),
        const SizedBox(width: 6),
        Expanded(child: Text(url, style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32)), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

