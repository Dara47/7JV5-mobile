import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/date_format.dart';
import 'firestore_service.dart';

/// key ของ Navigator/ScaffoldMessenger หลัก — ให้ IdleLogout เปิดกล่องเตือน
/// และเด้งกลับหน้าล็อกอินได้จากนอก widget tree (ไม่มี BuildContext ของตัวเอง)
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// ออกจากระบบอัตโนมัติเมื่อไม่มีการใช้งานครบเวลา (idle timeout)
///
/// **ใช้เฉพาะผู้ดูแลระบบ (admin)** — ครู/นักเรียนไม่โดนเตะออก (เริ่มนับที่ HomeScreen.initState
/// เฉพาะ isAdmin); ตัวดัก [IdleActivityDetector] ครอบทั้งแอปก็จริง แต่ [poke] ไม่ทำอะไรถ้ายังไม่ [start]
/// - เริ่มนับเมื่อแอดมินเข้า HomeScreen หยุดเมื่อออกจากหน้านั้น
/// - "มีการเคลื่อนไหว" = แตะจอ/เลื่อนจอ/ขยับเมาส์/สกรอลล์/พิมพ์คีย์บอร์ด (ดู [IdleActivityDetector])
/// - เตือนก่อนหมดเวลา [warnBefore] พร้อมปุ่ม "อยู่ต่อ" กันกำลังกรอกฟอร์มยาว ๆ แล้วโดนเตะออก
///
/// ทำไมเช็คด้วยการเทียบเวลาจริงทุก [_tick] แทนตั้ง Timer ยาว 10 นาทีรวดเดียว:
/// เบราว์เซอร์หน่วง timer ของแท็บที่ไม่ได้เปิดอยู่ (และมือถือหยุดเมื่อล็อกจอ)
/// timer ยาวจึงเพี้ยนได้ แต่การเทียบ timestamp ยังตรงเสมอ
class IdleLogout {
  /// ไม่ขยับครบเท่านี้ = ออกจากระบบ
  static const Duration timeout = Duration(minutes: 10);

  /// เตือนล่วงหน้าก่อนหมดเวลาเท่านี้ (นับถอยหลังในกล่องเตือน)
  static const Duration warnBefore = Duration(minutes: 1);

  static const Duration _tick = Duration(seconds: 20);

  static DateTime _lastActivity = nowThai();
  static Timer? _timer;
  static bool _warning = false;

  static bool get isRunning => _timer != null;

  /// เริ่มนับ — เรียกจาก HomeScreen.initState เฉพาะ admin
  static void start() {
    _lastActivity = nowThai();
    _warning = false;
    _timer?.cancel();
    _timer = Timer.periodic(_tick, (_) => checkNow());
  }

  /// หยุดนับ — เรียกจาก HomeScreen.dispose (ออกจากระบบ/ถูกเตะออกแล้ว)
  static void stop() {
    _timer?.cancel();
    _timer = null;
    _warning = false;
  }

  /// มีการเคลื่อนไหว — รีเซ็ตตัวนับ
  /// (ตอนกำลังเตือนอยู่ไม่รับ ต้องกด "อยู่ต่อ" เท่านั้น กันแตะโดนบังเอิญแล้วต่อเวลาให้เงียบ ๆ)
  static void poke() {
    if (_timer == null || _warning) return;
    _lastActivity = nowThai();
  }

  /// เช็คเดี๋ยวนี้ — ใช้ตอนกลับมาที่แอป (resume) ด้วย ไม่ต้องรอ tick ถัดไป
  static void checkNow() {
    if (_timer == null || _warning) return;
    final idle = nowThai().difference(_lastActivity);
    if (idle >= timeout) {
      forceLogout();
    } else if (idle >= timeout - warnBefore) {
      _showWarning();
    }
  }

  /// กล่องเตือน "กำลังจะออกจากระบบ" พร้อมนับถอยหลังถึงเวลาจริง
  static Future<void> _showWarning() async {
    final nav = appNavigatorKey.currentState;
    if (nav == null || _warning) return;
    _warning = true;
    final deadline = _lastActivity.add(timeout);
    // push DialogRoute ตรง ๆ กับ navigator key (showDialog ต้องใช้ context ที่มี Navigator เป็น ancestor
    // ซึ่ง context ของ navigator เองใช้ไม่ได้)
    final stay = await nav.push<bool>(DialogRoute<bool>(
      context: nav.context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _IdleWarningDialog(deadline: deadline),
    ));
    if (stay == true) {
      _warning = false;
      _lastActivity = nowThai();
    } else {
      _warning = false;
      await forceLogout();
    }
  }

  /// ออกจากระบบทันที + กลับหน้าล็อกอิน (ใช้ได้ทั้งแอดมิน(อีเมล) และครู/นักเรียน(รหัส))
  static Future<void> forceLogout() async {
    stop();
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {/* ไม่มี session อยู่แล้ว */}
    FirestoreService.currentUser = null;
    // แอดมิน(อีเมล): signOut ทำให้ StreamBuilder ใน main.dart สลับไป LoginScreen เอง
    // popUntil ตามไปเพื่อปิดกล่อง/ฟอร์มที่ค้างอยู่ด้านบนทั้งหมด (และเผื่อกรณีล็อกอินด้วยรหัส
    // ที่ HomeScreen ถูก push ทับ LoginScreen ถ้าอนาคตเปิดให้แอดมินเข้าด้วยรหัส)
    appNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    appMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('ออกจากระบบอัตโนมัติ — ไม่มีการใช้งานเกิน ${timeout.inMinutes} นาที'),
        backgroundColor: const Color(0xFF7C2D12),
        duration: const Duration(seconds: 6),
      ));
  }
}

/// ครอบทั้งแอปเพื่อดักการเคลื่อนไหวของผู้ใช้ (เสียบที่ MaterialApp.builder จุดเดียว)
class IdleActivityDetector extends StatefulWidget {
  final Widget child;
  const IdleActivityDetector({super.key, required this.child});

  @override
  State<IdleActivityDetector> createState() => _IdleActivityDetectorState();
}

class _IdleActivityDetectorState extends State<IdleActivityDetector> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ดักคีย์บอร์ดระดับแอป (พิมพ์ในฟอร์มก็นับว่าใช้งานอยู่ ไม่ใช่แค่แตะจอ)
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  bool _onKey(KeyEvent event) {
    IdleLogout.poke();
    return false; // ไม่กิน event ปล่อยให้ช่องกรอกทำงานตามปกติ
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // กลับมาที่แท็บ/ปลดล็อกจอ → เช็คทันที (ระหว่างที่ไม่ได้เปิดอยู่ timer ถูกเบราว์เซอร์หน่วง)
    if (state == AppLifecycleState.resumed) IdleLogout.checkNow();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => IdleLogout.poke(),
        onPointerMove: (_) => IdleLogout.poke(),
        onPointerHover: (_) => IdleLogout.poke(),
        onPointerSignal: (_) => IdleLogout.poke(),
        child: widget.child,
      );
}

/// กล่องเตือนก่อนออกจากระบบ — นับถอยหลังจาก [deadline] จริง (ไม่ใช่นับจำนวนครั้งของ timer)
class _IdleWarningDialog extends StatefulWidget {
  final DateTime deadline;
  const _IdleWarningDialog({required this.deadline});

  @override
  State<_IdleWarningDialog> createState() => _IdleWarningDialogState();
}

class _IdleWarningDialogState extends State<_IdleWarningDialog> {
  Timer? _ticker;
  int _left = 0;

  @override
  void initState() {
    super.initState();
    _left = _remaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _remaining();
      if (left <= 0) {
        _ticker?.cancel();
        if (mounted) Navigator.of(context).pop(false); // หมดเวลา = ออกจากระบบ
        return;
      }
      if (mounted) setState(() => _left = left);
    });
  }

  int _remaining() {
    final s = widget.deadline.difference(nowThai()).inSeconds;
    return s < 0 ? 0 : s;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false, // ปุ่มย้อนกลับ/ปัดปิดไม่ได้ ต้องเลือกเอง
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: const Icon(Icons.timer_outlined, size: 40, color: Color(0xFFE65100)),
          title: const Text('ไม่มีการใช้งาน'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ระบบจะออกจากระบบอัตโนมัติใน',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
              const SizedBox(height: 8),
              Text('$_left วินาที',
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800, color: Color(0xFFE65100))),
              const SizedBox(height: 10),
              Text('เพื่อความปลอดภัยของข้อมูล\nกด "อยู่ต่อ" เพื่อใช้งานต่อ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.5, color: Colors.grey.shade600)),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ออกจากระบบ', style: TextStyle(color: Colors.red)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('อยู่ต่อ'),
            ),
          ],
        ),
      );
}
