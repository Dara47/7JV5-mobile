import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
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

  @override
  void initState() {
    super.initState();
    _sub = FirestoreService.watchPackagesForUser(widget.appUser.uid, 'student')
        .listen((pkgs) => setState(() => _packages = pkgs));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
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
          if (_packages.isEmpty)
            _emptyCard()
          else
            ..._packages.map((pkg) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CourseCard(pkg: pkg),
            )),
          _leaveShortcut(context),
          const SizedBox(height: 20),
        ],
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
              Text(pkg.scheduleLabel,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFF97316), fontWeight: FontWeight.w600)),
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
                onTap: () => html.window.open(link.trim(), '_blank'),
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
