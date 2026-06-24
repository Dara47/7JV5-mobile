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

class _UserList extends StatelessWidget {
  final String role;
  final String search;
  final void Function({UserModel? user}) onEdit;
  const _UserList({required this.role, required this.search, required this.onEdit});

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

        return StreamBuilder<List<SessionModel>>(
          stream: role == 'student' ? FirestoreService.watchTodaySessions() : null,
          builder: (context, sessSnap) {
            final todaySessions = sessSnap.data ?? const <SessionModel>[];
            return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final u = filtered[i];
            final color = role == 'student' ? const Color(0xFFF97316) : const Color(0xFF2E7D32);
            return Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Row(mainAxisSize: MainAxisSize.min, children: [
                    // เลขลำดับ (เรียงตามผลค้นหา)
                    SizedBox(
                      width: 24,
                      child: Text('${i + 1}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                    ),
                    const SizedBox(width: 6),
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
                        if (v == 'edit') onEdit(user: u);
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
                  onTap: () => Navigator.push(context, MaterialPageRoute(
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

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(54, 0, 12, 10),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // แถว 1: จำนวนคาบ + +/- badges
                          Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            Icon(Icons.book_outlined, size: 13, color: Colors.blue.shade300),
                            Text('จำนวนคาบ:', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            Text('$total คาบ', style: const TextStyle(fontSize: 12, color: Color(0xFFF97316), fontWeight: FontWeight.w600)),
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
                            ...scheduleLines.map((line) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(children: [
                                const Icon(Icons.event_outlined, size: 12, color: Color(0xFFF97316)),
                                const SizedBox(width: 4),
                                Expanded(child: Text(line,
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
        );
      },
    );
  }
}
