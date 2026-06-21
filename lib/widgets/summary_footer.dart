import 'package:flutter/material.dart';
import '../models/models.dart';

class SummaryFooter extends StatelessWidget {
  final List<SessionModel> sessions;
  const SummaryFooter({super.key, required this.sessions});

  int get total => sessions.length;
  int get completed => sessions.where((s) => s.isCompleted).length;
  int get cancelled => sessions.where((s) => s.isCancelled).length;
  int get lateCount => sessions.where((s) => s.isLate).length;
  int get absentCount => sessions.where((s) => s.isAbsent).length;

  int get totalMinutes => sessions.where((s) => s.isCompleted)
      .fold(0, (sum, s) => sum + s.durationMinutes);

  String get totalHours {
    if (totalMinutes <= 0) return '0 ชม';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return m == 0 ? '$h ชม' : '$h ชม $m น';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1.5)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Row 1: main stats
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
          child: Row(children: [
            _Stat(icon: Icons.event_note, label: 'ทั้งหมด', value: '$total คาบ', color: const Color(0xFFF97316)),
            _divider(),
            _Stat(icon: Icons.check_circle_outline, label: 'เรียนแล้ว', value: '$completed คาบ', color: Colors.green),
            _divider(),
            _Stat(icon: Icons.access_time, label: 'รวมเวลา', value: totalHours, color: Colors.teal),
          ]),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
        // Row 2: discipline stats
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
          child: Row(children: [
            _Stat(icon: Icons.cancel_outlined, label: 'ยกเลิก', value: '$cancelled คาบ', color: Colors.red.shade400),
            _divider(),
            _Stat(icon: Icons.event_busy, label: 'ลา/ขาด', value: '$absentCount ครั้ง', color: Colors.red.shade700),
            _divider(),
            _Stat(icon: Icons.alarm_off, label: 'สาย', value: '$lateCount ครั้ง', color: Colors.orange),
          ]),
        ),
      ]),
    );
  }

  Widget _divider() => Container(height: 32, width: 1, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 4));
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]),
  );
}
