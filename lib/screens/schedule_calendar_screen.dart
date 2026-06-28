import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../utils/date_format.dart';

const _kOrange = Color(0xFFF97316);
const _kGreen = Color(0xFF2E7D32);
const _kPurple = Color(0xFF6A1B9A);

const _thaiMonths = [
  '', 'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];
const _weekdayHeaders = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];
// คอลัมน์ index (0=อา) → weekday ของ DateTime (1=จ..7=อา)
const _dayAbbrWeekday = {'อา': 7, 'จ': 1, 'อ': 2, 'พ': 3, 'พฤ': 4, 'ศ': 5, 'ส': 6};

/// occurrence ของคาบเรียนในวันหนึ่ง (ฉายจากแพ็กเกจ + overlay สถานะ session จริง)
class _Occurrence {
  final PackageModel pkg;
  final SlotItem slot;
  final bool isSpecificDate; // true = วันที่เจาะจง, false = ตารางประจำสัปดาห์
  final String status; // 'planned'(ยังไม่ generate) | 'scheduled' | 'completed' | 'cancelled'
  _Occurrence(this.pkg, this.slot, this.isSpecificDate, this.status);
}

String _statusLabel(String s) {
  switch (s) {
    case 'completed': return 'เรียนแล้ว';
    case 'scheduled': return 'มีนัด';
    case 'cancelled': return 'ยกเลิก';
    default: return 'วางแผน';
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'completed': return const Color(0xFF2E7D32);
    case 'scheduled': return const Color(0xFF1976D2);
    case 'cancelled': return const Color(0xFFC62828);
    default: return const Color(0xFF9E9E9E);
  }
}

/// หน้าปฏิทินเต็ม (มี AppBar) — เปิดจากหน้าหลัก/ตารางสอน
class ScheduleCalendarScreen extends StatelessWidget {
  /// ถ้าระบุ → กรองเฉพาะครู/นักเรียนคนนั้น (ไม่ระบุ = admin เห็นทั้งหมด)
  final String? filterTeacherId;
  final String? filterStudentId;
  final String title;
  const ScheduleCalendarScreen({
    super.key,
    this.filterTeacherId,
    this.filterStudentId,
    this.title = 'ปฏิทินคาบเรียน',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _kOrange,
        foregroundColor: Colors.white,
      ),
      body: ScheduleCalendarBody(
        filterTeacherId: filterTeacherId,
        filterStudentId: filterStudentId,
      ),
    );
  }
}

/// เนื้อปฏิทิน (ไม่มี Scaffold/AppBar) — ใช้ฝังในหน้าอื่นได้ เช่น หน้าตัดคาบ
/// enableCut=true → แอดมินแตะคาบที่เลยเวลาแล้วเพื่อตัดคาบได้เลย
class ScheduleCalendarBody extends StatefulWidget {
  final String? filterTeacherId;
  final String? filterStudentId;
  final bool enableCut;
  const ScheduleCalendarBody({
    super.key,
    this.filterTeacherId,
    this.filterStudentId,
    this.enableCut = false,
  });

  @override
  State<ScheduleCalendarBody> createState() => _ScheduleCalendarBodyState();
}

class _ScheduleCalendarBodyState extends State<ScheduleCalendarBody> {
  late DateTime _visibleMonth; // วันที่ 1 ของเดือนที่แสดง
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = nowThai();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
  }

  Stream<List<PackageModel>> get _stream {
    if (widget.filterTeacherId != null) {
      return FirestoreService.watchPackagesForUser(widget.filterTeacherId!, 'teacher');
    }
    if (widget.filterStudentId != null) {
      return FirestoreService.watchPackagesForUser(widget.filterStudentId!, 'student');
    }
    return FirestoreService.watchAllPackages();
  }

  Stream<List<SessionModel>> get _sessionStream {
    if (widget.filterTeacherId != null) {
      return FirestoreService.watchSessionsForUser(widget.filterTeacherId!, 'teacher');
    }
    if (widget.filterStudentId != null) {
      return FirestoreService.watchSessionsForUser(widget.filterStudentId!, 'student');
    }
    return FirestoreService.watchAllSessions();
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);
    });
  }

  void _goToday() {
    final now = nowThai();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month, 1);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
  }

  /// เวลาสิ้นสุดของ slot บนวันที่ที่กำหนด (ใช้ endTime ถ้ามี ไม่งั้น startTime)
  DateTime _slotEndDateTime(DateTime date, SlotItem slot) {
    final ref = slot.endTime.isNotEmpty ? slot.endTime : slot.startTime;
    try {
      final p = ref.split(':');
      return DateTime(date.year, date.month, date.day, int.parse(p[0]), int.parse(p[1]));
    } catch (_) {
      return DateTime(date.year, date.month, date.day, 23, 59);
    }
  }

  /// คาบนี้กดตัดได้ไหม: เปิดโหมดตัด + ยังไม่ตัด/ไม่ยกเลิก + ยังมีโควตา + เลยเวลาสิ้นสุดแล้ว
  bool _canCut(DateTime date, _Occurrence o) {
    if (!widget.enableCut) return false;
    if (o.status == 'completed' || o.status == 'cancelled') return false;
    if (o.pkg.remainingSessions <= 0) return false;
    return !nowThai().isBefore(_slotEndDateTime(date, o.slot)); // now >= end
  }

  void _confirmCut(DateTime date, _Occurrence o) {
    final pkg = o.pkg;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ตัดคาบเรียน'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('นักเรียน: ${pkg.studentName}'),
          Text('ครู: ${pkg.teacherName}'),
          Text(thaiDateTimeFull(date, startTime: o.slot.startTime, endTime: o.slot.endTime)),
          const SizedBox(height: 8),
          Text('คงเหลือก่อนตัด ${pkg.remainingSessions} คาบ → จะเหลือ ${pkg.remainingSessions - 1} คาบ',
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService.cutSlot(pkg, o.slot, onDate: date);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('ตัดคาบ ${pkg.studentName} เรียบร้อย'),
                  backgroundColor: Colors.green,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _kPurple, foregroundColor: Colors.white),
            child: const Text('ยืนยันตัดคาบ'),
          ),
        ],
      ),
    );
  }

  /// ตัดคาบทั้งหมดของวันที่เลือก ในคลิกเดียว (เฉพาะคาบที่ตัดได้)
  void _confirmCutAllForDay(DateTime date, List<_Occurrence> cuttable) {
    if (cuttable.isEmpty) return;
    final items = cuttable.map((o) => PendingCut(o.pkg, o.slot)).toList();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ตัดคาบทั้งหมด'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ยืนยันตัดคาบทั้งหมด ${items.length} คาบ ของ${thaiDateFull(date)} ในคลิกเดียว?'),
          const SizedBox(height: 8),
          const Text('ระบบจะ:\n• บันทึกผลการเรียนทุกคาบ\n• หักโควตาคาบที่เหลือคาบละ 1',
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final n = await FirestoreService.cutAllSlots(items, onDate: date);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('ตัดคาบทั้งหมด $n คาบเรียบร้อย'),
                  backgroundColor: Colors.green,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _kPurple, foregroundColor: Colors.white),
            child: const Text('ยืนยันตัดทั้งหมด'),
          ),
        ],
      ),
    );
  }

  /// แผนที่ วันที่(1..n) → รายการ occurrence ในเดือนที่แสดง
  /// statusMap: '{packageId}_{YYYY-MM-DD}_{start}' → สถานะ session จริง (ถ้ามี)
  Map<int, List<_Occurrence>> _buildOccurrences(
      List<PackageModel> packages, Map<String, String> statusMap) {
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final map = <int, List<_Occurrence>>{};

    void add(int day, _Occurrence occ) {
      // โหมดตัดคาบ: ซ่อนคาบที่จัดการแล้ว (เรียนแล้ว/ยกเลิก) ให้เหลือเฉพาะที่ยังต้องตัด
      if (widget.enableCut && (occ.status == 'completed' || occ.status == 'cancelled')) return;
      map.putIfAbsent(day, () => []).add(occ);
    }

    String statusFor(String pkgId, int year, int month, int day, String start) {
      final ds = toStorageDateStr(DateTime(year, month, day));
      return statusMap['${pkgId}_${ds}_$start'] ?? 'planned';
    }

    for (final p in packages) {
      if (p.status != 'active') continue;
      for (final slot in p.effectiveSlots) {
        // วันที่เจาะจง
        if (slot.date != null && slot.date!.isNotEmpty) {
          final d = parseDateStr(slot.date!);
          if (d != null && d.year == year && d.month == month) {
            add(d.day, _Occurrence(p, slot, true, statusFor(p.id, year, month, d.day, slot.startTime)));
          }
          continue;
        }
        // ตารางประจำสัปดาห์
        final wd = _dayAbbrWeekday[slot.day];
        if (wd == null) continue;
        for (int day = 1; day <= daysInMonth; day++) {
          if (DateTime(year, month, day).weekday == wd) {
            add(day, _Occurrence(p, slot, false, statusFor(p.id, year, month, day, slot.startTime)));
          }
        }
      }
    }

    // เรียงแต่ละวันตามเวลาเริ่ม
    for (final list in map.values) {
      list.sort((a, b) => a.slot.startTime.compareTo(b.slot.startTime));
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PackageModel>>(
      stream: _stream,
      builder: (context, pkgSnap) {
        if (pkgSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final packages = pkgSnap.data ?? [];
        return StreamBuilder<List<SessionModel>>(
          stream: _sessionStream,
          builder: (context, sessSnap) {
            final sessions = sessSnap.data ?? [];
            // (packageId_date_start) → status ของ session จริง
            final statusMap = <String, String>{};
            for (final s in sessions) {
              statusMap['${s.packageId}_${s.date}_${s.startTime}'] = s.status;
            }
            final occ = _buildOccurrences(packages, statusMap);

            return Column(children: [
              _monthHeader(),
              _weekdayRow(),
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: _calendarGrid(occ),
              )),
              _dayDetail(occ),
            ]);
          },
        );
      },
    );
  }

  Widget _monthHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(children: [
        IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left)),
        Expanded(child: Center(child: Text(
          '${_thaiMonths[_visibleMonth.month]} ${_visibleMonth.year + 543}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _kOrange),
        ))),
        IconButton(onPressed: _goToday, icon: const Icon(Icons.today, size: 22), tooltip: 'วันนี้'),
        IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right)),
      ]),
    );
  }

  Widget _weekdayRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: List.generate(7, (i) {
        final isSun = i == 0;
        final isSat = i == 6;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(child: Text(
              _weekdayHeaders[i],
              style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold,
                color: isSun ? Colors.red.shade400 : isSat ? Colors.blue.shade400 : Colors.black54,
              ),
            )),
          ),
        );
      })),
    );
  }

  Widget _calendarGrid(Map<int, List<_Occurrence>> occ) {
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // คอลัมน์เริ่มของวันที่ 1 (อา=0): DateTime weekday 7(อา)→0 ... 6(ส)→6
    final firstWeekday = DateTime(year, month, 1).weekday; // 1..7
    final leadingBlanks = firstWeekday % 7; // อา(7)→0, จ(1)→1...

    final cells = <Widget>[];
    for (int i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox());
    }
    final now = nowThai();
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
      final isSelected = _selectedDay != null &&
          date.year == _selectedDay!.year && date.month == _selectedDay!.month && date.day == _selectedDay!.day;
      final dayOcc = occ[day] ?? const <_Occurrence>[];
      final isPast = date.isBefore(DateTime(now.year, now.month, now.day));
      // จุดเด่นเมื่อมีคาบรอตัดในวันนี้ (โหมดตัด)
      final hasCuttable = dayOcc.any((o) => _canCut(date, o));
      cells.add(_dayCell(date,
          isToday: isToday, isSelected: isSelected, count: dayOcc.length,
          isPast: isPast, hasCuttable: hasCuttable));
    }
    // เติมช่องท้ายให้ครบแถว
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox());
    }

    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 7) {
      rows.add(Row(children: cells.sublist(i, i + 7).map((c) => Expanded(child: c)).toList()));
    }
    return Column(children: rows);
  }

  Widget _dayCell(DateTime date,
      {required bool isToday, required bool isSelected, required int count,
      required bool isPast, required bool hasCuttable}) {
    final weekdayCol = date.weekday % 7; // 0=อา..6=ส
    final dateColor = weekdayCol == 0
        ? Colors.red.shade400
        : weekdayCol == 6
            ? Colors.blue.shade400
            : Colors.black87;
    return GestureDetector(
      onTap: () => setState(() => _selectedDay = date),
      child: Container(
        height: 52,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected
              ? _kOrange.withAlpha(28)
              : isToday
                  ? const Color(0xFFE8F5E9)
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? _kOrange
                : isToday
                    ? _kGreen
                    : Colors.grey.shade200,
            width: isSelected || isToday ? 1.5 : 1,
          ),
        ),
        child: Stack(children: [
          Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w500,
                color: isPast && !isToday ? dateColor.withAlpha(110) : dateColor,
              ),
            ),
            const SizedBox(height: 2),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isPast && !isToday ? Colors.grey.shade400 : _kOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$count',
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              )
            else
              const SizedBox(height: 14),
          ])),
          // จุดแดงมุมขวาบน = มีคาบรอตัดในวันนั้น (โหมดตัด)
          if (hasCuttable)
            Positioned(
              right: 4, top: 4,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: _kPurple, shape: BoxShape.circle),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _dayDetail(Map<int, List<_Occurrence>> occ) {
    final sel = _selectedDay;
    if (sel == null) return const SizedBox();
    final inVisibleMonth = sel.year == _visibleMonth.year && sel.month == _visibleMonth.month;
    final list = inVisibleMonth ? (occ[sel.day] ?? const []) : const <_Occurrence>[];
    final cuttable = list.where((o) => _canCut(sel, o)).toList();

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            const Icon(Icons.event_note, size: 18, color: _kOrange),
            const SizedBox(width: 8),
            Expanded(child: Text(
              thaiDateFull(sel),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: _kOrange.withAlpha(24), borderRadius: BorderRadius.circular(12)),
              child: Text('${list.length} คาบ',
                  style: const TextStyle(fontSize: 12, color: _kOrange, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        // ปุ่มตัดคาบทั้งหมดของวันนี้ (คลิกเดียว) — เฉพาะโหมดตัดและมีคาบที่ตัดได้
        if (widget.enableCut && cuttable.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirmCutAllForDay(sel, cuttable),
                icon: const Icon(Icons.done_all, size: 18),
                label: Text('ตัดคาบทั้งหมด (${cuttable.length} คาบ)',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        const Divider(height: 1),
        Flexible(
          child: list.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('ไม่มีคาบเรียนในวันนี้', style: TextStyle(color: Colors.grey))),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _occTile(sel, list[i]),
                ),
        ),
      ]),
    );
  }

  Widget _occTile(DateTime date, _Occurrence o) {
    final p = o.pkg;
    final time = '${o.slot.startTime}${o.slot.endTime.isNotEmpty ? '–${o.slot.endTime}' : ''}';
    final canCut = _canCut(date, o);

    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: canCut ? _kPurple.withAlpha(90) : Colors.grey.shade200),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: _kOrange.withAlpha(20), borderRadius: BorderRadius.circular(8)),
          child: Text(time, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _kOrange)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.school_outlined, size: 13, color: _kOrange),
            const SizedBox(width: 4),
            Expanded(child: Text('${p.studentName} (${p.studentCode})',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            if (p.isGroup)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: _kPurple.withAlpha(28),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.groups, size: 11, color: _kPurple),
                  SizedBox(width: 2),
                  Text('กลุ่ม', style: TextStyle(fontSize: 9, color: _kPurple, fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.person_outlined, size: 13, color: _kGreen),
            const SizedBox(width: 4),
            Expanded(child: Text('${p.teacherName} (${p.teacherCode})',
                style: const TextStyle(fontSize: 12, color: Colors.black54), overflow: TextOverflow.ellipsis)),
          ]),
        ])),
        const SizedBox(width: 6),
        canCut
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(color: _kPurple, borderRadius: BorderRadius.circular(8)),
                child: const Text('✂ ตัดคาบ',
                    style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
              )
            : Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor(o.status).withAlpha(28),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(o.status),
                    style: TextStyle(fontSize: 10, color: _statusColor(o.status), fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  o.isSpecificDate ? 'เจาะจง' : 'ประจำ',
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                ),
              ]),
      ]),
    );

    if (!canCut) return tile;
    return InkWell(
      onTap: () => _confirmCut(date, o),
      borderRadius: BorderRadius.circular(10),
      child: tile,
    );
  }
}
