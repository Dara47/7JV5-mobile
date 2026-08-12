import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_env.dart';
import 'models/models.dart';
import 'services/firestore_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/app_watermark.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptionsForEnv);
    runApp(const JV5App());
  } catch (e) {
    // Firebase init ล้มเหลว (เน็ตหลุด/โดน firewall/เครื่องเก่า) — เดิมจะค้างหน้าโหลดจอขาวเงียบ ๆ
    // ตอนนี้วาดหน้า error ให้ผู้ใช้กด "ลองใหม่" ได้ (runApp ทำให้ flutter-first-frame ยิง → boot-loader หาย)
    runApp(StartupErrorApp(error: e.toString()));
  }
}

/// หน้าจอ error ตอนเปิดแอปไม่สำเร็จ (แทนจอขาว/ค้าง) — มีปุ่มลองใหม่
class StartupErrorApp extends StatelessWidget {
  final String error;
  const StartupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFFF7ED),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 64, color: Color(0xFFB91C1C)),
                const SizedBox(height: 16),
                const Text('เปิดแอปไม่สำเร็จ',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF7C2D12))),
                const SizedBox(height: 10),
                const Text(
                  'เชื่อมต่อระบบไม่ได้ อาจเป็นเพราะอินเทอร์เน็ตไม่เสถียร\nกรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่อีกครั้ง',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF9A3412)),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                  onPressed: () => main(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('ลองใหม่'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class JV5App extends StatelessWidget {
  const JV5App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '7J English',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF97316)),
        useMaterial3: true,
        fontFamily: 'Roboto',
        // โปร่งใส เพื่อให้ลายน้ำโลโก้ (AppWatermark) มองเห็นหลังทุกหน้า
        scaffoldBackgroundColor: Colors.transparent,
      ),
      // ลายน้ำโลโก้ครอบทั้งแอป — จุดเดียว ครบทุกเมนู
      // โหมดทดสอบ (APP_ENV=test) แปะป้าย "TEST" มุมขวาบน กันสับสนกับ production
      builder: (context, child) {
        Widget app = AppWatermark(child: child ?? const SizedBox.shrink());
        if (isTestEnv) {
          app = Banner(
            message: 'TEST',
            location: BannerLocation.topEnd,
            color: Colors.red.shade700,
            child: app,
          );
        }
        return app;
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          // เฉพาะผู้ใช้ที่ล็อกอินจริง (อีเมล=แอดมิน) เท่านั้นที่เข้าหน้าหลักจาก stream นี้
          // ผู้ใช้ anonymous (ครู/นักเรียนเข้าด้วยรหัส) จัดการเองผ่าน LoginScreen → push HomeScreen
          // กันบั๊ก "ไม่มี user doc = admin" ไม่ให้ anonymous หลุดเข้าหน้าแอดมิน
          if (snap.hasData && !snap.data!.isAnonymous) {
            return FutureBuilder<AppUser>(
              future: FirestoreService.getAppUser(snap.data!.uid, email: snap.data!.email ?? ''),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                return HomeScreen(appUser: userSnap.data!);
              },
            );
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
