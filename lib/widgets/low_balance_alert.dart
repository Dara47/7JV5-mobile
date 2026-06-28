import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../models/models.dart';
import '../utils/date_format.dart';

/// คีย์เก็บใน localStorage ว่ากด "ไม่ต้องเตือนวันนี้" ของวันไหนแล้ว
const _kDismissKey = 'lowBalanceDismissed';

/// คัดแพ็กเกจที่ยัง active และคาบ "หมดแล้ว (≤0)" หรือ "ใกล้หมด (1–3)"
/// เรียงเหลือน้อยสุดขึ้นก่อน
List<PackageModel> lowBalancePackages(List<PackageModel> all) {
  return all
      .where((p) => p.status == 'active' && (p.isExpired || p.isLowBalance))
      .toList()
    ..sort((a, b) => a.remainingSessions.compareTo(b.remainingSessions));
}

/// วันนี้กด "ไม่ต้องเตือนวันนี้" ไปแล้วหรือยัง (เก็บใน localStorage เบราว์เซอร์)
bool lowBalanceDismissedToday() {
  if (!kIsWeb) return false;
  try {
    return web.window.localStorage.getItem(_kDismissKey) == todayThaiStr();
  } catch (_) {
    return false;
  }
}

void _setDismissedToday() {
  if (!kIsWeb) return;
  try {
    web.window.localStorage.setItem(_kDismissKey, todayThaiStr());
  } catch (_) {/* localStorage ใช้ไม่ได้ — ข้าม */}
}

/// ป๊อปอัปเตือน "คาบเรียนใกล้หมด" (แสดงข้อมูลอย่างเดียว, copy ชื่อได้)
/// คืน Future ที่ complete เมื่อปิดป๊อปอัป — ไม่มีอะไรให้แสดงก็ไม่เปิด
Future<void> showLowBalanceAlert(BuildContext context, List<PackageModel> packages) {
  final pkgs = lowBalancePackages(packages);
  if (pkgs.isEmpty) return Future.value();
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _LowBalanceSheet(packages: pkgs),
  );
}

class _LowBalanceSheet extends StatefulWidget {
  final List<PackageModel> packages;
  const _LowBalanceSheet({required this.packages});
  @override
  State<_LowBalanceSheet> createState() => _LowBalanceSheetState();
}

class _LowBalanceSheetState extends State<_LowBalanceSheet> {
  static const _red = Color(0xFFE53935);
  static const _orange = Color(0xFFFB8C00);
  bool _dismiss = false;

  @override
  Widget build(BuildContext context) {
    final expired = widget.packages.where((p) => p.isExpired).toList();
    final low = widget.packages.where((p) => p.isLowBalance).toList();
    final maxH = MediaQuery.of(context).size.height * 0.8;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        ),
        // header + X
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [_red.withValues(alpha: 0.12), _orange.withValues(alpha: 0.04)],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 8, 10),
          child: Row(children: [
            const Icon(Icons.notifications_active_rounded, color: _red),
            const SizedBox(width: 10),
            const Expanded(child: Text('คาบเรียนใกล้หมด',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: Colors.grey),
            ),
          ]),
        ),
        const Divider(height: 1),
        // list (copy ชื่อได้ด้วย SelectionArea)
        Flexible(
          child: SelectionArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              children: [
                if (expired.isNotEmpty) _group('🔴 หมดแล้ว', expired, _red),
                if (low.isNotEmpty) _group('🟠 ใกล้หมด (1–3 คาบ)', low, _orange),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // footer: ไม่ต้องเตือนวันนี้ + ปิด
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 12, 8),
          child: Row(children: [
            Expanded(
              child: CheckboxListTile(
                value: _dismiss,
                onChanged: (v) => setState(() => _dismiss = v ?? false),
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('ไม่ต้องเตือนวันนี้', style: TextStyle(fontSize: 13)),
              ),
            ),
            TextButton(
              onPressed: () {
                if (_dismiss) _setDismissedToday();
                Navigator.pop(context);
              },
              child: const Text('ปิด'),
            ),
          ]),
        ),
      ]),
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
