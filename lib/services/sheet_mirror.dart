import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// มิเรอร์ข้อมูล 7JEng V5 → Google Sheet (ทางเดียว, ผ่าน Apps Script Web App)
///
/// Firestore ยังเป็นฐานข้อมูลหลักเสมอ — Sheet เป็นเพียง "สำเนาสำรอง" ที่หน้าตาเหมือน
/// การ export Excel ของแต่ละหน้า เพื่อเผื่อวันที่แอปมีปัญหา แอดมินยังเปิด Sheet ดูข้อมูลได้
///
/// การยิงเป็นแบบ fire-and-forget: ถ้าเน็ตหลุด/Sheet ล่ม จะไม่บล็อกการบันทึกลง Firestore
/// (บันทึกลง Firestore สำเร็จก่อนเสมอ แล้วค่อยยิงสำเนาไป Sheet)
class SheetMirror {
  SheetMirror._();

  // Apps Script Web App (deploy: ดำเนินการในฐานะ = เจ้าของ, สิทธิ์ = ทุกคน)
  static const String _url =
      'https://script.google.com/macros/s/AKfycbxxvd1RU-gVDGRjQxWKY5ZAleo5pnKNhSSFfFxP0A6Kkx1OziMT5Vj4EoFUGMlV4kBF/exec';
  static const String _secret = '7jv5-sheet-mirror-kxR8';

  /// สวิตช์เปิด/ปิดการมิเรอร์ (เผื่ออยากปิดชั่วคราวโดยไม่ต้องรื้อโค้ด)
  static const bool enabled = true;

  static const String sheetTeacher = 'ค่าจ้างครู';
  static const String sheetAdmin = 'ค่าจ้างแอดมิน';

  // ── ตัวช่วยจัดรูปแบบให้เหมือน export Excel ─────────────────────────────────
  static String _num(double n) => n % 1 == 0 ? n.toInt().toString() : n.toString();

  static String _rolesStr(List<PayrollRole> roles) => roles
      .map((r) => '${r.role} ${_num(r.count)}×${_num(r.rate)}=${_num(r.total)}')
      .join(' | ');

  static String _dedsStr(List<PayrollDeduction> deds) =>
      deds.map((d) => '${d.label}=${_num(d.amount)}').join(' | ');

  static const List<String> _teacherHeaders = [
    'ชื่อครู', 'ตั้งแต่วันที่', 'ถึงวันที่', 'สัปดาห์/ช่วง', 'รายการค่าจ้าง',
    'จำนวนคาบ', 'รวมค่าจ้าง', 'รายการหักเงิน', 'หักเงิน', 'จ่ายสุทธิ', 'สถานะ', 'หมายเหตุ',
  ];

  static const List<String> _adminHeaders = [
    'ชื่อแอดมิน', 'ตั้งแต่วันที่', 'ถึงวันที่', 'สัปดาห์/ช่วง', 'รายการค่าจ้าง',
    'รวมค่าจ้าง', 'รายการหักเงิน', 'หักเงิน', 'จ่ายสุทธิ', 'สถานะ', 'หมายเหตุ',
  ];

  // ── ค่าจ้างครู ─────────────────────────────────────────────────────────────
  static Future<void> payrollTeacher(TeacherPayrollModel m) {
    final gross = m.totalAmount + m.totalDeductions;
    return _upsert(sheetTeacher, _teacherHeaders, m.id, [
      m.teacherName, m.dateFrom ?? '', m.dateTo ?? '', m.weekLabel ?? '',
      _rolesStr(m.roles), m.totalSessions, gross, _dedsStr(m.deductions),
      m.totalDeductions, m.totalAmount, m.isPaid ? 'จ่ายแล้ว' : 'รอจ่าย', m.note ?? '',
    ]);
  }

  static Future<void> deleteTeacher(String id) => _delete(sheetTeacher, id);

  // ── ค่าจ้างแอดมิน ───────────────────────────────────────────────────────────
  static Future<void> payrollAdmin(AdminPayrollModel m) {
    final gross = m.totalAmount + m.totalDeductions;
    return _upsert(sheetAdmin, _adminHeaders, m.id, [
      m.adminName, m.dateFrom ?? '', m.dateTo ?? '', m.weekLabel ?? '',
      _rolesStr(m.roles), gross, _dedsStr(m.deductions),
      m.totalDeductions, m.totalAmount, m.isPaid ? 'จ่ายแล้ว' : 'รอจ่าย', m.note ?? '',
    ]);
  }

  static Future<void> deleteAdmin(String id) => _delete(sheetAdmin, id);

  // ── ยิงจริง ────────────────────────────────────────────────────────────────
  static Future<void> _upsert(
          String sheet, List<String> headers, String id, List<dynamic> values) =>
      _send({
        'secret': _secret, 'sheet': sheet, 'action': 'upsert',
        'id': id, 'headers': headers, 'values': values,
      });

  static Future<void> _delete(String sheet, String id) =>
      _send({'secret': _secret, 'sheet': sheet, 'action': 'delete', 'id': id});

  static Future<void> _send(Map<String, dynamic> payload) async {
    if (!enabled) return;
    try {
      // text/plain = "simple request" → เลี่ยง CORS preflight บนเว็บ
      await http.post(
        Uri.parse(_url),
        headers: const {'Content-Type': 'text/plain;charset=utf-8'},
        body: jsonEncode(payload),
      );
    } catch (_) {
      // เงียบไว้ ไม่ให้กระทบการบันทึก (Firestore บันทึกสำเร็จไปแล้ว)
    }
  }
}
