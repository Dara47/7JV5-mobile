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
  await Firebase.initializeApp(options: firebaseOptionsForEnv);
  runApp(const JV5App());
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
          if (snap.hasData) {
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
