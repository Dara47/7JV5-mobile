import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

/// หน้า "ตรวจค่าผิดปกติ" — อ่านอย่างเดียว ไม่แก้ไขข้อมูล
/// สแกนตาราง/แพ็กเกจที่ใช้งานอยู่ หาค่าที่ผิดจริง (แดง) และน่าสงสัย (ส้ม)
class AnomalyCheckScreen extends StatefulWidget {
  const AnomalyCheckScreen({super.key});
  @override
  State<AnomalyCheckScreen> createState() => _AnomalyCheckScreenState();
}

class _AnomalyCheckScreenState extends State<AnomalyCheckScreen> {
  static const _purple = Color(0xFF7E57C2);
  static const _pageSize = 30;
  bool _loading = true;
  String? _error;
  AnomalyReport? _report;
  int _visible = _pageSize;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _visible = _pageSize; });
    try {
      final r = await FirestoreService.checkAnomalies();
      if (mounted) setState(() { _report = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตรวจค่าผิดปกติ'),
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'ตรวจอีกครั้ง',
            onPressed: _loading ? null : _run,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: _purple),
              SizedBox(height: 14),
              Text('กำลังตรวจ... (อ่านทุกแพ็กที่ใช้งานอยู่)'),
            ]))
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('ตรวจไม่สำเร็จ: $_error',
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                ))
              : _buildReport(),
    );
  }

  Widget _buildReport() {
    final r = _report!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(r),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 18, color: Colors.amber.shade800),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'หน้านี้อ่านอย่างเดียว ไม่แก้ไขข้อมูล — แยกเป็น 2 กลุ่ม:\n'
              '🔴 ผิดจริง = โควตาเพี้ยน / เวลากลับด้าน / รูปแบบเวลาผิด — ควรแก้\n'
              '🟠 น่าสงสัย = เวลาแปลก / คาบสั้น-ยาว / วันไกล / คาบซ้ำ — อาจตั้งใจ ตรวจเป็นรายกรณี',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.5),
            )),
          ]),
        ),
        const SizedBox(height: 16),
        if (r.allClean)
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(children: [
              Icon(Icons.verified_rounded, size: 64, color: Colors.green.shade400),
              const SizedBox(height: 12),
              const Text('ไม่พบค่าผิดปกติ ✅',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('ตาราง/โควตาของทุกแพ็กที่ใช้งานอยู่ดูปกติ',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
          ))
        else ...[
          // ── ผิดจริง (แสดงก่อนเสมอ) ──
          _sectionTitle('🔴 ผิดจริง — ควรแก้', r.errors.length, const Color(0xFFE53935)),
          const SizedBox(height: 8),
          if (r.errors.isEmpty)
            _note('ไม่มีค่าผิดจริง ✅', Colors.green.shade600)
          else
            ...r.errors.map(_issueCard),
          const SizedBox(height: 20),

          // ── น่าสงสัย (โหลดเพิ่มได้) ──
          if (r.warnings.isNotEmpty) ...[
            _sectionTitle('🟠 น่าสงสัย — ตรวจเป็นรายกรณี', r.warnings.length, const Color(0xFFFB8C00)),
            const SizedBox(height: 8),
            ...r.warnings.take(_visible).map(_issueCard),
            if (r.warnings.length > _visible)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _visible += _pageSize),
                  icon: const Icon(Icons.expand_more, color: _purple),
                  label: Text('โหลดเพิ่ม • เหลืออีก ${r.warnings.length - _visible} รายการ',
                      style: const TextStyle(color: _purple, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    side: const BorderSide(color: _purple),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _sectionTitle(String text, int count, Color color) => Row(children: [
        Expanded(child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color))),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ),
      ]);

  Widget _note(String text, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(text, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
      );

  Widget _summaryCard(AnomalyReport r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_purple, Color(0xFF9575CD)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        _stat('สแกน', '${r.scannedPackages}', Colors.white),
        _divider(),
        _stat('ผิดจริง', '${r.errors.length}',
            r.errors.isEmpty ? Colors.white : const Color(0xFFFFCDD2)),
        _divider(),
        _stat('น่าสงสัย', '${r.warnings.length}',
            r.warnings.isEmpty ? Colors.white : const Color(0xFFFFE0B2)),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 36, color: Colors.white24);

  Widget _issueCard(AnomalyIssue it) {
    final p = it.pkg;
    final accent = it.isError ? const Color(0xFFE53935) : const Color(0xFFFB8C00);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(it.isError ? Icons.error_outline : Icons.warning_amber_rounded, size: 18, color: accent),
          const SizedBox(width: 6),
          Expanded(child: Text(
            p.studentName.isEmpty ? '(ไม่มีชื่อ)' : p.studentName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          )),
        ]),
        const SizedBox(height: 2),
        Text(
          [if (p.studentCode.isNotEmpty) p.studentCode, if (p.teacherName.isNotEmpty) p.teacherName]
              .join('  •  '),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(it.message,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: accent)),
        ),
      ]),
    );
  }
}
