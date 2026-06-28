import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../utils/date_format.dart';
import '../utils/web_file_picker.dart';

enum _Mode { users, relations }

/// แถวที่ parse จากไฟล์ พร้อมสถานะตรวจสอบ
class _Row {
  final String title;
  final String subtitle;
  final Map<String, dynamic> data; // ข้อมูลที่จะเขียน (ถ้า valid)
  final String? error; // null = ผ่าน
  _Row({required this.title, required this.subtitle, required this.data, this.error});
  bool get valid => error == null;
}

const _dayAbbr = {'อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'};
const _dayFullToAbbr = {
  'อาทิตย์': 'อา', 'จันทร์': 'จ', 'อังคาร': 'อ', 'พุธ': 'พ',
  'พฤหัสบดี': 'พฤ', 'พฤหัส': 'พฤ', 'ศุกร์': 'ศ', 'เสาร์': 'ส',
};

class ImportUsersScreen extends StatefulWidget {
  const ImportUsersScreen({super.key});
  @override
  State<ImportUsersScreen> createState() => _ImportUsersScreenState();
}

class _ImportUsersScreenState extends State<ImportUsersScreen> {
  _Mode _mode = _Mode.users;
  List<_Row> _rows = [];
  String? _fileName;
  String? _parseError;
  bool _loading = false;
  bool _importing = false;

  int get _validCount => _rows.where((r) => r.valid).length;
  int get _invalidCount => _rows.where((r) => !r.valid).length;

  void _switchMode(_Mode m) {
    if (_mode == m) return;
    setState(() {
      _mode = m;
      _rows = [];
      _fileName = null;
      _parseError = null;
    });
  }

  Future<void> _pickFile() async {
    setState(() { _loading = true; _parseError = null; });
    try {
      final picked = await pickWebFile(accept: '.csv,.json,.txt,text/csv,application/json');
      if (picked == null) {
        setState(() => _loading = false);
        return;
      }
      var content = utf8.decode(picked.bytes, allowMalformed: true);
      if (content.isNotEmpty && content.codeUnitAt(0) == 0xFEFF) {
        content = content.substring(1); // ตัด BOM
      }
      final raw = _parseRaw(picked.name, content);
      final rows = _mode == _Mode.users ? await _validateUsers(raw) : await _validateRelations(raw);
      if (!mounted) return;
      setState(() { _fileName = picked.name; _rows = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _parseError = 'แปลงไฟล์ไม่สำเร็จ: $e'; _loading = false; });
    }
  }

  // ── การ parse แบบทั่วไป → list ของ map (คีย์ = header ตัวพิมพ์เล็ก) ──
  List<Map<String, String>> _parseRaw(String name, String content) {
    final isJson = name.toLowerCase().endsWith('.json') ||
        content.trimLeft().startsWith('[') || content.trimLeft().startsWith('{');
    if (isJson) {
      final decoded = jsonDecode(content);
      final list = decoded is List ? decoded : [decoded];
      return list.map<Map<String, String>>((item) {
        final m = item as Map;
        final out = <String, String>{};
        m.forEach((k, v) => out[k.toString().trim().toLowerCase()] = v?.toString() ?? '');
        return out;
      }).toList();
    }
    final lines = const LineSplitter().convert(content).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];
    final header = _splitCsvLine(lines.first).map((h) => h.trim().toLowerCase()).toList();
    return lines.skip(1).map((line) {
      final cols = _splitCsvLine(line);
      final out = <String, String>{};
      for (int i = 0; i < header.length; i++) {
        out[header[i]] = i < cols.length ? cols[i].trim() : '';
      }
      return out;
    }).toList();
  }

  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') { sb.write('"'); i++; }
          else { inQuotes = false; }
        } else { sb.write(c); }
      } else {
        if (c == '"') { inQuotes = true; }
        else if (c == ',') { result.add(sb.toString()); sb.clear(); }
        else { sb.write(c); }
      }
    }
    result.add(sb.toString());
    return result;
  }

  String _pick(Map<String, String> m, List<String> aliases) {
    for (final a in aliases) {
      final v = m[a];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  String? _normTime(String t) {
    final mt = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(t.trim());
    if (mt == null) return null;
    final h = int.parse(mt.group(1)!), mi = int.parse(mt.group(2)!);
    if (h > 23 || mi > 59) return null;
    return '${h.toString().padLeft(2, '0')}:${mt.group(2)}';
  }

  String _normDay(String d) {
    d = d.trim();
    if (_dayAbbr.contains(d)) return d;
    return _dayFullToAbbr[d] ?? '';
  }

  // ── โหมด USERS ──
  Future<List<_Row>> _validateUsers(List<Map<String, String>> raw) async {
    final existing = await FirestoreService.allUserCodes();
    final seen = <String>{};
    final out = <_Row>[];
    for (final m in raw) {
      final code = _pick(m, ['code', 'รหัส', 'รหัสผู้ใช้']).toUpperCase();
      final name = _pick(m, ['name', 'ชื่อ', 'ชื่อ-นามสกุล', 'ชื่อนามสกุล']);
      var role = _pick(m, ['role', 'ประเภท', 'ตำแหน่ง']).toLowerCase();
      if (role == 'นักเรียน' || role == 's' || role == 'student') {
        role = 'student';
      } else if (role == 'ครู' || role == 't' || role == 'teacher') {
        role = 'teacher';
      } else {
        role = '';
      }
      if (role.isEmpty && code.isNotEmpty) {
        if (code.startsWith('S')) {
          role = 'student';
        } else if (code.startsWith('T')) {
          role = 'teacher';
        }
      }

      String? err;
      if (code.isEmpty) {
        err = 'ไม่มีรหัส';
      } else if (!(code.startsWith('S') || code.startsWith('T')) ||
          code.length < 2 || int.tryParse(code.substring(1)) == null) {
        err = 'รูปแบบรหัสไม่ถูกต้อง (ต้อง S/T + ตัวเลข)';
      } else if (name.isEmpty) {
        err = 'ไม่มีชื่อ';
      } else if (role != 'student' && role != 'teacher') {
        err = 'ระบุประเภทไม่ได้';
      } else if ((role == 'student') != code.startsWith('S')) {
        err = 'รหัสกับประเภทไม่ตรงกัน';
      } else if (existing.contains(code)) {
        err = 'รหัสมีอยู่แล้วในระบบ';
      } else if (seen.contains(code)) {
        err = 'รหัสซ้ำในไฟล์';
      }
      if (err == null) seen.add(code);

      final data = <String, dynamic>{'code': code, 'name': name, 'role': role, 'status': 'active'};
      final age = int.tryParse(_pick(m, ['age', 'อายุ']));
      if (age != null) data['age'] = age;
      if (role == 'student') {
        final s = int.tryParse(_pick(m, ['sessions', 'defaultsessions', 'จำนวนคาบ', 'คาบ']));
        if (s != null) data['defaultSessions'] = s;
      } else if (role == 'teacher') {
        final meet = _pick(m, ['meet', 'googlemeetlink', 'link', 'ลิงก์']);
        if (meet.isNotEmpty) data['googleMeetLink'] = meet;
      }

      final roleLabel = role == 'student' ? 'นักเรียน' : role == 'teacher' ? 'ครู' : '-';
      out.add(_Row(
        title: code.isEmpty ? '(ไม่มีรหัส)' : code,
        subtitle: '${name.isEmpty ? "(ไม่มีชื่อ)" : name} · $roleLabel',
        data: err == null ? data : {}, error: err,
      ));
    }
    return out;
  }

  // ── โหมด RELATIONS (แพ็กเกจ) ──
  Future<List<_Row>> _validateRelations(List<Map<String, String>> raw) async {
    final users = await FirestoreService.userIndexByCode();
    final pkgMap = <String, Map<String, dynamic>>{};
    final order = <String>[];
    final errorRows = <_Row>[];

    for (final m in raw) {
      final sCode = _pick(m, ['studentcode', 'รหัสนักเรียน', 'student', 'นักเรียน', 'code']).toUpperCase();
      final tCode = _pick(m, ['teachercode', 'รหัสครู', 'teacher', 'ครู']).toUpperCase();
      final sessionsStr = _pick(m, ['sessions', 'totalsessions', 'total', 'จำนวนคาบ', 'คาบ']);
      final remainStr = _pick(m, ['remaining', 'remainingsessions', 'คงเหลือ']);
      final dayRaw = _pick(m, ['day', 'วัน']);
      final startRaw = _pick(m, ['start', 'starttime', 'เริ่ม', 'เวลาเริ่ม']);
      final endRaw = _pick(m, ['end', 'endtime', 'สิ้นสุด', 'เวลาสิ้นสุด']);
      final date = _pick(m, ['date', 'วันที่']);

      final s = users[sCode];
      final t = users[tCode];
      String? err;
      if (sCode.isEmpty || tCode.isEmpty) {
        err = 'ไม่มีรหัสนักเรียน/ครู';
      } else if (s == null) {
        err = 'ไม่พบนักเรียน $sCode (นำเข้า users ก่อน)';
      } else if (t == null) {
        err = 'ไม่พบครู $tCode';
      } else if (s.role != 'student') {
        err = '$sCode ไม่ใช่นักเรียน';
      } else if (t.role != 'teacher') {
        err = '$tCode ไม่ใช่ครู';
      }

      // ตาราง (ถ้ามี) — ตรวจรูปแบบ
      String day = '';
      String? start, end;
      final hasSchedule = dayRaw.isNotEmpty || startRaw.isNotEmpty || endRaw.isNotEmpty || date.isNotEmpty;
      if (err == null && hasSchedule) {
        if (dayRaw.isNotEmpty) {
          day = _normDay(dayRaw);
          if (day.isEmpty) err = 'วันไม่ถูกต้อง: $dayRaw';
        }
        if (err == null && startRaw.isNotEmpty) {
          start = _normTime(startRaw);
          if (start == null) err = 'เวลาเริ่มไม่ถูกต้อง: $startRaw';
        }
        if (err == null && endRaw.isNotEmpty) {
          end = _normTime(endRaw);
          if (end == null) err = 'เวลาสิ้นสุดไม่ถูกต้อง: $endRaw';
        }
        if (err == null && start == null) err = 'มีตารางแต่ไม่มีเวลาเริ่ม';
        if (err == null && day.isEmpty && date.isEmpty) err = 'มีเวลาแต่ไม่ระบุวัน/วันที่';
        // วันที่เจาะจง → เติม day ให้ตรงกับวันที่
        if (err == null && date.isNotEmpty && day.isEmpty) {
          day = thaiDayAbbrFromStr(date);
        }
      }

      if (err != null) {
        errorRows.add(_Row(title: '$sCode → $tCode', subtitle: '', data: {}, error: err));
        continue;
      }

      final key = '${sCode}_$tCode';
      if (!pkgMap.containsKey(key)) {
        order.add(key);
        final total = int.tryParse(sessionsStr) ?? 0;
        final remaining = int.tryParse(remainStr) ?? total;
        pkgMap[key] = {
          'studentId': s!.id, 'teacherId': t!.id,
          'studentName': s.name, 'teacherName': t.name,
          'studentCode': sCode, 'teacherCode': tCode,
          'totalSessions': total, 'remainingSessions': remaining,
          'status': 'active',
          '_slots': <Map<String, dynamic>>[],
        };
      } else {
        // แถวซ้ำคู่เดิม + มีจำนวนคาบ → อัปเดตถ้ายังเป็น 0
        final total = int.tryParse(sessionsStr);
        if (total != null && (pkgMap[key]!['totalSessions'] as int) == 0) {
          pkgMap[key]!['totalSessions'] = total;
          pkgMap[key]!['remainingSessions'] = int.tryParse(remainStr) ?? total;
        }
      }
      if (hasSchedule && start != null) {
        (pkgMap[key]!['_slots'] as List).add({
          'day': day, 'startTime': start, 'endTime': end ?? start,
          if (date.isNotEmpty) 'date': date,
        });
      }
    }

    final rows = <_Row>[];
    for (final key in order) {
      final p = pkgMap[key]!;
      final slots = (p.remove('_slots') as List).cast<Map<String, dynamic>>();
      if (slots.isNotEmpty) {
        p['slots'] = slots;
        final f = slots.first; // mirror slot แรก ให้ส่วนอื่นของแอปอ่านได้
        p['scheduledDay'] = f['day'];
        p['scheduledTime'] = f['startTime'];
        p['scheduledEndTime'] = f['endTime'];
        if (f['date'] != null) p['scheduledDate'] = f['date'];
      }
      final schedText = slots.isEmpty
          ? 'ไม่มีตาราง'
          : slots.map((sl) {
              final d = (sl['date'] != null && (sl['date'] as String).isNotEmpty)
                  ? thaiShortDateFromStr(sl['date'] as String) : (sl['day'] as String? ?? '');
              return '$d ${sl['startTime']}–${sl['endTime']}'.trim();
            }).join(' • ');
      rows.add(_Row(
        title: '${p['studentCode']} → ${p['teacherCode']}',
        subtitle: '${p['totalSessions']} คาบ · $schedText',
        data: p, error: null,
      ));
    }
    rows.addAll(errorRows);
    return rows;
  }

  Future<void> _import() async {
    final valid = _rows.where((r) => r.valid).map((r) => r.data).toList();
    if (valid.isEmpty) return;
    setState(() => _importing = true);
    try {
      if (_mode == _Mode.users) {
        await FirestoreService.bulkAddUsers(valid);
      } else {
        await FirestoreService.bulkAddPackages(valid);
      }
      if (!mounted) return;
      final label = _mode == _Mode.users ? 'ผู้ใช้' : 'ความสัมพันธ์';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('นำเข้า$label ${valid.length} รายการเรียบร้อย'),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUsers = _mode == _Mode.users;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        title: const Text('นำเข้าข้อมูล (Bulk Import)'),
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        // ── สลับโหมด ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(child: _modeBtn('ผู้ใช้ (ครู/นักเรียน)', Icons.people_outline, _Mode.users)),
              Expanded(child: _modeBtn('ความสัมพันธ์', Icons.link, _Mode.relations)),
            ]),
          ),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            _formatHint(isUsers),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _pickFile,
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file, color: Color(0xFF37474F)),
                label: Text(_fileName == null ? 'เลือกไฟล์ CSV / JSON' : 'เลือกไฟล์ใหม่',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF37474F))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF37474F)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.description_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text(_fileName!, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis)),
              ]),
            ],
            if (_parseError != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.error_outline, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(child: Text(_parseError!, style: const TextStyle(fontSize: 12, color: Colors.red))),
              ]),
            ],
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                _summaryChip('ถูกต้อง $_validCount', Colors.green),
                const SizedBox(width: 8),
                if (_invalidCount > 0) _summaryChip('ข้าม $_invalidCount', Colors.red),
              ]),
              const SizedBox(height: 10),
              ..._rows.map(_rowTile),
            ],
          ]),
        ),
        if (_validCount > 0)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 52, width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _importing ? null : _import,
                  icon: _importing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(_importing ? 'กำลังนำเข้า...' : 'นำเข้า $_validCount รายการ',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _modeBtn(String label, IconData icon, _Mode m) {
    final selected = _mode == m;
    return GestureDetector(
      onTap: () => _switchMode(m),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF37474F) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey.shade600),
          const SizedBox(width: 6),
          Flexible(child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.grey.shade600))),
        ]),
      ),
    );
  }

  Widget _formatHint(bool isUsers) {
    final example = isUsers
        ? 'code,name,role,age,sessions,meet\n'
            'S260001,สมชาย ใจดี,student,15,40,\n'
            'T260001,ครูเอ,teacher,,,https://meet.google.com/abc'
        : 'studentCode,teacherCode,sessions,day,start,end\n'
            'S260001,T260001,40,จ,16:00,17:00\n'
            'S260001,T260001,40,พ,16:00,17:00   (คู่เดิมหลายวัน = หลาย slot)';
    final desc = isUsers
        ? '• code (จำเป็น) — S…=นักเรียน, T…=ครู\n'
            '• name (จำเป็น) · role ไม่ใส่ก็เดาจากรหัส\n'
            '• age, sessions (นักเรียน), meet (ครู) — ไม่บังคับ'
        : '• studentCode + teacherCode (ต้องนำเข้า users ก่อน)\n'
            '• sessions = จำนวนคาบรวม\n'
            '• day (จ/อ/พ…) + start + end = ตาราง (ไม่บังคับ)\n'
            '• คู่เดิมหลายแถว = รวมเป็นแพ็กเกจเดียวหลายช่วงเวลา';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF1565C0)),
          const SizedBox(width: 8),
          Text(isUsers ? 'รูปแบบไฟล์ผู้ใช้' : 'รูปแบบไฟล์ความสัมพันธ์',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
        ]),
        const SizedBox(height: 8),
        Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Text(example, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54)),
        ),
      ]),
    );
  }

  Widget _summaryChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
  );

  Widget _rowTile(_Row r) {
    final color = r.valid ? Colors.green : Colors.red;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(r.valid ? Icons.check_circle : Icons.cancel, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (r.subtitle.isNotEmpty)
              Text(r.subtitle, style: const TextStyle(fontSize: 12, color: Colors.black87), overflow: TextOverflow.ellipsis),
            if (!r.valid)
              Text(r.error!, style: const TextStyle(fontSize: 11, color: Colors.red)),
          ]),
        ),
      ]),
    );
  }
}
