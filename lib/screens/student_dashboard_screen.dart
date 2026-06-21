import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import 'packages_screen.dart';
import 'package_form_dialog.dart';

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
    final active    = _packages.where((p) => !p.isExpired).length;
    final remaining = _packages.fold(0, (s, p) => s + p.remainingSessions);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appUser.name),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'student_add_pkg',
        onPressed: () => showPackageForm(context,
            preselectedStudentId: widget.appUser.uid),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มคาบ'),
      ),
      body: Column(children: [
        // ── Stats banner ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFFFF3E0),
          child: Row(children: [
            _StatTile(label: 'คอร์สทั้งหมด', value: '${_packages.length}', color: Colors.blueGrey),
            const SizedBox(width: 8),
            _StatTile(label: 'กำลังเรียน',   value: '$active',    color: const Color(0xFFF97316)),
            const SizedBox(width: 8),
            _StatTile(label: 'คาบคงเหลือ',   value: '$remaining', color: Colors.green),
          ]),
        ),
        // ── Package list ─────────────────────────────────────────────
        Expanded(
          child: _packages.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  const Text('ยังไม่มีคาบเรียน', style: TextStyle(color: Colors.grey)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                  itemCount: _packages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => PackageCard(
                    pkg: _packages[i],
                    onEdit: () => showPackageForm(context, existing: _packages[i]),
                    viewerRole: 'student',
                    isStudentView: true,
                    canEdit: true,
                  ),
                ),
        ),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.color});

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
