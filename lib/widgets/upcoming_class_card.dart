import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// การ์ดเตือน "คาบเรียนถัดไป / กำลังเรียน" บนหน้า dashboard
class UpcomingClassCard extends StatelessWidget {
  final UpcomingClass info;
  final bool isTeacher;
  const UpcomingClassCard({super.key, required this.info, this.isTeacher = false});

  String _countdown(int mins) {
    if (mins <= 0) return '';
    if (mins < 60) return 'อีก $mins นาที';
    final h = mins ~/ 60, m = mins % 60;
    return m == 0 ? 'อีก $h ชม.' : 'อีก $h ชม. $m นาที';
  }

  @override
  Widget build(BuildContext context) {
    final s = info.slot;
    final timeRange = s.endTime.isNotEmpty ? '${s.startTime}–${s.endTime}' : s.startTime;
    final who = isTeacher ? info.pkg.studentName : info.pkg.teacherName;
    final whoLabel = isTeacher ? 'นักเรียน' : 'ครู';

    final bool soon = info.minutesUntil <= ClassReminderService.leadMinutes;
    final Color base = info.inProgress
        ? const Color(0xFF2E7D32)
        : (soon ? const Color(0xFFE53935) : const Color(0xFFF97316));
    final String headline = info.inProgress
        ? 'กำลังเรียนอยู่ตอนนี้'
        : 'คาบเรียนถัดไป • ${_countdown(info.minutesUntil)}';

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: base.withAlpha(70)),
          color: base.withAlpha(15),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: base.withAlpha(30), shape: BoxShape.circle),
            child: Icon(
              info.inProgress ? Icons.podcasts_rounded : Icons.notifications_active_rounded,
              color: base, size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(headline,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: base)),
              const SizedBox(height: 3),
              Text('$timeRange น. • $whoLabel $who',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            ]),
          ),
        ]),
      ),
    );
  }
}
