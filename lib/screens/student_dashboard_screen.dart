import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../models/models.dart';
import '../services/firestore_service.dart';
import 'packages_screen.dart';

class StudentDashboardScreen extends StatelessWidget {
  final AppUser appUser;
  const StudentDashboardScreen({super.key, required this.appUser});

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
        stream: FirestoreService.watchPackagesForUser(appUser.uid, 'student'),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final packages = snap.data ?? [];
          if (packages.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text('ยังไม่มีคาบเรียน', style: TextStyle(color: Colors.grey, fontSize: 15)),
            ]));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
            itemCount: packages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _StudentPackageCard(pkg: packages[i], student: appUser),
          );
        },
      ),
    );
  }
}

// ── Student Package Card ──────────────────────────────────────────────────────

class _StudentPackageCard extends StatelessWidget {
  final PackageModel pkg;
  final AppUser student;
  const _StudentPackageCard({required this.pkg, required this.student});

  String get _statusLabel {
    if (pkg.isCurrentlyInSession) return 'กำลังเรียน';
    if (pkg.isExpired) return 'หมดคาบ';
    if (pkg.isLowBalance) return 'ใกล้หมด';
    return 'ใช้งานอยู่';
  }

  @override
  Widget build(BuildContext context) {
    final pct = pkg.totalSessions > 0
        ? (pkg.remainingSessions / pkg.totalSessions).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Status bar ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: pkg.statusColor.withAlpha(20),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: pkg.statusColor, borderRadius: BorderRadius.circular(20)),
              child: Text(_statusLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Profile rows ─────────────────────────────────────
            _InfoRow(icon: Icons.person_outline, label: student.name,
                code: student.code, iconColor: const Color(0xFFF97316)),
            const SizedBox(height: 6),
            _InfoRow(icon: Icons.school_outlined, label: pkg.teacherName,
                code: pkg.teacherCode, iconColor: const Color(0xFF2E7D32)),
            const SizedBox(height: 14),

            // ── Stats ────────────────────────────────────────────
            Row(children: [
              _StatBox(label: 'รวมคาบ',   value: '${pkg.totalSessions}',    color: Colors.blueGrey),
              const SizedBox(width: 8),
              _StatBox(label: 'เรียนแล้ว', value: '${pkg.usedSessions}',     color: Colors.green),
              const SizedBox(width: 8),
              _StatBox(label: 'คงเหลือ',  value: '${pkg.remainingSessions}', color: pkg.statusColor, bold: true),
            ]),
            const SizedBox(height: 10),

            // ── Progress bar ──────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct, minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: pkg.statusColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'เหลือ = รวม − เรียนแล้ว  (${pkg.totalSessions} − ${pkg.usedSessions} = ${pkg.remainingSessions})',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 12),

            // ── Schedule ─────────────────────────────────────────
            if (pkg.scheduledDay != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFFF97316)),
                  const SizedBox(width: 8),
                  Text(pkg.scheduleLabel,
                      style: const TextStyle(fontSize: 14, color: Color(0xFFF97316),
                          fontWeight: FontWeight.w700)),
                ]),
              ),

            // ── Google Meet link (real-time) ──────────────────────
            const SizedBox(height: 10),
            StreamBuilder<UserModel?>(
              stream: FirestoreService.watchUser(pkg.teacherId),
              builder: (context, snap) {
                final link = snap.data?.googleMeetLink;
                if (link == null || link.trim().isEmpty) return const SizedBox.shrink();
                return InkWell(
                  onTap: () => html.window.open(link.trim(), '_blank'),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)]),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(
                          color: const Color(0xFF1565C0).withAlpha(70),
                          blurRadius: 6, offset: const Offset(0, 3))],
                    ),
                    child: const Row(children: [
                      Icon(Icons.video_call_rounded, size: 22, color: Colors.white),
                      SizedBox(width: 10),
                      Text('เข้าเรียน Google Meet',
                          style: TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Spacer(),
                      Icon(Icons.open_in_new, size: 16, color: Colors.white70),
                    ]),
                  ),
                );
              },
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String code;
  final Color iconColor;
  const _InfoRow({required this.icon, required this.label, required this.code, required this.iconColor});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 16, color: iconColor),
    const SizedBox(width: 8),
    Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
    Text(code, style: TextStyle(fontSize: 13, color: iconColor, fontWeight: FontWeight.w700)),
  ]);
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;
  const _StatBox({required this.label, required this.value, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ]),
    ),
  );
}
