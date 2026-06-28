import 'package:flutter/material.dart';
import '../utils/date_format.dart';

/// หน้า "วันนี้" (ภาพรวมสำหรับ admin) — รวมตัวเลขสำคัญในจอเดียว
/// แตะแต่ละแถว → เด้งไปหน้า/ป๊อปอัปรายละเอียด (reuse ของเดิม ไม่อ่านข้อมูลซ้ำ)
class AdminDashboardScreen extends StatelessWidget {
  final int pendingCuts;
  final int pendingLeaves;
  final int lowBalanceCount;
  final int todayClasses;
  final VoidCallback onTapCuts;
  final VoidCallback onTapLeaves;
  final VoidCallback onTapLowBalance;
  final VoidCallback onTapToday;

  const AdminDashboardScreen({
    super.key,
    required this.pendingCuts,
    required this.pendingLeaves,
    required this.lowBalanceCount,
    required this.todayClasses,
    required this.onTapCuts,
    required this.onTapLeaves,
    required this.onTapLowBalance,
    required this.onTapToday,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          children: [
            // หัวข้อ + วันที่ไทย
            const Row(children: [
              Icon(Icons.dashboard_rounded, color: Color(0xFFF97316), size: 26),
              SizedBox(width: 10),
              Text('ภาพรวมวันนี้',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(thaiDateFull(nowThai()),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 20),

            _Tile(
              icon: Icons.content_cut,
              color: const Color(0xFF7E57C2),
              label: 'รอตัดคาบ',
              sub: 'คาบที่ถึงเวลาตัดแล้ว',
              count: pendingCuts,
              onTap: onTapCuts,
            ),
            _Tile(
              icon: Icons.event_busy,
              color: const Color(0xFFE65100),
              label: 'ใบลารออนุมัติ',
              sub: 'คำขอลาที่ยังไม่ได้ตัดสิน',
              count: pendingLeaves,
              onTap: onTapLeaves,
            ),
            _Tile(
              icon: Icons.notifications_active_rounded,
              color: const Color(0xFFE53935),
              label: 'คาบเรียนใกล้หมด',
              sub: 'นักเรียนที่ควรชวนต่อแพ็ก',
              count: lowBalanceCount,
              onTap: onTapLowBalance,
            ),
            _Tile(
              icon: Icons.calendar_month_rounded,
              color: const Color(0xFF1976D2),
              label: 'คาบเรียนวันนี้',
              sub: 'ดูปฏิทินคาบทั้งหมด',
              count: todayClasses,
              onTap: onTapToday,
            ),
          ],
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
        border: Border.all(color: color.withValues(alpha: hasItems ? 0.35 : 0.12)),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(children: [
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
              // ตัวเลขรวม (เด่นเมื่อมีรายการ)
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
