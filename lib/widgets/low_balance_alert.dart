import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../screens/package_form_dialog.dart';

/// คัดแพ็กเกจที่ยัง active และคาบ "เหลือน้อยกว่า 3" (รวมหมดแล้ว ≤0 และใกล้หมด 1–2)
/// ผู้ใช้กำหนด: แสดงเฉพาะเหลือ < 3 คาบ — ถ้าเรียนต่อ/เพิ่มคาบจนเหลือ ≥ 3 (เช่น 4) จะหลุดจากรายการ
/// เรียงเหลือน้อยสุดขึ้นก่อน
List<PackageModel> lowBalancePackages(List<PackageModel> all) {
  return all
      .where((p) => p.status == 'active' && p.remainingSessions < 3)
      .toList()
    ..sort((a, b) => a.remainingSessions.compareTo(b.remainingSessions));
}

/// รายการ "คาบเรียนใกล้หมด" แบบฝังในหน้า (ไม่ใช่ป๊อปอัป) — แสดงข้อมูลอย่างเดียว copy ชื่อได้
/// แยกกลุ่ม 🔴 หมดแล้ว(≤0) / 🟠 ใกล้หมด(1–2) เรียงเหลือน้อยสุด
class LowBalanceList extends StatefulWidget {
  final List<PackageModel> packages;
  final EdgeInsets padding;
  const LowBalanceList({
    super.key,
    required this.packages,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 100),
  });

  @override
  State<LowBalanceList> createState() => _LowBalanceListState();
}

class _LowBalanceListState extends State<LowBalanceList> {
  static const _red = Color(0xFFE53935);
  static const _orange = Color(0xFFFB8C00);
  static const _pageSize = 30;
  int _visible = _pageSize;

  // คำค้นหา (ชื่อ / รหัสนักเรียน / ครู) — เก็บ controller ใน state ครั้งเดียว
  // (ไม่สร้างใน build ตาม [[gotcha-stream-in-build-focus-loss]]) กันช่องค้นหาหลุดโฟกัส
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// ตรงกับคำค้นไหม (ชื่อนักเรียน / รหัสนักเรียน / ชื่อครู) — ไม่สนตัวพิมพ์เล็กใหญ่
  bool _matches(PackageModel p, String q) {
    return p.studentName.toLowerCase().contains(q) ||
        p.studentCode.toLowerCase().contains(q) ||
        p.teacherName.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final base = lowBalancePackages(widget.packages);
    // ยังไม่มีใครคาบใกล้หมดเลย → แสดงสถานะว่างเฉย ๆ (ไม่ต้องมีช่องค้นหา)
    if (base.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_rounded, size: 56, color: Colors.green.shade300),
          const SizedBox(height: 12),
          Text('ไม่มีนักเรียนคาบใกล้หมด',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
        ]),
      );
    }

    final q = _query.trim().toLowerCase();
    final pkgs = q.isEmpty ? base : base.where((p) => _matches(p, q)).toList();

    return Column(children: [
      _searchField(base.length),
      Expanded(child: _buildList(pkgs)),
    ]);
  }

  Widget _searchField(int total) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() {
            _query = v;
            _visible = _pageSize; // เริ่มนับหน้าใหม่เมื่อเปลี่ยนคำค้น
          }),
          decoration: InputDecoration(
            hintText: 'ค้นหา ชื่อ / รหัสนักเรียน / ครู',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () => setState(() {
                      _searchCtrl.clear();
                      _query = '';
                      _visible = _pageSize;
                    }),
                  ),
            isDense: true,
            filled: true,
            fillColor: Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );

  Widget _buildList(List<PackageModel> pkgs) {
    if (pkgs.isEmpty) {
      // มีรายการอยู่แต่คำค้นไม่ตรงใคร
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text('ไม่พบรายการที่ค้นหา',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        ]),
      );
    }
    // pkgs เรียงเหลือน้อยสุดก่อน → หมดแล้ว(≤0) มาก่อน ใกล้หมด(1–2) เสมอ
    final allExpired = pkgs.where((p) => p.isExpired).toList();
    final allLow = pkgs.where((p) => p.isLowBalance).toList();
    // แสดงแค่ _visible รายการแรกรวมทั้ง 2 กลุ่ม (กันเครื่องอืดตอนรายการเยอะ)
    final shownExpired = allExpired.take(_visible).toList();
    final lowBudget = _visible - allExpired.length;
    final shownLow = lowBudget > 0 ? allLow.take(lowBudget).toList() : const <PackageModel>[];
    final remaining = pkgs.length - shownExpired.length - shownLow.length;

    return SelectionArea(
      child: ListView(
        padding: widget.padding,
        children: [
          if (shownExpired.isNotEmpty) _group('🔴 หมดแล้ว', allExpired.length, shownExpired, _red),
          if (shownLow.isNotEmpty) _group('🟠 ใกล้หมด (1–2 คาบ)', allLow.length, shownLow, _orange),
          if (remaining > 0) _loadMore(remaining),
        ],
      ),
    );
  }

  Widget _group(String title, int totalCount, List<PackageModel> items, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
            child: Text('$title ($totalCount)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          ),
          ...items.map((p) => _LowBalanceRow(p: p, color: color)),
        ],
      );

  Widget _loadMore(int remaining) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _visible += _pageSize),
          icon: const Icon(Icons.expand_more, color: _orange),
          label: Text('โหลดเพิ่ม • เหลืออีก $remaining รายการ',
              style: const TextStyle(color: _orange, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            side: const BorderSide(color: _orange),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
}

/// แถวนักเรียน 1 ราย: ข้อมูล + ป้ายสถานะติดตาม + ปุ่ม แก้ไข/เรียนต่อ/ไม่เรียนต่อ
class _LowBalanceRow extends StatelessWidget {
  final PackageModel p;
  final Color color;
  const _LowBalanceRow({required this.p, required this.color});

  static const _green = Color(0xFF2E7D32);
  static const _grey = Color(0xFF757575);
  static const _teal = Color(0xFF00897B);

  Future<void> _setStatus(BuildContext context, String? value) async {
    final messenger = ScaffoldMessenger.of(context);
    // กดป้ายเดิมซ้ำ = ยกเลิก (กลับเป็นยังไม่ระบุ)
    final next = (p.renewStatus == value) ? null : value;
    await FirestoreService.updatePackageFields(p.id, {'renewStatus': next});
    final msg = next == 'continue'
        ? 'ทำเครื่องหมาย "เรียนต่อ"'
        : next == 'stop'
            ? 'ทำเครื่องหมาย "ไม่เรียนต่อ"'
            : 'ล้างสถานะแล้ว';
    messenger.showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  Future<void> _toggleFollowed(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final next = !p.followedUp;
    await FirestoreService.updatePackageFields(p.id, {'followedUp': next});
    messenger.showSnackBar(SnackBar(
        content: Text(next ? 'ทำเครื่องหมาย "ติดตามแล้ว"' : 'ยกเลิก "ติดตามแล้ว"'),
        duration: const Duration(seconds: 1)));
  }

  @override
  Widget build(BuildContext context) {
    final st = p.renewStatus; // 'continue' / 'stop' / null
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.studentName.isEmpty ? '(ไม่มีชื่อ)' : p.studentName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                [
                  if (p.studentCode.isNotEmpty) p.studentCode,
                  if (p.teacherName.isNotEmpty) p.teacherName,
                ].join('  •  '),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          if (p.followedUp) ...[_followedChip(), const SizedBox(width: 6)],
          if (st != null) ...[_statusChip(st), const SizedBox(width: 6)],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
            child: Text('เหลือ ${p.remainingSessions}/${p.totalSessions}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 6),
        // ปุ่มจัดการ (Wrap กันล้นจอแคบ)
        Wrap(
          spacing: 6, runSpacing: 4,
          children: [
            _btn(
              icon: Icons.edit_outlined,
              label: 'แก้ไข',
              accent: const Color(0xFF1976D2),
              active: false,
              onTap: () => showPackageForm(context, existing: p),
            ),
            _btn(
              icon: Icons.check_circle_outline,
              label: 'เรียนต่อ',
              accent: _green,
              active: st == 'continue',
              onTap: () => _setStatus(context, 'continue'),
            ),
            _btn(
              icon: Icons.cancel_outlined,
              label: 'ไม่เรียนต่อ',
              accent: _grey,
              active: st == 'stop',
              onTap: () => _setStatus(context, 'stop'),
            ),
            _btn(
              icon: Icons.how_to_reg_outlined,
              label: 'ติดตามแล้ว',
              accent: _teal,
              active: p.followedUp,
              onTap: () => _toggleFollowed(context),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _statusChip(String st) {
    final isGo = st == 'continue';
    final c = isGo ? _green : _grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isGo ? Icons.check_circle : Icons.cancel, size: 13, color: c),
        const SizedBox(width: 3),
        Text(isGo ? 'เรียนต่อ' : 'ไม่เรียนต่อ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c)),
      ]),
    );
  }

  Widget _followedChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _teal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _teal.withValues(alpha: 0.5)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.how_to_reg, size: 13, color: _teal),
          SizedBox(width: 3),
          Text('ติดตามแล้ว',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _teal)),
        ]),
      );

  Widget _btn({
    required IconData icon,
    required String label,
    required Color accent,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? accent : accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: active ? Colors.white : accent),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : accent)),
          ]),
        ),
      ),
    );
  }
}
