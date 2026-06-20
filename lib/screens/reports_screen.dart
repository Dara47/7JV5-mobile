import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import 'packages_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายงาน'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: () async {
              final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
                title: const Text('ออกจากระบบ'),
                content: const Text('ยืนยันออกจากระบบ?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ออก', style: TextStyle(color: Colors.red))),
                ],
              ));
              if (ok == true) FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<PackageModel>>(
        stream: FirestoreService.watchAllPackages(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];
          final expired = all.where((p) => p.isExpired).toList();
          final low = all.where((p) => p.isLowBalance).toList();
          final active = all.where((p) => p.isActive).toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Summary cards
              Row(children: [
                _SummaryCard(label: 'ใช้งานปกติ', value: '${active.length}', color: Colors.green),
                const SizedBox(width: 8),
                _SummaryCard(label: 'ใกล้หมดคาบ', value: '${low.length}', color: Colors.orange),
                const SizedBox(width: 8),
                _SummaryCard(label: 'หมดคาบ', value: '${expired.length}', color: Colors.red),
              ]),
              const SizedBox(height: 16),

              if (expired.isNotEmpty) ...[
                _SectionHeader(title: 'หมดคาบแล้ว (${expired.length})', color: Colors.red),
                const SizedBox(height: 8),
                ...expired.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PackageCard(pkg: p, onEdit: () {}, viewerRole: 'admin'),
                )),
                const SizedBox(height: 8),
              ],

              if (low.isNotEmpty) ...[
                _SectionHeader(title: 'ใกล้หมดคาบ (${low.length})', color: Colors.orange),
                const SizedBox(height: 8),
                ...low.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PackageCard(pkg: p, onEdit: () {}, viewerRole: 'admin'),
                )),
              ],

              if (expired.isEmpty && low.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                      SizedBox(height: 8),
                      Text('ทุกคาบเรียนอยู่ในเกณฑ์ดี', style: TextStyle(color: Colors.grey)),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(8)),
    child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
  );
}
