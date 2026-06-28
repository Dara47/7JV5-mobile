import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

/// หน้า "ตรวจสุขภาพข้อมูลคาบ" — อ่านอย่างเดียว ไม่แก้ไขข้อมูลใดๆ
/// เทียบจำนวน session ที่ completed จริง กับ "เรียนแล้ว (รวม−เหลือ)" ของแต่ละแพ็ก
class SessionHealthScreen extends StatefulWidget {
  const SessionHealthScreen({super.key});
  @override
  State<SessionHealthScreen> createState() => _SessionHealthScreenState();
}

class _SessionHealthScreenState extends State<SessionHealthScreen> {
  static const _teal = Color(0xFF00897B);
  static const _pageSize = 30;
  bool _loading = true;
  String? _error;
  SessionHealthReport? _report;
  int _visible = _pageSize;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() { _loading = true; _error = null; _visible = _pageSize; });
    try {
      final r = await FirestoreService.checkSessionHealth();
      if (mounted) setState(() { _report = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ตรวจสุขภาพข้อมูลคาบ'),
        backgroundColor: _teal,
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
              CircularProgressIndicator(color: _teal),
              SizedBox(height: 14),
              Text('กำลังตรวจ... (อ่านทุกแพ็ก + คาบที่เรียนแล้ว)'),
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
              '🔵 นำเข้าเก่า = กำหนดเรียนแล้วไว้แต่ไม่มี record คาบ (ปกติ ตัวเลขถูกต้อง ไม่ต้องแก้)\n'
              '🔴 drift จริง = มี record คาบแต่ตัวเลขไม่ตรง — ควรตรวจเป็นรายกรณี',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900, height: 1.5),
            )),
          ]),
        ),
        const SizedBox(height: 16),
        if (r.allHealthy)
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(children: [
              Icon(Icons.verified_rounded, size: 64, color: Colors.green.shade400),
              const SizedBox(height: 12),
              const Text('ข้อมูลคาบทุกแพ็กตรงกัน ✅',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('เรียนแล้ว (รวม−เหลือ) = จำนวนคาบที่เรียนจริง ทุกแพ็ก',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
          ))
        else ...[
          // ── drift จริง (ปัญหาที่ควรดู) แสดงก่อนเสมอ ──
          _sectionTitle('🔴 ต้องตรวจ — drift จริง', r.driftIssues.length, const Color(0xFFE53935)),
          const SizedBox(height: 8),
          if (r.driftIssues.isEmpty)
            _note('ไม่มี drift จริง — แพ็กที่มี record คาบ ตัวเลขตรงทั้งหมด ✅', Colors.green.shade600)
          else
            ...r.driftIssues.map(_issueCard),
          const SizedBox(height: 20),

          // ── นำเข้าเก่า (ปกติ — แบ่งหน้าโหลดเพิ่ม) ──
          if (r.legacyIssues.isNotEmpty) ...[
            _sectionTitle('🔵 นำเข้าเก่า — ไม่มี record คาบ (ปกติ)', r.legacyIssues.length, const Color(0xFF1976D2)),
            const SizedBox(height: 4),
            Text('ข้อมูลโอนจาก V4.1.2 ที่ใส่ "เรียนแล้ว" มาเลย ไม่มี record รายคาบ — ตัวเลขถูกต้อง ไม่ต้องแก้',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            ...r.legacyIssues.take(_visible).map(_issueCard),
            if (r.legacyIssues.length > _visible)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _visible += _pageSize),
                  icon: const Icon(Icons.expand_more, color: _teal),
                  label: Text('โหลดเพิ่ม • เหลืออีก ${r.legacyIssues.length - _visible} รายการ',
                      style: const TextStyle(color: _teal, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    side: const BorderSide(color: _teal),
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
        Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
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

  Widget _summaryCard(SessionHealthReport r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_teal, Color(0xFF26A69A)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        _stat('ทั้งหมด', '${r.totalPackages}', Colors.white),
        _divider(),
        _stat('ตรงกัน', '${r.okCount}', Colors.white),
        _divider(),
        _stat('นำเข้าเก่า', '${r.legacyIssues.length}', Colors.white),
        _divider(),
        _stat('ต้องตรวจ', '${r.driftIssues.length}',
            r.driftIssues.isEmpty ? Colors.white : const Color(0xFFFFCDD2)),
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

  Widget _issueCard(SessionHealthIssue it) {
    final p = it.pkg;
    final legacy = it.isLegacy;
    final accent = legacy
        ? const Color(0xFF1976D2)
        : (it.diff > 0 ? const Color(0xFFE53935) : const Color(0xFFFB8C00));
    final badge = legacy
        ? 'ไม่มี record'
        : (it.diff > 0 ? 'session เกิน ${it.diff}' : 'session ขาด ${-it.diff}');
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
          Expanded(child: Text(
            p.studentName.isEmpty ? '(ไม่มีชื่อ)' : p.studentName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(20)),
            child: Text(badge,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 2),
        Text(
          [if (p.studentCode.isNotEmpty) p.studentCode, if (p.teacherName.isNotEmpty) p.teacherName]
              .join('  •  '),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          _chip('รวม', '${p.totalSessions}', Colors.blueGrey),
          _chip('เหลือ', '${p.remainingSessions}', const Color(0xFF1976D2)),
          _chip('เรียนแล้ว(แพ็ก)', '${it.expectedUsed}', const Color(0xFF2E7D32)),
          _chip('คาบจริง', '${it.completedCount}', accent),
        ]),
      ]),
    );
  }

  Widget _chip(String label, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$label: $value',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      );
}
