import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// มิเรอร์ข้อมูล 7JEng V5 → Google Sheet (ทางเดียว, ผ่าน Apps Script Web App)
///
/// Firestore ยังเป็นฐานข้อมูลหลักเสมอ — Sheet เป็นเพียง "สำเนาสำรอง" หน้าตาเหมือนที่แสดงในแอป
/// เผื่อวันที่แอปมีปัญหา แอดมินยังเปิด Sheet ดูข้อมูลได้
///
/// ⚠️ ไม่รวม "บัญชีค่าจ้าง" (เงินเดือนอ่อนไหว — เก็บไว้ใน Firebase + ล็อกในแอปเท่านั้น)
///
/// การยิงเป็น fire-and-forget: ถ้าเน็ตหลุด/Sheet ล่ม จะไม่บล็อกการบันทึกลง Firestore
class SheetMirror {
  SheetMirror._();

  static const String _url =
      'https://script.google.com/macros/s/AKfycbxxvd1RU-gVDGRjQxWKY5ZAleo5pnKNhSSFfFxP0A6Kkx1OziMT5Vj4EoFUGMlV4kBF/exec';
  static const String _secret = '7jv5-sheet-mirror-kxR8';
  static const bool enabled = true;

  // ชื่อแท็บใน Sheet
  static const String tUsers = 'ผู้ใช้';
  static const String tPackages = 'แพ็กเกจ/ตารางเรียน';
  static const String tSessions = 'คาบเรียน';
  static const String tTeacherSlots = 'ตารางครู';
  static const String tLeaves = 'ใบลา';

  // ── หัวตาราง (คอลัมน์) แต่ละเมนู ────────────────────────────────────────────
  static const List<String> hUsers = [
    'รหัส', 'ชื่อ', 'บทบาท', 'สถานะ', 'อายุ', 'คาบเริ่มต้น', 'Google Meet',
  ];
  static const List<String> hPackages = [
    'นักเรียน', 'รหัสนักเรียน', 'ครู', 'รหัสครู', 'คาบทั้งหมด', 'คงเหลือ', 'เรียนแล้ว',
    'สถานะ', 'ตารางเรียน', 'ประเภท', 'ติดตามต่อ', 'หมายเหตุ',
  ];
  static const List<String> hSessions = [
    'วันที่', 'เริ่ม', 'สิ้นสุด', 'นักเรียน', 'รหัสนักเรียน', 'ครู', 'รหัสครู',
    'ภาษา', 'ทักษะ', 'สถานะ', 'มาสาย', 'ขาด', 'หมายเหตุ',
  ];
  static const List<String> hTeacherSlots = [
    'ครู', 'รหัสครู', 'ตารางสอน', 'หมายเหตุ',
  ];
  static const List<String> hLeaves = [
    'วันที่', 'ผู้ขอ', 'รหัส', 'บทบาท', 'เหตุผล', 'สถานะ',
    'ครูที่เกี่ยวข้อง', 'นักเรียนที่เกี่ยวข้อง', 'หมายเหตุแอดมิน',
  ];

  static String _role(String r) =>
      r == 'teacher' ? 'ครู' : r == 'admin' ? 'แอดมิน' : 'นักเรียน';

  // ── สร้างค่าแถวจาก model (ให้ตรงกับที่แสดงในแอป) ─────────────────────────────
  static List<dynamic> valuesUser(UserModel u) => [
        u.code, u.name, _role(u.role), u.isActive ? 'ใช้งาน' : 'ปิดใช้งาน',
        u.age ?? '', u.defaultSessions ?? '', u.googleMeetLink ?? '',
      ];

  static List<dynamic> valuesPackage(PackageModel p) => [
        p.studentName, p.studentCode, p.teacherName, p.teacherCode,
        p.totalSessions, p.remainingSessions, p.usedSessions, p.statusLabel,
        p.scheduleLabel, p.isGroup ? 'กลุ่ม' : 'เดี่ยว',
        p.renewStatus == 'continue' ? 'เรียนต่อ' : p.renewStatus == 'stop' ? 'ไม่เรียนต่อ' : '',
        p.notes ?? '',
      ];

  static List<dynamic> valuesSession(SessionModel s) => [
        s.date, s.startTime, s.endTime, s.studentName, s.studentCode ?? '',
        s.teacherName, s.teacherCode ?? '', s.language ?? '', s.skill ?? '',
        SessionModel.statusLabel(s.status), s.isLate ? 'สาย' : '', s.isAbsent ? 'ขาด' : '',
        s.notes ?? '',
      ];

  static List<dynamic> valuesTeacherSlot(TeacherSlotModel t) =>
      [t.teacherName, t.teacherCode, t.scheduleLabel, t.notes ?? ''];

  static List<dynamic> valuesLeave(LeaveRequestModel l) => [
        l.date, l.userName, l.userCode, _role(l.userRole), l.reason, l.statusLabel,
        l.teacherLabel, l.studentLabel, l.adminNote ?? '',
      ];

  // ── มิเรอร์รายตัว (ใช้ตอน add/update ในแอป) ─────────────────────────────────
  static Future<void> upsertUser(UserModel u) => _upsert(tUsers, hUsers, u.id, valuesUser(u));
  static Future<void> upsertPackage(PackageModel p) => _upsert(tPackages, hPackages, p.id, valuesPackage(p));
  static Future<void> upsertSession(SessionModel s) => _upsert(tSessions, hSessions, s.id, valuesSession(s));
  static Future<void> upsertTeacherSlot(TeacherSlotModel t) => _upsert(tTeacherSlots, hTeacherSlots, t.teacherId, valuesTeacherSlot(t));
  static Future<void> upsertLeave(LeaveRequestModel l) => _upsert(tLeaves, hLeaves, l.id, valuesLeave(l));

  static Future<void> delete(String sheet, String id) =>
      _send({'secret': _secret, 'sheet': sheet, 'action': 'delete', 'id': id});

  // ── มิเรอร์ทีละก้อน (ใช้ตอนซิงก์ทั้งหมด) ─────────────────────────────────────
  /// ส่งหลายแถวในครั้งเดียว (แบ่งก้อนละ 300 แถวกัน payload ใหญ่/ช้า)
  static Future<void> upsertMany(
      String sheet, List<String> headers, List<({String id, List<dynamic> values})> rows) async {
    if (!enabled || rows.isEmpty) return;
    const chunk = 300;
    for (var i = 0; i < rows.length; i += chunk) {
      final part = rows.sublist(i, i + chunk > rows.length ? rows.length : i + chunk);
      await _send({
        'secret': _secret, 'sheet': sheet, 'action': 'upsertMany', 'headers': headers,
        'rows': part.map((r) => {'id': r.id, 'values': r.values}).toList(),
      });
    }
  }

  // ── ยิงจริง ────────────────────────────────────────────────────────────────
  static Future<void> _upsert(
          String sheet, List<String> headers, String id, List<dynamic> values) =>
      _send({
        'secret': _secret, 'sheet': sheet, 'action': 'upsert',
        'id': id, 'headers': headers, 'values': values,
      });

  static Future<void> _send(Map<String, dynamic> payload) async {
    if (!enabled) return;
    try {
      await http.post(
        Uri.parse(_url),
        headers: const {'Content-Type': 'text/plain;charset=utf-8'},
        body: jsonEncode(payload),
      );
    } catch (_) {/* เงียบไว้ ไม่ให้กระทบการบันทึก */}
  }
}
