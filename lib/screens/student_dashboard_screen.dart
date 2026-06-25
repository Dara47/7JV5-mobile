import 'dart:async';
import 'dart:convert';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../widgets/upcoming_class_card.dart';
import 'leave_request_screen.dart';
import 'schedule_calendar_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  final AppUser appUser;
  const StudentDashboardScreen({super.key, required this.appUser});
  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  List<PackageModel> _packages = [];
  StreamSubscription<List<PackageModel>>? _sub;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    ClassReminderService.ensurePermission();
    _sub = FirestoreService.watchPackagesForUser(widget.appUser.uid, 'student')
        .listen((pkgs) {
      setState(() => _packages = pkgs);
      ClassReminderService.checkAndNotify(pkgs, isTeacher: false);
    });
    // เดินนาฬิกาเพื่ออัปเดตเวลานับถอยหลัง + ยิงแจ้งเตือนเมื่อใกล้ถึงคาบ
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ClassReminderService.checkAndNotify(_packages, isTeacher: false);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = ClassReminderService.nextToday(_packages);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('หน้าหลัก'),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'ปฏิทินคาบเรียน',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ScheduleCalendarScreen(
                filterStudentId: widget.appUser.uid,
                title: 'ปฏิทินเรียนของฉัน',
              ),
            )),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _profileCard(),
          const SizedBox(height: 12),
          if (next != null) ...[
            UpcomingClassCard(info: next, isTeacher: false),
            const SizedBox(height: 12),
          ],
          if (_packages.isEmpty)
            _emptyCard()
          else
            ..._packages.map((pkg) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CourseCard(pkg: pkg),
            )),
          _leaveShortcut(context),
          const SizedBox(height: 12),
          _contactCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// การ์ดติดต่อ/ชำระเงิน — LINE + QR ธนาคาร + หมายเหตุ (จากหน้าตั้งค่า)
  Widget _contactCard() => StreamBuilder<Map<String, dynamic>>(
    stream: FirestoreService.watchSettings(),
    builder: (context, snap) {
      final data = snap.data ?? const {};
      final line = (data['lineLink'] ?? '') as String;
      final qr = (data['qrImageUrl'] ?? '') as String;
      final notes = (data['notes'] ?? '') as String;
      if (line.isEmpty && qr.isEmpty && notes.isEmpty) return const SizedBox.shrink();

      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.payments_outlined, size: 18, color: Color(0xFFF97316)),
              SizedBox(width: 8),
              Text('ติดต่อ / ชำระเงิน',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 12),

            if (line.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => web.window.open(line.trim(), '_blank'),
                  icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF00C300)),
                  label: const Text('เพิ่มเพื่อน / แชต LINE',
                      style: TextStyle(color: Color(0xFF00B900), fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00C300)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (qr.isNotEmpty) ...[
              Center(child: Text('สแกน QR เพื่อชำระเงิน',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: () => _showQrFull(context, qr),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _qrImage(qr, height: 240),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (notes.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(notes, style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ),
          ]),
        ),
      );
    },
  );

  /// แสดงรูป QR — รองรับทั้ง data URI (อัปโหลด) และ URL ปกติ
  Widget _qrImage(String value, {double height = 200}) {
    Widget errorBox() => Container(
          height: 100, alignment: Alignment.center,
          color: Colors.grey.shade100,
          child: const Text('โหลดภาพ QR ไม่ได้', style: TextStyle(fontSize: 12, color: Colors.grey)),
        );
    if (value.startsWith('data:')) {
      return Image.memory(base64Decode(value.substring(value.indexOf(',') + 1)),
          height: height, fit: BoxFit.contain, errorBuilder: (_, __, ___) => errorBox());
    }
    return Image.network(value, height: height, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => errorBox());
  }

  void _showQrFull(BuildContext context, String value) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('QR ชำระเงิน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _qrImage(value, height: 360),
            const SizedBox(height: 12),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('ปิด')),
          ]),
        ),
      ),
    );
  }

  Widget _profileCard() => Card(
    elevation: 3,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
            colors: [Color(0xFFF97316), Color(0xFFFF8F00)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white.withAlpha(50),
          child: const Icon(Icons.school_rounded, size: 32, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.appUser.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.badge_outlined, size: 14, color: Colors.white70),
            const SizedBox(width: 4),
            Text(widget.appUser.code,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_packages.length}',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const Text('คอร์สเรียน', style: TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      ]),
    ),
  );

  Widget _emptyCard() => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
        const SizedBox(height: 8),
        const Text('ยังไม่มีคาบเรียน', style: TextStyle(color: Colors.grey)),
      ]),
    ),
  );

  Widget _leaveShortcut(BuildContext context) => Card(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => LeaveRequestScreen(appUser: widget.appUser))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_busy_rounded, color: Colors.red, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ใบลา', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('ยื่นใบลาหรือดูประวัติการลา', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
      ),
    ),
  );
}

// ── Course card (one per package) ────────────────────────────────────────────

class _CourseCard extends StatelessWidget {
  final PackageModel pkg;
  const _CourseCard({required this.pkg});

  @override
  Widget build(BuildContext context) {
    final pct = pkg.totalSessions > 0
        ? (pkg.usedSessions / pkg.totalSessions).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Teacher row ──────────────────────────────────────────────
          Row(children: [
            const Icon(Icons.person_rounded, size: 16, color: Color(0xFF2E7D32)),
            const SizedBox(width: 6),
            Expanded(child: Text(pkg.teacherName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            _CodeChip(code: pkg.teacherCode, color: const Color(0xFF2E7D32)),
          ]),
          const SizedBox(height: 10),

          // ── Session stats ────────────────────────────────────────────
          Row(children: [
            _StatBox(label: 'รวม',      value: '${pkg.totalSessions}',    color: Colors.blueGrey),
            const SizedBox(width: 6),
            _StatBox(label: 'เรียนแล้ว', value: '${pkg.usedSessions}',    color: Colors.orange),
            const SizedBox(width: 6),
            _StatBox(label: 'เหลือ',    value: '${pkg.remainingSessions}', color: pkg.statusColor, bold: true),
          ]),
          const SizedBox(height: 8),

          // ── Progress ─────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct, minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: pkg.statusColor,
            ),
          ),
          const SizedBox(height: 3),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${pkg.usedSessions}/${pkg.totalSessions} คาบ',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text('${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11, color: pkg.statusColor, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),

          // ── Schedule ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 14, color: Color(0xFFF97316)),
              const SizedBox(width: 6),
              Expanded(child: Text(pkg.scheduleLabel,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFF97316), fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 10),

          // ── Google Meet ──────────────────────────────────────────────
          StreamBuilder<UserModel?>(
            stream: FirestoreService.watchUser(pkg.teacherId),
            builder: (context, snap) {
              final link = snap.data?.googleMeetLink;
              if (link == null || link.trim().isEmpty) return const SizedBox.shrink();
              return InkWell(
                onTap: () => web.window.open(link.trim(), '_blank'),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(
                        color: const Color(0xFF1565C0).withAlpha(60),
                        blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: const Row(children: [
                    Icon(Icons.video_call_rounded, size: 22, color: Colors.white),
                    SizedBox(width: 8),
                    Text('เข้าเรียน Google Meet',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    Spacer(),
                    Icon(Icons.open_in_new, size: 14, color: Colors.white70),
                  ]),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _StatBox({required this.label, required this.value, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 18,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    ),
  );
}

class _CodeChip extends StatelessWidget {
  final String code;
  final Color color;
  const _CodeChip({required this.code, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(code, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );
}
