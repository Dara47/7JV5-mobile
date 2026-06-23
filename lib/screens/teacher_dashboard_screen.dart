import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../widgets/upcoming_class_card.dart';
import 'packages_screen.dart';
import 'leave_request_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final AppUser appUser;
  const TeacherDashboardScreen({super.key, required this.appUser});
  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  List<PackageModel> _packages = [];
  StreamSubscription<List<PackageModel>>? _sub;
  Timer? _ticker;
  bool _isEn = false;

  @override
  void initState() {
    super.initState();
    ClassReminderService.ensurePermission();
    _sub = FirestoreService.watchPackagesForUser(widget.appUser.uid, 'teacher')
        .listen((pkgs) {
      setState(() => _packages = pkgs);
      ClassReminderService.checkAndNotify(pkgs, isTeacher: true);
    });
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ClassReminderService.checkAndNotify(_packages, isTeacher: true);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  String _t(String th, String en) => _isEn ? en : th;

  @override
  Widget build(BuildContext context) {
    final totalSessions = _packages.fold(0, (s, p) => s + p.totalSessions);
    final usedSessions  = _packages.fold(0, (s, p) => s + p.usedSessions);
    final remaining     = _packages.fold(0, (s, p) => s + p.remainingSessions);
    final next = ClassReminderService.nextToday(_packages);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_t('หน้าหลัก', 'Home')),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _isEn = !_isEn),
            icon: const Icon(Icons.translate, size: 16, color: Colors.white),
            label: Text(_isEn ? 'TH' : 'EN',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ── Profile card ─────────────────────────────────────────────
          _profileCard(),
          const SizedBox(height: 12),

          // ── การ์ดเตือนคาบเรียนถัดไป ──────────────────────────────────
          if (next != null) ...[
            UpcomingClassCard(info: next, isTeacher: true),
            const SizedBox(height: 12),
          ],

          // ── Stats row ────────────────────────────────────────────────
          Row(children: [
            _SummaryTile(label: _t('คาบรวม', 'Total'),    value: '$totalSessions', color: Colors.blueGrey),
            const SizedBox(width: 8),
            _SummaryTile(label: _t('สอนแล้ว', 'Taught'),  value: '$usedSessions',  color: Colors.green),
            const SizedBox(width: 8),
            _SummaryTile(label: _t('เหลือ', 'Left'),      value: '$remaining',      color: const Color(0xFFF97316)),
          ]),
          const SizedBox(height: 14),

          // ── Section header ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Row(children: [
              const Icon(Icons.people_rounded, size: 16, color: Color(0xFFF97316)),
              const SizedBox(width: 6),
              Text(_t('รายชื่อนักเรียนในความดูแล', 'My Students'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${_packages.length} ${_t('คน', 'students')}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFF97316), fontWeight: FontWeight.w600)),
              ),
            ]),
          ),

          // ── Student list ─────────────────────────────────────────────
          if (_packages.isEmpty)
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(_t('ยังไม่มีนักเรียน', 'No students yet'),
                      style: const TextStyle(color: Colors.grey)),
                ]),
              ),
            )
          else
            ..._packages.map((pkg) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _StudentCard(pkg: pkg, isEn: _isEn),
            )),

          // ── Leave shortcut ───────────────────────────────────────────
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
          child: const Icon(Icons.person_rounded, size: 32, color: Colors.white),
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
          Text(_t('นักเรียน', 'Students'),
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_t('ใบลา', 'Leave Request'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(_t('ยื่นใบลาหรือดูประวัติการลา', 'Submit or view leave history'),
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
      ),
    ),
  );
}

// ── Student card ──────────────────────────────────────────────────────────────

class _StudentCard extends StatelessWidget {
  final PackageModel pkg;
  final bool isEn;
  const _StudentCard({required this.pkg, required this.isEn});

  String _t(String th, String en) => isEn ? en : th;

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

          // ── Student info ─────────────────────────────────────────────
          Row(children: [
            const Icon(Icons.school_outlined, size: 16, color: Color(0xFFF97316)),
            const SizedBox(width: 6),
            Expanded(child: Text(pkg.studentName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            _Chip(code: pkg.studentCode, color: const Color(0xFFF97316)),
          ]),
          const SizedBox(height: 10),

          // ── Session stats ────────────────────────────────────────────
          Row(children: [
            _Box(label: _t('รวม', 'Total'),      value: '${pkg.totalSessions}',    color: Colors.blueGrey),
            const SizedBox(width: 6),
            _Box(label: _t('สอนแล้ว', 'Taught'), value: '${pkg.usedSessions}',    color: Colors.green),
            const SizedBox(width: 6),
            _Box(label: _t('เหลือ', 'Left'),     value: '${pkg.remainingSessions}', color: pkg.statusColor, bold: true),
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
            Text('${pkg.usedSessions}/${pkg.totalSessions} ${_t('คาบ', 'sessions')}',
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

          // ── Report button ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => PackageReportScreen(pkg: pkg))),
              icon: const Icon(Icons.bar_chart, size: 16),
              label: Text(_t('รายงานการสอน', 'Teaching Report')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blueGrey,
                side: BorderSide(color: Colors.blueGrey.shade200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Box extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _Box({required this.label, required this.value, required this.color, this.bold = false});

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

class _Chip extends StatelessWidget {
  final String code;
  final Color color;
  const _Chip({required this.code, required this.color});

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

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    ),
  );
}
