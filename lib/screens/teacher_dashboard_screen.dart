import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import 'packages_screen.dart';

class TeacherDashboardScreen extends StatelessWidget {
  final AppUser appUser;
  const TeacherDashboardScreen({super.key, required this.appUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F4),
      appBar: AppBar(
        title: Text(appUser.name),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<PackageModel>>(
        stream: FirestoreService.watchPackagesForUser(appUser.uid, 'teacher'),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final packages = snap.data ?? [];
          final totalStudents  = packages.map((p) => p.studentId).toSet().length;
          final totalTaught    = packages.fold(0, (s, p) => s + p.usedSessions);
          final totalRemaining = packages.fold(0, (s, p) => s + p.remainingSessions);

          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            children: [

              // ── Teacher summary card ────────────────────────────
              _TeacherSummaryCard(
                appUser: appUser,
                totalStudents: totalStudents,
                totalTaught: totalTaught,
                totalRemaining: totalRemaining,
              ),
              const SizedBox(height: 18),

              if (packages.isEmpty)
                Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.group_outlined, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('ยังไม่มีนักเรียนในความดูแล',
                        style: TextStyle(color: Colors.grey, fontSize: 15)),
                  ]),
                ))
              else ...[
                Row(children: [
                  const Icon(Icons.groups_2_outlined, size: 18, color: Colors.black54),
                  const SizedBox(width: 6),
                  Text('นักเรียนในความดูแล (${packages.length} คาบ)',
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 14, color: Colors.black87)),
                ]),
                const SizedBox(height: 10),
                ...packages.map((pkg) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TeacherStudentCard(pkg: pkg, teacher: appUser),
                )),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Teacher summary header card ───────────────────────────────────────────────

class _TeacherSummaryCard extends StatelessWidget {
  final AppUser appUser;
  final int totalStudents;
  final int totalTaught;
  final int totalRemaining;

  const _TeacherSummaryCard({
    required this.appUser, required this.totalStudents,
    required this.totalTaught, required this.totalRemaining,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFF97316), Color(0xFFFB923C)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: const Color(0xFFF97316).withAlpha(80),
          blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(40),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(appUser.name,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(appUser.code,
              style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 13)),
        ]),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        _SummaryChip(label: 'นักเรียน',    value: '$totalStudents',  icon: Icons.people_outline),
        const SizedBox(width: 8),
        _SummaryChip(label: 'สอนแล้วรวม', value: '$totalTaught',    icon: Icons.check_circle_outline),
        const SizedBox(width: 8),
        _SummaryChip(label: 'เหลือรวม',   value: '$totalRemaining', icon: Icons.hourglass_bottom_outlined),
      ]),
    ]),
  );
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _SummaryChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Icon(icon, size: 18, color: Colors.white),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 10)),
      ]),
    ),
  );
}

// ── Student card (teacher view) ───────────────────────────────────────────────

class _TeacherStudentCard extends StatelessWidget {
  final PackageModel pkg;
  final AppUser teacher;
  const _TeacherStudentCard({required this.pkg, required this.teacher});

  String get _statusLabel {
    if (pkg.isCurrentlyInSession) return 'กำลังสอน';
    if (pkg.isExpired) return 'สอนเสร็จแล้ว';
    if (pkg.isLowBalance) return 'ใกล้เสร็จ';
    return 'รอสอน';
  }

  @override
  Widget build(BuildContext context) {
    final pct = pkg.totalSessions > 0
        ? (pkg.remainingSessions / pkg.totalSessions).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header: status + report ───────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: pkg.statusColor.withAlpha(18),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: pkg.statusColor, borderRadius: BorderRadius.circular(16)),
              child: Text(_statusLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => PackageReportScreen(pkg: pkg),
              )),
              icon: const Icon(Icons.bar_chart, size: 16),
              label: const Text('รายงาน', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueGrey,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
            ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Student + Teacher info ────────────────────────
            Row(children: [
              const Icon(Icons.person_outline, size: 16, color: Color(0xFFF97316)),
              const SizedBox(width: 6),
              Expanded(child: Text(pkg.studentName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              Text(pkg.studentCode,
                  style: const TextStyle(color: Color(0xFFF97316),
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.school_outlined, size: 15, color: Color(0xFF2E7D32)),
              const SizedBox(width: 6),
              Expanded(child: Text('ครู: ${teacher.name}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54))),
              Text(teacher.code,
                  style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12)),
            ]),
            const SizedBox(height: 10),

            // ── Schedule ──────────────────────────────────────
            if (pkg.scheduledDay != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 14, color: Color(0xFFF97316)),
                  const SizedBox(width: 6),
                  Text(pkg.scheduleLabel,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFF97316),
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            const SizedBox(height: 10),

            // ── Stats ─────────────────────────────────────────
            Row(children: [
              _MiniStat(label: 'รวมคาบ',   value: '${pkg.totalSessions}',    color: Colors.blueGrey),
              const SizedBox(width: 6),
              _MiniStat(label: 'สอนแล้ว',  value: '${pkg.usedSessions}',     color: Colors.green),
              const SizedBox(width: 6),
              _MiniStat(label: 'คงเหลือ',  value: '${pkg.remainingSessions}', color: pkg.statusColor, bold: true),
            ]),
            const SizedBox(height: 8),

            // ── Progress bar ──────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct, minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                color: pkg.statusColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'เหลือ = รวม − สอนแล้ว  (${pkg.totalSessions} − ${pkg.usedSessions} = ${pkg.remainingSessions})',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _MiniStat({required this.label, required this.value, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ]),
    ),
  );
}
