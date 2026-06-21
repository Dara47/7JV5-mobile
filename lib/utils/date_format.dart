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

String _pad(int n) => n.toString().padLeft(2, '0');

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

/// แปลง "2025-06-21" → DateTime
DateTime? parseDateStr(String s) {
  try { return DateTime.parse(s); } catch (_) { return null; }
}

/// แปลง DateTime เป็น "YYYY-MM-DD" สำหรับบันทึก Firestore
String toStorageDateStr(DateTime d) =>
    '${d.year}-${_pad(d.month)}-${_pad(d.day)}';
