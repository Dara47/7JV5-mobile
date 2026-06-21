import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _lineCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
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
    _qrCtrl.text = data['qrImageUrl'] ?? '';
    _notesCtrl.text = data['notes'] ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FirestoreService.saveSettings({
        'lineLink': _lineCtrl.text.trim(),
        'qrImageUrl': _qrCtrl.text.trim(),
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
              _SectionHeader(icon: Icons.qr_code_2, label: 'ภาพ QR ธนาคาร (URL)', color: const Color(0xFF1565C0)),
              const SizedBox(height: 8),
              _Field(
                controller: _qrCtrl,
                hint: 'https://example.com/qr.png',
                icon: Icons.image_outlined,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              _QrPreview(ctrl: _qrCtrl),
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

  const _Field({required this.controller, required this.hint, required this.icon, this.keyboardType});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
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

class _QrPreview extends StatefulWidget {
  final TextEditingController ctrl;
  const _QrPreview({required this.ctrl});
  @override
  State<_QrPreview> createState() => _QrPreviewState();
}

class _QrPreviewState extends State<_QrPreview> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.ctrl.text.trim();
    if (url.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.qr_code_2, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text('วาง URL รูป QR แล้วกดบันทึก', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        height: 200,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          height: 100,
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.broken_image_outlined, color: Colors.red.shade300),
            const SizedBox(width: 8),
            Text('โหลดภาพไม่ได้ ตรวจสอบ URL', style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
          ]),
        ),
      ),
    );
  }
}
