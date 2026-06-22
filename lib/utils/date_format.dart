// ── Thai date/time formatting utilities ──────────────────────────────────────

const _thaiDayFull = {
  1: 'จันทร์',
  2: 'อังคาร',
  3: 'พุธ',
  4: 'พฤหัสบดี',
  5: 'ศุกร์',
  6: 'เสาร์',
  7: 'อาทิตย์',
};

/// ตัวย่อวันไทยตรงกับที่ใช้ใน Firestore ('อา','จ','อ','พ','พฤ','ศ','ส')
const _thaiDayAbbr = {
  1: 'จ',
  2: 'อ',
  3: 'พ',
  4: 'พฤ',
  5: 'ศ',
  6: 'ส',
  7: 'อา',
};

String _pad(int n) => n.toString().padLeft(2, '0');

/// DateTime → ตัวย่อวันไทย เช่น อาทิตย์ → 'อา'
String thaiDayAbbr(DateTime d) => _thaiDayAbbr[d.weekday] ?? '';

/// "2025-06-21" → 'อา' (คืน '' ถ้าแปลงไม่ได้)
String thaiDayAbbrFromStr(String dateStr) {
  final d = parseDateStr(dateStr);
  return d != null ? thaiDayAbbr(d) : '';
}

/// "2025-06-21" → "21/06/2569" (สั้น ไม่มีชื่อวัน)
String thaiShortDateFromStr(String dateStr) {
  final d = parseDateStr(dateStr);
  if (d == null) return dateStr;
  return '${_pad(d.day)}/${_pad(d.month)}/${d.year + 543}';
}

/// "วันอาทิตย์ที่ 21/06/2569"
String thaiDateFull(DateTime d) {
  final dayName = _thaiDayFull[d.weekday] ?? '';
  final dd = _pad(d.day);
  final mm = _pad(d.month);
  final yyyy = d.year + 543;
  return 'วัน${dayName}ที่ $dd/$mm/$yyyy';
}

/// "วันอาทิตย์ที่ 21/06/2569 เวลา 09:00 - 09:40 น."
String thaiDateTimeFull(DateTime d, {String? startTime, String? endTime}) {
  final date = thaiDateFull(d);
  if (startTime == null) return date;
  final time = endTime != null ? '$startTime - $endTime น.' : '$startTime น.';
  return '$date เวลา $time';
}

/// แปลง "2025-06-21" → "วันอาทิตย์ที่ 21/06/2569"
String thaiDateFromStr(String dateStr) {
  final d = parseDateStr(dateStr);
  return d != null ? thaiDateFull(d) : dateStr;
}

/// แปลง "2025-06-21" → "วันอาทิตย์ที่ 21/06/2569 เวลา 09:00 - 09:40 น."
String thaiDateTimeFromStr(String dateStr, {String? startTime, String? endTime}) {
  final d = parseDateStr(dateStr);
  if (d == null) return dateStr;
  return thaiDateTimeFull(d, startTime: startTime, endTime: endTime);
}

/// แปลง "2025-06-21" → DateTime
DateTime? parseDateStr(String s) {
  try { return DateTime.parse(s); } catch (_) { return null; }
}

/// แปลง DateTime เป็น "YYYY-MM-DD" สำหรับบันทึก Firestore
String toStorageDateStr(DateTime d) =>
    '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
