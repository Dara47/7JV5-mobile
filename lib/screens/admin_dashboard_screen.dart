import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/date_format.dart';
import '../widgets/low_balance_alert.dart';

const _kOrange = Color(0xFFF97316);
const _kOrangeDeep = Color(0xFFFF8F00);

/// หน้า "คาบเรียนใกล้หมด" (สำหรับ admin) — แสดงรายชื่อนักเรียนที่ควรชวนต่อแพ็กในหน้าเลย
class AdminDashboardScreen extends StatelessWidget {
  final List<PackageModel> lowBalance;

  const AdminDashboardScreen({
    super.key,
    required this.lowBalance,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        _banner(),
        Expanded(child: LowBalanceList(packages: lowBalance)),
      ]),
    );
  }

  /// แบนเนอร์ส้มแบรนด์ 7J (โทนเดียวกับเมนู/ปุ่ม Home)
  Widget _banner() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_kOrange, _kOrangeDeep],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x33F97316), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Row(children: [
            // โลโก้ 7J สี่เหลี่ยมมน (เหมือนหัวเมนู)
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              ),
              child: const Center(child: Text('7J',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('คาบเรียนใกล้หมด',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.event_rounded, size: 14, color: Colors.white70),
                const SizedBox(width: 5),
                Text(thaiDateFull(nowThai()),
                    style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ])),
          ]),
        ),
      ),
    );
  }
}
