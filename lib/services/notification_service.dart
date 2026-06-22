import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import '../models/models.dart';
import '../utils/date_format.dart';

/// คาบที่ "กำลังเรียน" หรือ "กำลังจะถึง" ในวันนี้
class UpcomingClass {
  final PackageModel pkg;
  final SlotItem slot;
  final int minutesUntil; // นาทีจนถึงเวลาเริ่ม (>=0); 0 = ถึงแล้ว/กำลังเรียน
  final bool inProgress;  // อยู่ในช่วงเรียนตอนนี้
  const UpcomingClass(this.pkg, this.slot, this.minutesUntil, this.inProgress);
}

/// แจ้งเตือนก่อนเรียน — คำนวณคาบถัดไปวันนี้ + ยิง browser notification (เฉพาะเว็บ)
///
/// หมายเหตุ: เป็น best-effort ขณะแอปเปิดอยู่ (ไม่ใช่ push เมื่อปิดแอป — ต้องใช้ FCM)
class ClassReminderService {
  ClassReminderService._();

  /// เตือนล่วงหน้ากี่นาทีก่อนคาบเริ่ม
  static const int leadMinutes = 15;

  /// กันยิง notification ซ้ำ key: 'YYYY-MM-DD_packageId_startTime'
  static final Set<String> _notified = {};

  static const _dayMap = {'อา': 7, 'จ': 1, 'อ': 2, 'พ': 3, 'พฤ': 4, 'ศ': 5, 'ส': 6};

  /// นาทีเริ่มของ slot ถ้าเป็นของ "วันนี้" — ไม่งั้น null
  static int? _startMinToday(SlotItem s, DateTime now, String todayStr) {
    if (s.date != null && s.date!.isNotEmpty) {
      if (s.date != todayStr) return null;
    } else if (_dayMap[s.day] != now.weekday) {
      return null;
    }
    try {
      final sp = s.startTime.split(':');
      return int.parse(sp[0]) * 60 + int.parse(sp[1]);
    } catch (_) {
      return null;
    }
  }

  static int _endMin(SlotItem s, int fallback) {
    try {
      final ref = s.endTime.isNotEmpty ? s.endTime : s.startTime;
      final ep = ref.split(':');
      return int.parse(ep[0]) * 60 + int.parse(ep[1]);
    } catch (_) {
      return fallback;
    }
  }

  /// หาคาบ "กำลังเรียน" (priority) หรือ "ถัดไปวันนี้ที่ยังไม่เริ่ม" (เร็วสุด)
  static UpcomingClass? nextToday(List<PackageModel> packages) {
    final now = nowThai();
    final todayStr = todayThaiStr();
    final nowM = now.hour * 60 + now.minute;
    UpcomingClass? best;
    for (final p in packages) {
      if (p.status != 'active' || p.remainingSessions <= 0) continue;
      for (final s in p.effectiveSlots) {
        final startM = _startMinToday(s, now, todayStr);
        if (startM == null) continue;
        final endM = _endMin(s, startM);
        if (nowM >= startM && nowM < endM) {
          return UpcomingClass(p, s, 0, true); // กำลังเรียน
        }
        if (nowM < startM) {
          final mins = startM - nowM;
          if (best == null || mins < best.minutesUntil) {
            best = UpcomingClass(p, s, mins, false);
          }
        }
      }
    }
    return best;
  }

  /// ขอสิทธิ์แจ้งเตือนเบราว์เซอร์ (เว็บเท่านั้น) — เรียกตอนเข้า dashboard
  static void ensurePermission() {
    if (!kIsWeb) return;
    try {
      if (web.Notification.permission == 'default') {
        web.Notification.requestPermission();
      }
    } catch (_) {}
  }

  /// ตรวจคาบที่ใกล้ถึง (0 < mins <= leadMinutes) แล้วยิง browser notification
  /// กันซ้ำต่อคาบต่อวัน — เรียกซ้ำได้บ่อย (เช่นทุก 30 วินาที)
  static void checkAndNotify(List<PackageModel> packages, {required bool isTeacher}) {
    if (!kIsWeb) return;
    try {
      if (web.Notification.permission != 'granted') return;
    } catch (_) {
      return;
    }
    final now = nowThai();
    final todayStr = todayThaiStr();
    final nowM = now.hour * 60 + now.minute;
    for (final p in packages) {
      if (p.status != 'active' || p.remainingSessions <= 0) continue;
      for (final s in p.effectiveSlots) {
        final startM = _startMinToday(s, now, todayStr);
        if (startM == null) continue;
        final mins = startM - nowM;
        if (mins <= 0 || mins > leadMinutes) continue;
        final key = '${todayStr}_${p.id}_${s.startTime}';
        if (_notified.contains(key)) continue;
        _notified.add(key);
        final who = isTeacher ? p.studentName : p.teacherName;
        final endPart = s.endTime.isNotEmpty ? '–${s.endTime}' : '';
        final body = 'เริ่ม ${s.startTime}$endPart น. '
            '(${isTeacher ? 'นักเรียน' : 'ครู'} $who) • อีก $mins นาที';
        try {
          web.Notification(
            'ใกล้ถึงเวลาเรียน 📚',
            web.NotificationOptions(body: body, tag: key),
          );
        } catch (_) {}
      }
    }
  }
}
