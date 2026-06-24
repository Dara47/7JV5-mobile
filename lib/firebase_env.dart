// สลับ Firebase environment ระหว่าง prod กับ test ด้วย --dart-define
//
//   prod (ดีฟอลต์) → jenglishcenter-v4 (ข้อมูลจริง)
//   test           → engmobilev5      (ข้อมูลทดสอบ แยกขาดจากของจริง)
//
// build ทดสอบ:  flutter build web --dart-define=APP_ENV=test
// build/run ปกติ: ไม่ต้องใส่อะไร = prod เสมอ (ปลอดภัยไว้ก่อน)
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'firebase_options_test.dart';

const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'prod');

bool get isTestEnv => appEnv == 'test';

/// FirebaseOptions ตาม environment ปัจจุบัน
FirebaseOptions get firebaseOptionsForEnv =>
    isTestEnv ? TestFirebaseOptions.currentPlatform : DefaultFirebaseOptions.currentPlatform;
