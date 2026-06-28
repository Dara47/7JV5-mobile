import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../utils/date_format.dart';
import 'user_form_screen.dart';
import 'packages_screen.dart';

class _StudentStatusBadge extends StatelessWidget {
  final String userId;
  final bool isActive;
  const _StudentStatusBadge({required this.userId, required this.isActive});

  @override
  Widget build(BuildContext context) {
    if (!isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        child: Text('หยุด', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      );
    }
    return StreamBuilder<List<PackageModel>>(
      stream: FirestoreService.watchPackagesForUser(userId, 'student'),
      builder: (context, snap) {
        final pkgs = snap.data ?? [];
        final hasExpired = pkgs.isNotEmpty && pkgs.any((p) => p.remainingSessions == 0);
        final isLow = !hasExpired && pkgs.any((p) => p.isLowBalance);

        if (hasExpired) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
            child: Text('หมดคาบ', style: TextStyle(fontSize: 11, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
          );
        }
        if (isLow) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
            child: Text('ใกล้หมด', style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
          );
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
          child: Text('ใช้งาน', style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
        );
      },
    );
  }
}

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});
  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openForm({UserModel? user}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => UserFormScreen(existing: user),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการผู้ใช้'),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'นักเรียน'), Tab(text: 'ครู')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_user',
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFFF97316),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('เพิ่มผู้ใช้'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'ค้นหาชื่อหรือรหัส...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchCtrl.clear())
                  : null,
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _UserList(role: 'student', search: _search, onEdit: _openForm),
              _UserList(role: 'teacher', search: _search, onEdit: _openForm),
            ],
          ),
        ),
      ]),
    );
  }
}

class _UserList extends StatefulWidget {
  final String role;
  final String search;
  final void Function({UserModel? user}) onEdit;
  const _UserList({required this.role, required this.search, required this.onEdit});

  @override
  State<_UserList> createState() => _UserListState();
}

class _UserListState extends State<_UserList> {
  static const _pageSize = 20;
  int _visible = _pageSize;

  // ── โหมดเลือกหลายคนเพื่อลบ ──
  bool _selectMode = false;
  final Set<String> _selected = {};

  @override
  void didUpdateWidget(covariant _UserList old) {
    super.didUpdateWidget(old);
    // เปลี่ยนคำค้น → เริ่มนับใหม่ที่ 20
    if (old.search != widget.search) {
      _visible = _pageSize;
    }
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _exitSelect() => setState(() {
    _selectMode = false;
    _selected.clear();
  });

  /// แถบเครื่องมือด้านบน — สลับระหว่างปุ่ม "เลือกเพื่อลบ" กับแถบเลือก/ลบ
  Widget _selectionBar(List<UserModel> filtered) {
    final label = widget.role == 'student' ? 'นักเรียน' : 'ครู';
    if (!_selectMode) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
          child: TextButton.icon(
            onPressed: () => setState(() { _selectMode = true; _selected.clear(); }),
            icon: const Icon(Icons.checklist_rtl, size: 18),
            label: const Text('เลือกเพื่อลบ'),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
          ),
        ),
      );
    }
    final allIds = filtered.map((u) => u.id).toSet();
    final allSelected = allIds.isNotEmpty && _selected.containsAll(allIds);
    return Container(
      color: Colors.red.shade50,
      padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
      child: Row(children: [
        Checkbox(
          value: allSelected,
          onChanged: (v) => setState(() {
            if (v == true) { _selected..clear()..addAll(allIds); }
            else { _selected.clear(); }
          }),
        ),
        Text('เลือก ${_selected.length}/${filtered.length} $label',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        TextButton(onPressed: _exitSelect, child: const Text('ยกเลิก')),
        const SizedBox(width: 4),
        ElevatedButton.icon(
          onPressed: _selected.isEmpty ? null : () => _confirmDeleteSelected(),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: Text('ลบ (${_selected.length})'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red, foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ]),
    );
  }

  /// ยืนยันลบรายการที่เลือก แล้วลบพร้อมความคืบหน้า + ปุ่มหยุด
  Future<void> _confirmDeleteSelected() async {
    final role = widget.role;
    final label = role == 'student' ? 'นักเรียน' : 'ครู';
    final ids = _selected.toList();
    final count = ids.length;
    if (count == 0) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text('ลบ$label ที่เลือก')),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('จะลบ$label ที่เลือกไว้ $count คน', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ข้อมูลที่จะถูกลบ (ของแต่ละคน):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
              SizedBox(height: 4),
              Text('• ข้อมูลผู้ใช้', style: TextStyle(fontSize: 12, color: Colors.black87)),
              Text('• แพ็กเกจทั้งหมด', style: TextStyle(fontSize: 12, color: Colors.black87)),
              Text('• คาบเรียนที่ยังไม่เสร็จ', style: TextStyle(fontSize: 12, color: Colors.black87)),
              SizedBox(height: 4),
              Text('* ประวัติรายงานยังคงอยู่', style: TextStyle(fontSize: 11, color: Colors.green, fontStyle: FontStyle.italic)),
              Text('* ลบแล้วกู้คืนไม่ได้', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('ยกเลิก')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dctx, true),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: Text('ลบ ($count)'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    // กล่องความคืบหน้า + ปุ่มหยุด
    final doneVN = ValueNotifier<int>(0);
    final cancelVN = ValueNotifier<bool>(false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 4),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            ValueListenableBuilder<int>(
              valueListenable: doneVN,
              builder: (_, d, __) => Text('กำลังลบ $d / $count คน…',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: cancelVN,
              builder: (_, c, __) => TextButton(
                onPressed: c ? null : () => cancelVN.value = true,
                child: Text(c ? 'กำลังหยุด…' : 'หยุด',
                    style: TextStyle(color: c ? Colors.grey : Colors.red, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );

    int deleted = 0;
    String? error;
    try {
      deleted = await FirestoreService.cascadeDeleteUsers(
        ids, role,
        onProgress: (d, t) => doneVN.value = d,
        isCancelled: () => cancelVN.value,
      );
    } catch (e) {
      error = e.toString();
    }
    doneVN.dispose();
    cancelVN.dispose();
    if (!mounted) return;
    Navigator.pop(context); // ปิดกล่องความคืบหน้า
    _exitSelect();
    final stopped = error == null && deleted < count;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error != null
          ? 'ลบล้มเหลว: $error'
          : stopped
              ? 'หยุดแล้ว — ลบไป $deleted จาก $count คน'
              : 'ลบ$label $deleted คนแล้ว'),
      backgroundColor: error != null ? Colors.red : (stopped ? Colors.orange : Colors.green),
    ));
  }

  void _confirmDelete(BuildContext context, UserModel u) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบผู้ใช้'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ลบ "${u.name}" (${u.code})?'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ข้อมูลที่จะถูกลบ:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
              SizedBox(height: 4),
              Text('• ข้อมูลผู้ใช้', style: TextStyle(fontSize: 12, color: Colors.black87)),
              Text('• แพ็กเกจทั้งหมด', style: TextStyle(fontSize: 12, color: Colors.black87)),
              Text('• คาบเรียนที่ยังไม่เสร็จ', style: TextStyle(fontSize: 12, color: Colors.black87)),
              SizedBox(height: 4),
              Text('* ประวัติรายงานยังคงอยู่', style: TextStyle(fontSize: 11, color: Colors.green, fontStyle: FontStyle.italic)),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService.cascadeDeleteUser(u.id, u.role);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('ลบทั้งหมด'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final search = widget.search;
    return StreamBuilder<List<UserModel>>(
      stream: FirestoreService.watchUsers(role: role),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('ข้อผิดพลาด: ${snap.error}'));
        }
        final all = snap.data ?? [];
        final filtered = search.isEmpty
            ? all
            : all.where((u) =>
                u.name.toLowerCase().contains(search) ||
                u.code.toLowerCase().contains(search)).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(role == 'student' ? Icons.school_outlined : Icons.person_outlined, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(search.isEmpty ? 'ยังไม่มี${role == "student" ? "นักเรียน" : "ครู"}' : 'ไม่พบผลการค้นหา',
                  style: const TextStyle(color: Colors.grey)),
            ]),
          );
        }

        // แสดงทีละ 20 รายการ (กดโหลดเพิ่มได้) — มีช่องค้นหาแล้วไม่ต้องโหลดทั้งหมด
        final visible = _visible.clamp(0, filtered.length);
        final shown = filtered.take(visible).toList();
        final hasMore = filtered.length > visible;

        return Column(children: [
          _selectionBar(filtered),
          Expanded(child: StreamBuilder<List<SessionModel>>(
          stream: role == 'student' ? FirestoreService.watchTodaySessions() : null,
          builder: (context, sessSnap) {
            final todaySessions = sessSnap.data ?? const <SessionModel>[];
            return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          itemCount: shown.length + 1, // +1 = แถวท้าย (ปุ่มโหลดเพิ่ม / สรุปจำนวน)
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            // แถวท้ายสุด
            if (i == shown.length) {
              if (hasMore) {
                final remaining = filtered.length - visible;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _visible += _pageSize),
                      icon: const Icon(Icons.expand_more, size: 18),
                      label: Text('โหลดเพิ่ม (เหลืออีก $remaining)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF97316),
                        side: const BorderSide(color: Color(0xFFF97316)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(child: Text('แสดงครบ ${filtered.length} รายการ',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
              );
            }
            final u = shown[i];
            final color = role == 'student' ? const Color(0xFFF97316) : const Color(0xFF2E7D32);
            final isSel = _selected.contains(u.id);
            return Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isSel ? const BorderSide(color: Colors.red, width: 1.5) : BorderSide.none,
              ),
              color: isSel ? Colors.red.shade50 : null,
              elevation: 1,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_selectMode)
                      Checkbox(
                        value: isSel,
                        onChanged: (_) => _toggleSelect(u.id),
                        activeColor: Colors.red,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )
                    else ...[
                      // เลขลำดับ (เรียงตามผลค้นหา)
                      SizedBox(
                        width: 24,
                        child: Text('${i + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    CircleAvatar(
                      backgroundColor: color,
                      radius: 22,
                      child: Text(
                        u.name.isNotEmpty ? u.name[0] : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ]),
                  title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Row(children: [
                    Text(u.code, style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 13)),
                    if (u.age != null) ...[
                      const SizedBox(width: 8),
                      Text('อายุ ${u.age} ปี', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    role == 'student'
                      ? _StudentStatusBadge(userId: u.id, isActive: u.isActive)
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: u.isActive ? Colors.green.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(u.isActive ? 'ใช้งาน' : 'หยุด',
                              style: TextStyle(fontSize: 11, color: u.isActive ? Colors.green.shade700 : Colors.grey)),
                        ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                      onSelected: (v) {
                        if (v == 'edit') widget.onEdit(user: u);
                        if (v == 'detail') Navigator.push(context, MaterialPageRoute(
                            builder: (_) => role == 'student'
                                ? PackagesScreen(filterStudentId: u.id, filterStudentName: u.name)
                                : PackagesScreen(filterTeacherId: u.id, filterTeacherName: u.name)));
                        if (v == 'delete') _confirmDelete(context, u);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'detail', child: Row(children: [Icon(Icons.visibility_outlined, size: 18), SizedBox(width: 8), Text('ดูรายละเอียด')])),
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('แก้ไข')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('ลบ', style: TextStyle(color: Colors.red))])),
                      ],
                    ),
                  ]),
                  onTap: _selectMode
                      ? () => _toggleSelect(u.id)
                      : () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => role == 'student'
                              ? PackagesScreen(filterStudentId: u.id, filterStudentName: u.name)
                              : PackagesScreen(filterTeacherId: u.id, filterTeacherName: u.name))),
                ),
                if (role == 'student')
                  StreamBuilder<List<PackageModel>>(
                    stream: FirestoreService.watchPackagesForUser(u.id, 'student'),
                    builder: (ctx, pkgSnap) {
                      final pkgs = pkgSnap.data ?? [];
                      if (pkgs.isEmpty && u.totalAdded == 0 && u.totalRemoved == 0) return const SizedBox.shrink();

                      final total = pkgs.fold(0, (s, p) => s + p.totalSessions);
                      final used = pkgs.fold(0, (s, p) => s + p.usedSessions);
                      final remaining = pkgs.fold(0, (s, p) => s + p.remainingSessions);
                      final hasAdj = u.totalAdded > 0 || u.totalRemoved > 0;

                      // ── คำนวณสถานะการเรียน (รองรับหลาย slot ต่อแพ็กเกจ) ──
                      final now = nowThai();
                      const dayMap = {'อา': 7, 'จ': 1, 'อ': 2, 'พ': 3, 'พฤ': 4, 'ศ': 5, 'ส': 6};
                      final todayStr = todayThaiStr();
                      final nowM = now.hour * 60 + now.minute;
                      final hasSchedule = pkgs.any((p) => p.effectiveSlots.isNotEmpty);

                      String learnLabel = 'ว่าง';
                      Color learnColor = Colors.grey;
                      bool needsCut = false;

                      if (hasSchedule) {
                        // วน slot ของวันนี้ทั้งหมดจากทุกแพ็กเกจ
                        bool anyActive = false;   // อยู่ในช่วงเรียน
                        bool anyUpcoming = false; // วันนี้ ยังไม่ถึงเวลา
                        bool anyEnded = false;    // วันนี้ เลยเวลาแล้ว
                        for (final p in pkgs) {
                          for (final s in p.effectiveSlots) {
                            if (s.date != null && s.date!.isNotEmpty) {
                              if (s.date != todayStr) continue;
                            } else if (dayMap[s.day] != now.weekday) continue;
                            try {
                              final sp = s.startTime.split(':');
                              final ep = (s.endTime.isNotEmpty ? s.endTime : s.startTime).split(':');
                              final startM = int.parse(sp[0]) * 60 + int.parse(sp[1]);
                              final endM = int.parse(ep[0]) * 60 + int.parse(ep[1]);
                              if (nowM >= startM && nowM < endM) {
                                anyActive = true;
                              } else if (nowM < startM) {
                                anyUpcoming = true;
                              } else {
                                anyEnded = true;
                              }
                            } catch (_) {}
                          }
                        }
                        // ลำดับความสำคัญ: กำลังเรียน > รอเรียน(ยังมีคาบวันนี้) > เรียนแล้ว
                        if (anyActive) {
                          learnLabel = 'กำลังเรียน';
                          learnColor = Colors.green;
                        } else if (anyUpcoming) {
                          learnLabel = 'รอเรียน';
                          learnColor = Colors.amber.shade700;
                        } else if (anyEnded) {
                          learnLabel = 'เรียนแล้ว';
                          learnColor = Colors.blue;
                        }

                        // ── รอตัดคาบ: ใช้ตรรกะเดียวกับหน้าตัดคาบ (รองรับหลาย slot + เช็ค session ตัดแล้ว) ──
                        needsCut = FirestoreService
                            .computePendingCuts(pkgs, todaySessions)
                            .isNotEmpty;
                      }

                      // ── ตารางเรียน: วัน/วันที่ + เวลา ทุก slot (ดูได้ทันทีไม่ต้องคลิกเข้า) ──
                      final scheduleLines = <String>[];
                      for (final p in pkgs) {
                        for (final s in p.effectiveSlots) {
                          final datePart = (s.date != null && s.date!.isNotEmpty)
                              ? '${thaiDayAbbrFromStr(s.date!)} ${thaiShortDateFromStr(s.date!)}'
                              : 'ทุก${s.day}';
                          final timePart = s.startTime.isNotEmpty
                              ? '${s.startTime}${s.endTime.isNotEmpty ? '–${s.endTime}' : ''} น.'
                              : '';
                          scheduleLines.add('$datePart  $timePart'.trim());
                        }
                      }

                      // ── หมายเหตุ/ชื่อคอร์ส จากแพ็กเกจ (แสดงให้เห็นทันที) ──
                      final notes = <String>[];
                      for (final p in pkgs) {
                        final n = p.notes?.trim();
                        if (n != null && n.isNotEmpty && !notes.contains(n)) notes.add(n);
                      }

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(54, 0, 12, 10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // แถว 1: จำนวนคาบ + +/- badges
                          Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            Icon(Icons.book_outlined, size: 13, color: Colors.blue.shade300),
                            Text('จำนวนคาบ:', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            Text('$total คาบ', style: const TextStyle(fontSize: 12, color: Color(0xFFF97316), fontWeight: FontWeight.w600)),
                            Text('•', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                            Text('เรียนแล้ว', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            Text('$used', style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                            Text('•', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                            Text('เหลือ', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            Text('$remaining', style: TextStyle(fontSize: 12, color: remaining <= 0 ? Colors.red.shade600 : Colors.blue.shade700, fontWeight: FontWeight.w600)),
                            if (hasAdj) ...[
                              if (u.totalAdded > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                                  child: Text('+${u.totalAdded}', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                ),
                              if (u.totalRemoved > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                                  child: Text('-${u.totalRemoved}', style: TextStyle(fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ]),
                          // แถว หมายเหตุ/ชื่อคอร์ส (จากแพ็กเกจ)
                          if (notes.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ...notes.map((n) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Icon(Icons.sticky_note_2_outlined, size: 13, color: Colors.amber.shade700),
                                const SizedBox(width: 4),
                                Expanded(child: Text(n,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.brown.shade600))),
                              ]),
                            )),
                          ],
                          const SizedBox(height: 4),
                          // แถว 2: สถานะ dot + text
                          Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 7, height: 7, decoration: BoxDecoration(color: learnColor, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Text(learnLabel, style: TextStyle(fontSize: 11, color: learnColor, fontWeight: FontWeight.w600)),
                            ]),
                            if (needsCut)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange),
                                const SizedBox(width: 3),
                                Text('รอตัดคาบเรียน', style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                              ]),
                          ]),
                          // แถว 3: ตารางเรียน (วัน/วันที่ + เวลา ทุก slot)
                          if (scheduleLines.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            ...scheduleLines.asMap().entries.map((e) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                SizedBox(
                                  width: 20,
                                  child: Text('${e.key + 1}.',
                                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                                ),
                                const Icon(Icons.event_outlined, size: 12, color: Color(0xFFF97316)),
                                const SizedBox(width: 4),
                                Expanded(child: Text(e.value,
                                    style: const TextStyle(fontSize: 11.5, color: Colors.black54))),
                              ]),
                            )),
                          ],
                        ]),
                      );
                    },
                  ),
              ]),
            );
          },
        );
          },
        )),
        ]);
      },
    );
  }
}
