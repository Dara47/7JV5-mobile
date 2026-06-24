// Firebase config ของ project ทดสอบ "EngMobileV5" (engmobilev5)
// ใช้เฉพาะตอน build ด้วย --dart-define=APP_ENV=test (เช่นที่ Vercel)
// แยกจาก production (jenglishcenter-v4) เพื่อให้ข้อมูลทดสอบไม่ปนของจริง
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class TestFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    // โหมดทดสอบใช้บนเว็บ (Vercel) เท่านั้น — มือถือ/เดสก์ท็อปให้ใช้ prod ตามปกติ
    throw UnsupportedError(
      'TestFirebaseOptions รองรับเฉพาะ web — '
      'อย่าใช้ APP_ENV=test กับ build android/ios',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAddc3X9JKbjBTXF_xLVBKJezY_54G2W4g',
    appId: '1:465340503229:web:08a57bf3145662f8e253d4',
    messagingSenderId: '465340503229',
    projectId: 'engmobilev5',
    authDomain: 'engmobilev5.firebaseapp.com',
    storageBucket: 'engmobilev5.firebasestorage.app',
    measurementId: 'G-P24MS2M5NS',
  );
}
