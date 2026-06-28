import 'package:flutter/material.dart';
import '../utils/date_format.dart';

const _kOrange = Color(0xFFF97316);
const _kOrangeDeep = Color(0xFFFF8F00);

/// หน้า "คาบเรียนใกล้หมด" (สำหรับ admin) — เหลือเฉพาะฟังก์ชันคาบเรียนใกล้หมด
/// แตะแถว → เด้งป๊อปอัปรายชื่อนักเรียนที่ควรชวนต่อแพ็ก (reuse ของเดิม)
class AdminDashboardScreen extends StatelessWidget {
  final int lowBalanceCount;
  final VoidCallback onTapLowBalance;

  const AdminDashboardScreen({
    super.key,
    required this.lowBalanceCount,
    required this.onTapLowBalance,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        _banner(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
            children: [
              _Tile(
                icon: Icons.notifications_active_rounded,
                color: const Color(0xFFE53935),
                label: 'คาบเรียนใกล้หมด',
                sub: 'นักเรียนที่ควรชวนต่อแพ็ก',
                count: lowBalanceCount,
                onTap: onTapLowBalance,
              ),
            ],
          ),
        ),
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

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String sub;
  final int count;
  final VoidCallback onTap;
  const _Tile({
    required this.icon, required this.color, required this.label,
    required this.sub, required this.count, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasItems = count > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: hasItems ? 0.30 : 0.10)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 16, 14),
            child: Row(children: [
              // แถบสีซ้าย (accent ตามฟังก์ชัน)
              Container(
                width: 5, height: 44,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 12),
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ])),
              const SizedBox(width: 10),
              Container(
                constraints: const BoxConstraints(minWidth: 36),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: hasItems ? color : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold,
                      color: hasItems ? Colors.white : Colors.grey.shade500,
                    )),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ]),
          ),
        ),
      ),
    );
  }
}
