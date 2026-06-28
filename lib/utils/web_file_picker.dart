// เลือกไฟล์บนเว็บโดยใช้ HTML <input type="file"> ตรงๆ ผ่าน package:web
// ใช้แทน file_picker 8.3.7 ที่ throw LateInitializationError บน release build (เว็บ)
import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

class PickedWebFile {
  final String name;
  final Uint8List bytes;
  PickedWebFile(this.name, this.bytes);
}

/// เปิดหน้าต่างเลือกไฟล์ของเบราว์เซอร์ แล้วคืนชื่อ+ไบต์ของไฟล์ที่เลือก
/// คืน null ถ้าผู้ใช้ยกเลิก/อ่านไฟล์ไม่ได้ (ไม่ค้างทุกกรณี)
/// [accept] เช่น 'image/*' หรือ '.csv,.json,.txt'
Future<PickedWebFile?> pickWebFile({String accept = ''}) {
  final completer = Completer<PickedWebFile?>();
  final input = web.HTMLInputElement();
  input.type = 'file';
  if (accept.isNotEmpty) input.accept = accept;
  input.style.display = 'none';
  // ผูกเข้า DOM เพื่อให้ .click() เปิด dialog ได้แน่นอนทุกเบราว์เซอร์
  web.document.body?.appendChild(input);

  // listener สำหรับ fallback ตอนโฟกัสกลับ — เก็บเป็นตัวแปรเดียวเพื่อ remove ได้
  late final JSFunction focusListener;

  void finish(PickedWebFile? file) {
    if (!completer.isCompleted) completer.complete(file);
    try {
      web.window.removeEventListener('focus', focusListener);
    } catch (_) {}
    try {
      input.remove();
    } catch (_) {}
  }

  // อ่านไฟล์ที่เลือก
  input.onchange = (web.Event _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      finish(null);
      return;
    }
    final file = files.item(0);
    if (file == null) {
      finish(null);
      return;
    }
    final reader = web.FileReader();
    reader.onload = (web.Event _) {
      try {
        final result = reader.result;
        if (result == null) {
          finish(null);
          return;
        }
        final bytes = (result as JSArrayBuffer).toDart.asUint8List();
        finish(PickedWebFile(file.name, bytes));
      } catch (_) {
        finish(null);
      }
    }.toJS;
    reader.onerror = ((web.Event _) => finish(null)).toJS;
    reader.readAsArrayBuffer(file);
  }.toJS;

  // กดยกเลิก dialog (Chrome/Edge ยิง event 'cancel')
  input.oncancel = ((web.Event _) => finish(null)).toJS;

  // Fallback: โฟกัสกลับมาที่หน้าต่างหลังปิด dialog — ถ้ายังไม่มีไฟล์ภายในเวลาสั้นๆ = ยกเลิก
  focusListener = ((web.Event _) {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!completer.isCompleted &&
          (input.files == null || input.files!.length == 0)) {
        finish(null);
      }
    });
  }).toJS;
  web.window.addEventListener('focus', focusListener);

  input.click();
  return completer.future;
}
