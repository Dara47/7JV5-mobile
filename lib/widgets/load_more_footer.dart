import 'package:flutter/material.dart';

/// แถวท้ายลิสต์: ปุ่ม "โหลดเพิ่ม" (ถ้ายังมีต่อ) หรือข้อความ "แสดงครบ N รายการ"
/// ใช้คู่กับการแสดงผลทีละหน้า (เริ่ม 20 กดเพิ่มทีละ 20) เพราะหน้ามีช่องค้นหาแล้ว
class LoadMoreFooter extends StatelessWidget {
  final bool hasMore;
  final int remaining;
  final int total;
  final VoidCallback onMore;
  final Color color;
  const LoadMoreFooter({
    super.key,
    required this.hasMore,
    required this.remaining,
    required this.total,
    required this.onMore,
    this.color = const Color(0xFFF97316),
  });

  @override
  Widget build(BuildContext context) {
    if (hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: OutlinedButton.icon(
            onPressed: onMore,
            icon: const Icon(Icons.expand_more, size: 18),
            label: Text('โหลดเพิ่ม (เหลืออีก $remaining)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(color: color),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text('แสดงครบ $total รายการ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ),
    );
  }
}
