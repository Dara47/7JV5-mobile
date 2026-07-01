#!/usr/bin/env bash
# สคริปต์ build Flutter web บน Vercel (Linux) — Vercel ไม่มี Flutter ติดมา จึงโคลนเอง
# pin เวอร์ชันให้ตรงกับเครื่อง dev (3.44.2) กันพฤติกรรมต่างกัน
#
# รองรับ 2 โหมด ผ่าน Vercel Environment Variable ชื่อ APP_ENV (ตั้งต่อ project):
#   APP_ENV=test (ดีฟอลต์) → Firebase test (engmobilev5)      ← project 7-jv-5-mobile (ลองของ)
#   APP_ENV=prod           → Firebase prod (jenglishcenter-v4) ← project สำรอง (backup ข้อมูลจริง)
# โหมด prod ต้องตั้ง FB_* ใน Vercel Environment Variables (config prod เป็น local-only ไม่อยู่ใน git)
set -euo pipefail

FLUTTER_VERSION="3.44.2"
APP_ENV="${APP_ENV:-test}"

if [ ! -d "_flutter" ]; then
  git clone https://github.com/flutter/flutter.git --branch "$FLUTTER_VERSION" --depth 1 _flutter
fi
export PATH="$PATH:$PWD/_flutter/bin"

# lib/firebase_options.dart เป็น local-only secret (ดู .gitignore) จึงไม่มีบน Vercel → สร้างเอง
if [ ! -f lib/firebase_options.dart ]; then
  if [ "$APP_ENV" = "prod" ]; then
    # โหมด prod: สร้างจาก Vercel Environment Variables (ค่า Firebase web ของ prod)
    : "${FB_API_KEY:?ต้องตั้ง FB_API_KEY ใน Vercel Environment Variables สำหรับโหมด prod}"
    cat > lib/firebase_options.dart <<DART
// AUTO-GENERATED บน Vercel จาก Environment Variables (โหมด prod)
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '${FB_API_KEY}',
    appId: '${FB_APP_ID}',
    messagingSenderId: '${FB_MESSAGING_SENDER_ID}',
    projectId: '${FB_PROJECT_ID}',
    authDomain: '${FB_AUTH_DOMAIN}',
    storageBucket: '${FB_STORAGE_BUCKET}',
    measurementId: '${FB_MEASUREMENT_ID}',
  );
}
DART
  else
    # โหมด test: ชี้ไป test config (committed) — โหมด test รันด้วย TestFirebaseOptions อยู่แล้ว
    cat > lib/firebase_options.dart <<'DART'
// AUTO-GENERATED บน Vercel — ชี้ test project (กัน prod secret หลุด)
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'firebase_options_test.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => TestFirebaseOptions.currentPlatform;
}
DART
  fi
fi

flutter --version
flutter config --enable-web
flutter pub get

# --pwa-strategy=none : ไม่ register Service Worker (กันอาการมือถือค้าง cache เก่า — เหมือนฝั่ง Firebase)
if [ "$APP_ENV" = "prod" ]; then
  flutter build web --release --pwa-strategy=none
else
  flutter build web --release --pwa-strategy=none --dart-define=APP_ENV=test
fi
