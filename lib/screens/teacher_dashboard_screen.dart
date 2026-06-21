import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import 'packages_screen.dart';
import 'package_form_dialog.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final AppUser appUser;
  const TeacherDashboardScreen({super.key, required this.appUser});
  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  List<PackageModel> _packages = [];
  StreamSubscription<List<PackageModel>>? _sub;
  bool _isEn = false;

  @override
  void initState() {
    super.initState();
    _sub = FirestoreService.watchPackagesForUser(widget.appUser.uid, 'teacher')
        .listen((pkgs) => setState(() => _packages = pkgs));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _packages.where((p) => !p.isExpired).length;
    final done   = _packages.where((p) => p.isExpired).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appUser.name),
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'teacher_add_pkg',
        onPressed: () => showPackageForm(context),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_isEn ? 'Add Session' : 'เพิ่มคาบ'),
      ),
      body: Column(children: [
        // ── Stats banner ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFFFFF3E0),
          child: Row(children: [
            _StatTile(label: _isEn ? 'Total'  : 'ทั้งหมด',   value: '${_packages.length}', color: Colors.blueGrey),
            const SizedBox(width: 8),
            _StatTile(label: _isEn ? 'Active' : 'กำลังสอน', value: '$active', color: const Color(0xFFF97316)),
            const SizedBox(width: 8),
            _StatTile(label: _isEn ? 'Done'   : 'สอนเสร็จ', value: '$done',   color: Colors.green),
          ]),
        ),
        // ── Package list ─────────────────────────────────────────────
        Expanded(
          child: _packages.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 8),
                  Text(_isEn ? 'No packages yet' : 'ยังไม่มีคาบเรียน',
                      style: const TextStyle(color: Colors.grey)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                  itemCount: _packages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => PackageCard(
                    pkg: _packages[i],
                    onEdit: () => showPackageForm(context, existing: _packages[i]),
                    viewerRole: 'teacher',
                    isStudentView: false,
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
