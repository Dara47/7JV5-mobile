#!/usr/bin/env bash
# สคริปต์ build Flutter web บน Vercel (Linux) — Vercel ไม่มี Flutter ติดมา จึงโคลนเอง
# pin เวอร์ชันให้ตรงกับเครื่อง dev (3.44.2) กันพฤติกรรมต่างกัน
set -euo pipefail

FLUTTER_VERSION="3.44.2"

if [ ! -d "_flutter" ]; then
  git clone https://github.com/flutter/flutter.git --branch "$FLUTTER_VERSION" --depth 1 _flutter
fi
export PATH="$PATH:$PWD/_flutter/bin"

# prod (lib/firebase_options.dart) เป็น local-only secret (ดู .gitignore) จึงไม่มีบน Vercel
# สร้าง stub ที่ชี้ไป test config เพื่อให้ compile ผ่าน — รันจริงโหมด test ใช้ TestFirebaseOptions อยู่แล้ว
# (กัน prod secret หลุดขึ้น git/Vercel)
if [ ! -f lib/firebase_options.dart ]; then
  cat > lib/firebase_options.dart <<'DART'
// AUTO-GENERATED บน Vercel — prod options เป็น local-only (ดู .gitignore)
// ชี้ไป test project เพื่อกัน prod secret หลุด; โหมด test รันด้วย TestFirebaseOptions อยู่แล้ว
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'firebase_options_test.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => TestFirebaseOptions.currentPlatform;
}
DART
fi

flutter --version
flutter config --enable-web
flutter pub get

# APP_ENV=test → ต่อ Firebase project ทดสอบ (engmobilev5) ไม่ใช่ของจริง
flutter build web --release --dart-define=APP_ENV=test
