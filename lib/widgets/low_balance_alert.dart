import 'package:flutter/material.dart';
import '../models/models.dart';

/// คัดแพ็กเกจที่ยัง active และคาบ "หมดแล้ว (≤0)" หรือ "ใกล้หมด (1–3)"
/// เรียงเหลือน้อยสุดขึ้นก่อน
List<PackageModel> lowBalancePackages(List<PackageModel> all) {
  return all
      .where((p) => p.status == 'active' && (p.isExpired || p.isLowBalance))
      .toList()
    ..sort((a, b) => a.remainingSessions.compareTo(b.remainingSessions));
}

/// รายการ "คาบเรียนใกล้หมด" แบบฝังในหน้า (ไม่ใช่ป๊อปอัป) — แสดงข้อมูลอย่างเดียว copy ชื่อได้
/// แยกกลุ่ม 🔴 หมดแล้ว(≤0) / 🟠 ใกล้หมด(1–3) เรียงเหลือน้อยสุด
class LowBalanceList extends StatelessWidget {
  final List<PackageModel> packages;
  final EdgeInsets padding;
  const LowBalanceList({
    super.key,
    required this.packages,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 100),
  });

  static const _red = Color(0xFFE53935);
  static const _orange = Color(0xFFFB8C00);

  @override
  Widget build(BuildContext context) {
    final pkgs = lowBalancePackages(packages);
    if (pkgs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.check_circle_rounded, size: 56, color: Colors.green.shade300),
          const SizedBox(height: 12),
          Text('ไม่มีนักเรียนคาบใกล้หมด',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
        ]),
      );
    }
    final expired = pkgs.where((p) => p.isExpired).toList();
    final low = pkgs.where((p) => p.isLowBalance).toList();
    return SelectionArea(
      child: ListView(
        padding: padding,
        children: [
          if (expired.isNotEmpty) _group('🔴 หมดแล้ว', expired, _red),
          if (low.isNotEmpty) _group('🟠 ใกล้หมด (1–3 คาบ)', low, _orange),
        ],
      ),
    );
  }

  Widget _group(String title, List<PackageModel> items, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
            child: Text('$title (${items.length})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          ),
          ...items.map((p) => _row(p, color)),
        ],
      );

  Widget _row(PackageModel p, Color color) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
            child: Text('เหลือ ${p.remainingSessions}/${p.totalSessions}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ]),
      );
}
