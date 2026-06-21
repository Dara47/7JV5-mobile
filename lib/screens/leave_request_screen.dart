import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';

const _kColor = Color(0xFFE65100);

class LeaveRequestScreen extends StatelessWidget {
  final AppUser appUser;
  const LeaveRequestScreen({super.key, required this.appUser});

  @override
  Widget build(BuildContext context) {
    if (appUser.isAdmin) return const _AdminLeaveView();
    return _UserLeaveView(appUser: appUser);
  }
}

// ── Admin View ────────────────────────────────────────────────────────────────

class _AdminLeaveView extends StatefulWidget {
  const _AdminLeaveView();
  @override
  State<_AdminLeaveView> createState() => _AdminLeaveViewState();
}

class _AdminLeaveViewState extends State<_AdminLeaveView> {
  String _filter = 'pending';

  List<LeaveRequestModel> _filtered(List<LeaveRequestModel> all) {
    if (_filter == 'all') return all;
    return all.where((r) => r.status == _filter).toList();
  }

  void _confirmApprove(LeaveRequestModel r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('อนุมัติใบลา'),
        content: Text('อนุมัติใบลาของ ${r.userName} (${r.shortDate})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService.updateLeaveStatus(r.id, 'approved');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('อนุมัติแล้ว'), backgroundColor: Colors.green));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('อนุมัติ'),
          ),
        ],
      ),
    );
  }

  void _confirmReject(LeaveRequestModel r) {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ปฏิเสธใบลา'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ปฏิเสธใบลาของ ${r.userName} (${r.shortDate})?'),
          const SizedBox(height: 12),
          TextField(
            controller: noteCtrl,
            decoration: InputDecoration(
              hintText: 'หมายเหตุ (ไม่บังคับ)',
              filled: true, fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.all(10),
            ),
            maxLines: 2,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              final note = noteCtrl.text.trim();
              Navigator.pop(context);
              await FirestoreService.updateLeaveStatus(r.id, 'rejected', adminNote: note);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ปฏิเสธแล้ว'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('ปฏิเสธ'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(LeaveRequestModel r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบใบลา'),
        content: Text('ลบใบลาของ ${r.userName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService.deleteLeaveRequest(r.id);
            },
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ใบลา'),
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<LeaveRequestModel>>(
        stream: FirestoreService.watchLeaveRequests(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = snap.data ?? [];
          final pending = all.where((r) => r.isPending).length;
          final shown = _filtered(all);

          return Column(children: [
            // Filter chips
            Container(
              color: Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                _FilterChip(label: 'รอพิจารณา', count: all.where((r) => r.isPending).length,
                    selected: _filter == 'pending', color: Colors.orange,
                    onTap: () => setState(() => _filter = 'pending')),
                const SizedBox(width: 6),
                _FilterChip(label: 'อนุมัติ', count: all.where((r) => r.isApproved).length,
                    selected: _filter == 'approved', color: Colors.green,
                    onTap: () => setState(() => _filter = 'approved')),
                const SizedBox(width: 6),
                _FilterChip(label: 'ปฏิเสธ', count: all.where((r) => r.isRejected).length,
                    selected: _filter == 'rejected', color: Colors.red,
                    onTap: () => setState(() => _filter = 'rejected')),
                const SizedBox(width: 6),
                _FilterChip(label: 'ทั้งหมด', count: all.length,
                    selected: _filter == 'all', color: Colors.blueGrey,
                    onTap: () => setState(() => _filter = 'all')),
              ]),
            ),

            if (pending > 0 && _filter == 'pending')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Colors.orange.shade100,
                child: Text('มีใบลารอพิจารณา $pending รายการ',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
              ),

            Expanded(
              child: shown.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.event_busy_outlined, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 8),
                      const Text('ไม่มีใบลา', style: TextStyle(color: Colors.grey)),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _AdminLeaveCard(
                        leave: shown[i],
                        onApprove: () => _confirmApprove(shown[i]),
                        onReject: () => _confirmReject(shown[i]),
                        onDelete: () => _confirmDelete(shown[i]),
                      ),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _AdminLeaveCard extends StatelessWidget {
  final LeaveRequestModel leave;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDelete;
  const _AdminLeaveCard({required this.leave, required this.onApprove, required this.onReject, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final roleColor = leave.userRole == 'teacher' ? const Color(0xFF2E7D32) : const Color(0xFFB45309);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: roleColor.withAlpha(20), borderRadius: BorderRadius.circular(8), border: Border.all(color: roleColor.withAlpha(80))),
              child: Text(leave.roleLabel, style: TextStyle(fontSize: 11, color: roleColor, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('${leave.userName} (${leave.userCode})',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: leave.statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: leave.statusColor.withAlpha(80)),
              ),
              child: Text(leave.statusLabel,
                  style: TextStyle(fontSize: 11, color: leave.statusColor, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            InkWell(onTap: onDelete, child: const Icon(Icons.delete_outline, size: 18, color: Colors.grey)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text('วันลา: ${leave.shortDate}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.notes, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(child: Text('เหตุผล: ${leave.reason}', style: const TextStyle(fontSize: 13, color: Colors.black87))),
          ]),
          if (leave.adminNote != null && leave.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 14, color: Colors.blueGrey),
              const SizedBox(width: 4),
              Expanded(child: Text('หมายเหตุ admin: ${leave.adminNote}',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey))),
            ]),
          ],
          if (leave.isPending) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('ปฏิเสธ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('อนุมัติ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ── User View (teacher / student) ─────────────────────────────────────────────

class _UserLeaveView extends StatefulWidget {
  final AppUser appUser;
  const _UserLeaveView({required this.appUser});
  @override
  State<_UserLeaveView> createState() => _UserLeaveViewState();
}

class _UserLeaveViewState extends State<_UserLeaveView> {
  void _showSubmitForm() {
    String? selectedDate;
    final reasonCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          margin: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.event_busy_outlined, color: _kColor),
                  const SizedBox(width: 10),
                  const Text('ส่งใบลา', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ]),
                const Divider(),
                const SizedBox(height: 8),

                const Text('📅 วันที่ลา', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) {
                      setSheet(() => selectedDate = picked.toIso8601String().substring(0, 10));
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: selectedDate != null ? Colors.orange.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selectedDate != null ? Colors.orange.shade300 : Colors.grey.shade300),
                    ),
                    child: Text(
                      selectedDate != null
                          ? '${selectedDate!.substring(8)}/${selectedDate!.substring(5, 7)}/${selectedDate!.substring(0, 4)}'
                          : 'แตะเพื่อเลือกวันที่',
                      style: TextStyle(
                        fontSize: 15,
                        color: selectedDate != null ? Colors.orange.shade800 : Colors.grey,
                        fontWeight: selectedDate != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                const Text('📝 เหตุผล', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'ระบุเหตุผลการลา...',
                    filled: true, fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (selectedDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('กรุณาเลือกวันที่ลา')));
                        return;
                      }
                      if (reasonCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('กรุณาระบุเหตุผล')));
                        return;
                      }
                      Navigator.pop(ctx);
                      await FirestoreService.addLeaveRequest({
                        'userId': widget.appUser.uid,
                        'userName': widget.appUser.name,
                        'userCode': widget.appUser.code,
                        'userRole': widget.appUser.role,
                        'date': selectedDate,
                        'reason': reasonCtrl.text.trim(),
                        'status': 'pending',
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ส่งใบลาแล้ว'), backgroundColor: Colors.green));
                      }
                    },
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('ส่งใบลา', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kColor, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _confirmDelete(LeaveRequestModel r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ยกเลิกใบลา'),
        content: Text('ยกเลิกใบลาวันที่ ${r.shortDate}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ไม่')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService.deleteLeaveRequest(r.id);
            },
            child: const Text('ยกเลิกใบลา', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ใบลาของฉัน'),
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSubmitForm,
        backgroundColor: _kColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('ส่งใบลา'),
      ),
      body: StreamBuilder<List<LeaveRequestModel>>(
        stream: FirestoreService.watchMyLeaveRequests(widget.appUser.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final leaves = snap.data ?? [];
          if (leaves.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.event_available_outlined, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              const Text('ยังไม่มีใบลา', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              const Text('กด + ส่งใบลา เพื่อยื่นใบลา', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: leaves.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = leaves[i];
              return Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.calendar_today, size: 15, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('วันลา: ${r.shortDate}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: r.statusColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: r.statusColor.withAlpha(80)),
                        ),
                        child: Text(r.statusLabel,
                            style: TextStyle(fontSize: 11, color: r.statusColor, fontWeight: FontWeight.w600)),
                      ),
                      if (r.isPending) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _confirmDelete(r),
                          child: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 6),
                    Text('เหตุผล: ${r.reason}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    if (r.adminNote != null && r.adminNote!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('หมายเหตุ admin: ${r.adminNote}',
                          style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                    ],
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.count, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? color : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : Colors.grey.shade300),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600)),
        if (count > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withAlpha(80) : color.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: TextStyle(fontSize: 10, color: selected ? Colors.white : color, fontWeight: FontWeight.bold)),
          ),
        ],
      ]),
    ),
  );
}
