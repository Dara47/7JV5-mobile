import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../utils/date_format.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  /// ผู้ใช้ที่ล็อกอินอยู่ตอนนี้ — ใช้แนบชื่อผู้ดูแลใน audit log
  static AppUser? currentUser;

  static Stream<List<UserModel>> watchUsers({String? role}) {
    Query<Map<String, dynamic>> q = _db.collection('users');
    if (role != null) q = q.where('role', isEqualTo: role);
    return q.snapshots().map((s) => s.docs.map(UserModel.fromDoc).toList()
      ..sort((a, b) => a.code.compareTo(b.code)));
  }

  static Future<AppUser> getAppUser(String uid, {String email = ''}) async {
    // ชื่อเริ่มต้นของ admin = ส่วนหน้าอีเมล (เช่น frame@7j.com → "frame")
    final fallbackName = email.contains('@') ? email.split('@').first : 'Admin';
    final doc = await _db.collection('users').doc(uid).get();
    AppUser u;
    if (!doc.exists) {
      u = AppUser(uid: uid, role: 'admin', name: fallbackName, code: 'A000', email: email);
    } else {
      final d = doc.data()!;
      final name = (d['name'] ?? '').toString().trim();
      u = AppUser(
        uid: uid, role: d['role'] ?? 'admin',
        name: name.isEmpty ? fallbackName : name,
        code: d['code'] ?? '', email: email,
      );
    }
    currentUser = u;
    return u;
  }

  /// บันทึก/แก้ชื่อผู้ดูแล (เขียน users/{uid}) — ให้ audit log รู้ว่าใคร
  static Future<void> saveAdminName(String name) async {
    final u = currentUser;
    if (u == null) return;
    await _db.collection('users').doc(u.uid).set({
      'role': 'admin',
      'name': name.trim(),
      'email': u.email,
      'code': u.code.isEmpty ? 'A000' : u.code,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    currentUser = AppUser(uid: u.uid, role: 'admin', name: name.trim(), code: u.code, email: u.email);
  }

  // ── Audit Log (ใครทำอะไร) ──────────────────────────────────────────────────
  /// บันทึกการกระทำของผู้ดูแล — ทำงานเฉพาะเมื่อผู้ใช้ปัจจุบันเป็น admin
  static Future<void> logAudit(String action, {String detail = ''}) async {
    final u = currentUser;
    if (u == null || !u.isAdmin) return;
    try {
      await _db.collection('auditLogs').add({
        'action': action,
        'detail': detail,
        'adminName': u.name,
        'adminEmail': u.email,
        'adminUid': u.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {/* อย่าให้ log ล้มแล้วกระทบงานหลัก */}
  }

  static Stream<List<AuditLogModel>> watchAuditLogs({int limit = 300}) {
    return _db.collection('auditLogs')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(AuditLogModel.fromDoc).toList());
  }

  static Future<UserModel?> getUser(String id) async {
    final doc = await _db.collection('users').doc(id).get();
    if (!doc.exists) return null;
    return UserModel.fromDoc(doc);
  }

  static Stream<List<PackageModel>> watchPackagesForUser(String userId, String role) {
    final field = role == 'student' ? 'studentId' : 'teacherId';
    return _db.collection('packages').where(field, isEqualTo: userId)
        .snapshots().map((s) => s.docs.map(PackageModel.fromDoc).toList());
  }

  static Future<List<PackageModel>> getPackagesForUser(String userId, String role) async {
    final field = role == 'student' ? 'studentId' : 'teacherId';
    final snap = await _db.collection('packages').where(field, isEqualTo: userId).where('status', isEqualTo: 'active').get();
    return snap.docs.map(PackageModel.fromDoc).toList();
  }

  static Stream<List<SessionModel>> watchSessionsForUser(String userId, String role) {
    final field = role == 'student' ? 'studentId' : 'teacherId';
    return _db.collection('sessions').where(field, isEqualTo: userId)
        .snapshots().map((s) {
      final list = s.docs.map(SessionModel.fromDoc).toList();
      list.sort((a, b) {
        final dateCmp = b.date.compareTo(a.date);
        return dateCmp != 0 ? dateCmp : b.startTime.compareTo(a.startTime);
      });
      return list;
    });
  }

  /// session ของวันนี้ (ทุกสถานะ) — ใช้เช็คว่า slot ไหนตัดไปแล้ว
  static Stream<List<SessionModel>> watchTodaySessions() {
    return _db.collection('sessions').where('date', isEqualTo: todayThaiStr())
        .snapshots().map((s) => s.docs.map(SessionModel.fromDoc).toList());
  }

  /// คำนวณคาบที่รอตัดวันนี้ (รองรับหลาย slot/วัน) จาก packages + session ของวันนี้
  static List<PendingCut> computePendingCuts(
      List<PackageModel> packages, List<SessionModel> todaySessions) {
    return computePendingCutsForDate(packages, todaySessions, nowThai());
  }

  /// คำนวณคาบที่รอตัด "ในวันที่กำหนด" (รองรับหลาย slot/วัน) จาก packages + session ของวันนั้น
  /// - อนาคต: ไม่มีคาบให้ตัด (ยังไม่เลยเวลา)
  /// - อดีต: ทุกคาบของวันนั้นถือว่าเลยเวลาแล้ว
  /// - วันนี้: เฉพาะคาบที่เลยเวลาสิ้นสุดแล้ว
  static List<PendingCut> computePendingCutsForDate(
      List<PackageModel> packages, List<SessionModel> daySessions, DateTime date) {
    final now = nowThai();
    final dateStr = toStorageDateStr(date);
    const thaiDays = {1: 'จ', 2: 'อ', 3: 'พ', 4: 'พฤ', 5: 'ศ', 6: 'ส', 7: 'อา'};
    final targetDay = thaiDays[date.weekday]!;
    final nowMinutes = now.hour * 60 + now.minute;
    final dOnly = DateTime(date.year, date.month, date.day);
    final tOnly = DateTime(now.year, now.month, now.day);
    final isFuture = dOnly.isAfter(tOnly);
    final isPast = dOnly.isBefore(tOnly);
    // slot ที่ "ตัดแล้ว" ในวันนั้น = มี session completed ที่ packageId+startTime ตรงกัน
    final completed = <String>{};
    for (final s in daySessions) {
      if (s.status == 'completed') completed.add('${s.packageId}_${s.startTime}');
    }

    final result = <PendingCut>[];
    if (isFuture) return result; // คาบในอนาคตยังไม่เลยเวลา ตัดไม่ได้
    for (final pkg in packages) {
      if (pkg.status != 'active') continue;
      if (pkg.remainingSessions <= 0) continue;
      for (final slot in pkg.effectiveSlots) {
        // ต้องเป็นช่วงของวันที่กำหนด
        if (slot.date != null && slot.date!.isNotEmpty) {
          if (slot.date != dateStr) continue;
        } else if (slot.day != targetDay) {
          continue;
        }
        // วันนี้: ต้องเลยเวลาสิ้นสุดแล้ว (อดีตผ่านไปแล้วทุกคาบ)
        if (!isPast) {
          try {
            final ref = slot.endTime.isNotEmpty ? slot.endTime : slot.startTime;
            final ep = ref.split(':');
            final endM = int.parse(ep[0]) * 60 + int.parse(ep[1]);
            if (nowMinutes < endM) continue;
          } catch (_) { continue; }
        }
        // ยังไม่ตัด slot นี้ในวันนั้น
        if (completed.contains('${pkg.id}_${slot.startTime}')) continue;
        result.add(PendingCut(pkg, slot));
      }
    }
    result.sort((a, b) => a.slot.startTime.compareTo(b.slot.startTime));
    return result;
  }

  /// session ของวันที่กำหนด
  static Stream<List<SessionModel>> watchSessionsForDate(DateTime date) {
    return _db.collection('sessions').where('date', isEqualTo: toStorageDateStr(date))
        .snapshots().map((s) => s.docs.map(SessionModel.fromDoc).toList());
  }

  /// stream คาบรอตัดวันนี้ (รวม packages + session ของวันนี้)
  static Stream<List<PendingCut>> watchPendingCuts() => watchPendingCutsForDate(nowThai());

  /// stream คาบรอตัด "ในวันที่กำหนด" (รวม packages + session ของวันนั้น)
  static Stream<List<PendingCut>> watchPendingCutsForDate(DateTime date) {
    final controller = StreamController<List<PendingCut>>();
    List<PackageModel>? pkgs;
    List<SessionModel>? sess;
    void emit() {
      if (pkgs != null && sess != null) controller.add(computePendingCutsForDate(pkgs!, sess!, date));
    }
    final s1 = watchAllPackages().listen((p) { pkgs = p; emit(); });
    final s2 = watchSessionsForDate(date).listen((s) { sess = s; emit(); });
    controller.onCancel = () { s1.cancel(); s2.cancel(); };
    return controller.stream;
  }

  /// ตัดคาบ 1 ช่วงเวลา (slot) ของแพ็กเกจ — หักโควตาคาบร่วม 1 คาบ
  /// reuse session ที่มีอยู่ของวัน+เวลาเดียวกัน (เช่นที่ generate ไว้) ไม่สร้างซ้ำ
  /// onDate: วันที่ของคาบ (ดีฟอลต์ = วันนี้) — ใช้ตัดคาบย้อนหลังจากปฏิทินได้
  static Future<void> cutSlot(PackageModel pkg, SlotItem slot, {DateTime? onDate}) async {
    final dateStr = onDate != null ? toStorageDateStr(onDate) : todayThaiStr();
    final existing = await _db.collection('sessions')
        .where('packageId', isEqualTo: pkg.id)
        .where('date', isEqualTo: dateStr)
        .where('startTime', isEqualTo: slot.startTime)
        .limit(1).get();
    if (existing.docs.isNotEmpty) {
      if ((existing.docs.first.data()['status'] as String?) == 'completed') return; // ตัดไปแล้ว
      await existing.docs.first.reference.update({
        'status': 'completed', 'endTime': slot.endTime,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _db.collection('sessions').add({
        'packageId': pkg.id,
        'studentId': pkg.studentId, 'teacherId': pkg.teacherId,
        'studentName': pkg.studentName, 'teacherName': pkg.teacherName,
        'date': dateStr, 'startTime': slot.startTime, 'endTime': slot.endTime,
        'status': 'completed', 'isLate': false, 'isAbsent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await _db.collection('packages').doc(pkg.id).update({
      'remainingSessions': FieldValue.increment(-1),
      'lastCutDate': dateStr,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await logAudit('ตัดคาบ',
        detail: '${pkg.studentName} (${pkg.studentCode}) · ครู ${pkg.teacherName} · ${slot.startTime}–${slot.endTime} · $dateStr');
  }

  /// ตัดคาบหลาย slot ในคลิกเดียว (batch) — คืนจำนวนที่ตัดสำเร็จ
  /// onDate: วันที่ของคาบที่จะตัด (ดีฟอลต์ = วันนี้) — ใช้ตัดทั้งวันจากปฏิทินย้อนหลังได้
  static Future<int> cutAllSlots(List<PendingCut> items, {DateTime? onDate}) async {
    final today = onDate != null ? toStorageDateStr(onDate) : todayThaiStr();
    final todaySnap = await _db.collection('sessions').where('date', isEqualTo: today).get();
    // map packageId+startTime → ref (reuse session ที่ generate ไว้)
    final byKey = <String, DocumentReference>{};
    for (final d in todaySnap.docs) {
      final m = d.data();
      final k = '${m['packageId']}_${m['startTime']}';
      byKey.putIfAbsent(k, () => d.reference);
    }
    final batch = _db.batch();
    final dec = <String, int>{}; // packageId → จำนวนคาบที่หัก
    int count = 0;
    for (final it in items) {
      final key = '${it.pkg.id}_${it.slot.startTime}';
      final ref = byKey[key];
      if (ref != null) {
        batch.update(ref, {'status': 'completed', 'endTime': it.slot.endTime, 'updatedAt': FieldValue.serverTimestamp()});
      } else {
        final sref = _db.collection('sessions').doc();
        batch.set(sref, {
          'packageId': it.pkg.id,
          'studentId': it.pkg.studentId, 'teacherId': it.pkg.teacherId,
          'studentName': it.pkg.studentName, 'teacherName': it.pkg.teacherName,
          'date': today, 'startTime': it.slot.startTime, 'endTime': it.slot.endTime,
          'status': 'completed', 'isLate': false, 'isAbsent': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      dec[it.pkg.id] = (dec[it.pkg.id] ?? 0) + 1;
      count++;
    }
    dec.forEach((pid, n) {
      batch.update(_db.collection('packages').doc(pid), {
        'remainingSessions': FieldValue.increment(-n),
        'lastCutDate': today,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    if (count > 0) {
      await batch.commit();
      await logAudit('ตัดคาบทั้งหมด', detail: '$count คาบ');
    }
    return count;
  }

  /// สร้างตารางคาบล่วงหน้า (status 'scheduled') จากแพ็กเกจ active สำหรับ N วันข้างหน้า
  /// - กันซ้ำด้วย packageId+date / จำกัดไม่เกิน remainingSessions ต่อแพ็กเกจ
  /// - คืนจำนวน session ที่สร้างใหม่
  static Future<int> generateUpcomingSessions({int daysAhead = 30}) async {
    final now = nowThai();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = today.add(Duration(days: daysAhead));
    final todayStr = toStorageDateStr(today);
    final endStr = toStorageDateStr(endDate);

    final pkgSnap = await _db.collection('packages').where('status', isEqualTo: 'active').get();
    final packages = pkgSnap.docs.map(PackageModel.fromDoc).toList();

    // session ที่มีอยู่ในช่วงนี้ → กันซ้ำ + นับ scheduled ที่มีอยู่แล้วต่อแพ็กเกจ
    final sessSnap = await _db.collection('sessions')
        .where('date', isGreaterThanOrEqualTo: todayStr)
        .where('date', isLessThanOrEqualTo: endStr)
        .get();
    final existingKeys = <String>{};
    final scheduledCount = <String, int>{};
    for (final d in sessSnap.docs) {
      final m = d.data();
      final pid = m['packageId'] as String? ?? '';
      final dt = m['date'] as String? ?? '';
      final st = m['startTime'] as String? ?? '';
      existingKeys.add('${pid}_${dt}_$st'); // กันซ้ำราย slot (packageId+date+เวลาเริ่ม)
      if ((m['status'] as String?) == 'scheduled') {
        scheduledCount[pid] = (scheduledCount[pid] ?? 0) + 1;
      }
    }

    const dayMap = {'อา': 7, 'จ': 1, 'อ': 2, 'พ': 3, 'พฤ': 4, 'ศ': 5, 'ส': 6};
    WriteBatch batch = _db.batch();
    int batchOps = 0;
    int created = 0;

    for (final p in packages) {
      int allowed = p.remainingSessions - (scheduledCount[p.id] ?? 0);
      if (allowed <= 0) continue;

      // รวม (วันที่, slot) ที่จะเกิดในช่วง — จากทุก slot ของแพ็กเกจ
      final occ = <({DateTime date, SlotItem slot})>[];
      for (final slot in p.effectiveSlots) {
        if (slot.date != null && slot.date!.isNotEmpty) {
          final d = parseDateStr(slot.date!);
          if (d != null) {
            final dd = DateTime(d.year, d.month, d.day);
            if (!dd.isBefore(today) && !dd.isAfter(endDate)) occ.add((date: dd, slot: slot));
          }
        } else {
          final wd = dayMap[slot.day];
          if (wd != null) {
            for (var dt = today; !dt.isAfter(endDate); dt = dt.add(const Duration(days: 1))) {
              if (dt.weekday == wd) occ.add((date: dt, slot: slot));
            }
          }
        }
      }
      occ.sort((a, b) {
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.slot.startTime.compareTo(b.slot.startTime);
      });

      for (final o in occ) {
        if (allowed <= 0) break;
        final ds = toStorageDateStr(o.date);
        final key = '${p.id}_${ds}_${o.slot.startTime}';
        if (existingKeys.contains(key)) continue;
        final ref = _db.collection('sessions').doc();
        batch.set(ref, {
          'packageId': p.id,
          'studentId': p.studentId, 'teacherId': p.teacherId,
          'studentName': p.studentName, 'teacherName': p.teacherName,
          'date': ds,
          'startTime': o.slot.startTime,
          'endTime': o.slot.endTime,
          'status': 'scheduled',
          'isLate': false, 'isAbsent': false,
          'generated': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        existingKeys.add(key);
        allowed--;
        created++;
        batchOps++;
        if (batchOps >= 400) { await batch.commit(); batch = _db.batch(); batchOps = 0; }
      }
    }
    if (batchOps > 0) await batch.commit();
    return created;
  }

  /// ซิงก์ตารางล่วงหน้าของแพ็กเกจเดียวให้ตรงกับ slots ปัจจุบัน
  /// - ลบ session 'scheduled' ที่ generate ไว้ (generated==true) แต่ไม่ตรงตารางใหม่แล้ว
  /// - สร้าง session 'scheduled' ที่ขาดให้ตรง (จำกัดตาม remainingSessions)
  /// - ไม่แตะ session ที่ completed/cancelled หรือที่สร้างเอง (generated != true)
  /// เรียกหลังแก้/ย้าย/ลบ slot ของแพ็กเกจ เพื่อให้ปฏิทินล่วงหน้าตรงเสมอ
  static Future<void> resyncPackageSchedule(String packageId, {int daysAhead = 30}) async {
    final now = nowThai();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = today.add(Duration(days: daysAhead));
    final todayStr = toStorageDateStr(today);
    final endStr = toStorageDateStr(endDate);

    final doc = await _db.collection('packages').doc(packageId).get();
    if (!doc.exists) return;
    final pkg = PackageModel.fromDoc(doc);

    // ── occurrence ที่ถูกต้องตามตารางปัจจุบัน (วันนี้→endDate) ──
    const dayMap = {'อา': 7, 'จ': 1, 'อ': 2, 'พ': 3, 'พฤ': 4, 'ศ': 5, 'ส': 6};
    final valid = <String, ({String date, SlotItem slot})>{}; // key date_startTime
    if (pkg.status == 'active' && pkg.remainingSessions > 0) {
      for (final slot in pkg.effectiveSlots) {
        if (slot.date != null && slot.date!.isNotEmpty) {
          final d = parseDateStr(slot.date!);
          if (d != null) {
            final dd = DateTime(d.year, d.month, d.day);
            if (!dd.isBefore(today) && !dd.isAfter(endDate)) {
              final ds = toStorageDateStr(dd);
              valid['${ds}_${slot.startTime}'] = (date: ds, slot: slot);
            }
          }
        } else {
          final wd = dayMap[slot.day];
          if (wd != null) {
            for (var dt = today; !dt.isAfter(endDate); dt = dt.add(const Duration(days: 1))) {
              if (dt.weekday == wd) {
                final ds = toStorageDateStr(dt);
                valid['${ds}_${slot.startTime}'] = (date: ds, slot: slot);
              }
            }
          }
        }
      }
    }

    // ── session ของแพ็กเกจนี้ (query เฉพาะ packageId แล้วกรองช่วงวันใน memory
    //    เพื่อเลี่ยง composite index packageId+date) ──
    final snap = await _db.collection('sessions')
        .where('packageId', isEqualTo: packageId)
        .get();

    final batch = _db.batch();
    int ops = 0;
    final existingValidKeys = <String>{};
    for (final d in snap.docs) {
      final m = d.data();
      final ds = m['date'] as String? ?? '';
      if (ds.compareTo(todayStr) < 0 || ds.compareTo(endStr) > 0) continue; // นอกช่วง วันนี้→endDate
      final key = '${ds}_${m['startTime']}';
      final isScheduledGenerated =
          (m['status'] as String?) == 'scheduled' && m['generated'] == true;
      if (isScheduledGenerated && !valid.containsKey(key)) {
        batch.delete(d.reference); // ตารางเปลี่ยน → ลบคาบที่ generate ไว้แต่ไม่ตรงแล้ว
        ops++;
      } else {
        existingValidKeys.add(key); // มีอยู่แล้ว (ตรง) หรือเป็นคาบที่ตัด/สร้างเอง — กันสร้างซ้ำ
      }
    }

    // ── สร้าง occurrence ที่ขาด (จำกัดตามโควตาที่เหลือ) ──
    int allowed = pkg.remainingSessions - existingValidKeys.length;
    final missing = valid.entries
        .where((e) => !existingValidKeys.contains(e.key))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final e in missing) {
      if (allowed <= 0) break;
      final slot = e.value.slot;
      final ref = _db.collection('sessions').doc();
      batch.set(ref, {
        'packageId': pkg.id,
        'studentId': pkg.studentId, 'teacherId': pkg.teacherId,
        'studentName': pkg.studentName, 'teacherName': pkg.teacherName,
        'date': e.value.date, 'startTime': slot.startTime, 'endTime': slot.endTime,
        'status': 'scheduled', 'isLate': false, 'isAbsent': false,
        'generated': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      allowed--;
      ops++;
    }

    if (ops > 0) await batch.commit();
  }

  /// session ทั้งหมด (ทุกสถานะ) — สำหรับปฏิทิน admin
  static Stream<List<SessionModel>> watchAllSessions() {
    return _db.collection('sessions').snapshots()
        .map((s) => s.docs.map(SessionModel.fromDoc).toList());
  }

  static Stream<List<SessionModel>> watchCompletedSessions() {
    return _db.collection('sessions')
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((s) {
      final list = s.docs.map(SessionModel.fromDoc).toList();
      list.sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : b.startTime.compareTo(a.startTime);
      });
      return list;
    });
  }

  static Future<void> deleteAllCompletedSessions() async {
    final snap = await _db.collection('sessions').where('status', isEqualTo: 'completed').get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  static Future<void> addSession(Map<String, dynamic> data) async {
    await _db.collection('sessions').add({
      ...data, 'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateSession(String id, Map<String, dynamic> data) async {
    await _db.collection('sessions').doc(id).update({
      ...data, 'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> updateSessionStatus(String sessionId, String status) async {
    await _db.collection('sessions').doc(sessionId).update({
      'status': status, 'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteSession(String sessionId) async {
    await _db.collection('sessions').doc(sessionId).delete();
  }

  // ── Package management ───────────────────────────────────────────────────

  static Stream<List<PackageModel>> watchAllPackages() {
    return _db.collection('packages').snapshots().map((s) {
      final list = s.docs.map(PackageModel.fromDoc).toList();
      list.sort((a, b) => a.studentName.compareTo(b.studentName));
      return list;
    });
  }

  static Future<void> deletePackage(String id) async {
    await _db.collection('packages').doc(id).delete();
  }

  static Future<void> addPackage(Map<String, dynamic> data) async {
    await _db.collection('packages').add({...data, 'createdAt': FieldValue.serverTimestamp()});
  }

  static Future<void> updatePackageFields(String id, Map<String, dynamic> data) async {
    await _db.collection('packages').doc(id).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  static Future<void> adjustSessions(String id, {int totalDelta = 0, int remainingDelta = 0, String? studentId}) async {
    await _db.collection('packages').doc(id).update({
      if (totalDelta != 0) 'totalSessions': FieldValue.increment(totalDelta),
      if (remainingDelta != 0) 'remainingSessions': FieldValue.increment(remainingDelta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    if (studentId != null && totalDelta != 0) {
      await _db.collection('users').doc(studentId).update({
        if (totalDelta > 0) 'totalAdded': FieldValue.increment(totalDelta),
        if (totalDelta < 0) 'totalRemoved': FieldValue.increment(-totalDelta),
      });
    }
  }

  // ── User management ──────────────────────────────────────────────────────

  static Future<String> generateCode(String role) async {
    final prefix = role == 'student' ? 'S' : 'T';
    final snap = await _db.collection('users').where('role', isEqualTo: role).get();
    int max = 270000;
    for (final doc in snap.docs) {
      final code = (doc.data()['code'] ?? '') as String;
      if (code.startsWith(prefix)) {
        // รองรับรหัสหลายยุค (S26xxxx / S27xxxx) — ตัด prefix แล้ว parse ตัวเลข
        final num = int.tryParse(code.substring(1));
        if (num != null && num > max) max = num;
      }
    }
    return '$prefix${max + 1}';
  }

  /// รหัสนี้ถูกใช้แล้วหรือยัง (กันซ้ำตอนสร้าง/โอนย้ายข้อมูล) — ข้ามเอกสารของตัวเองได้
  static Future<bool> isCodeTaken(String code, {String? excludeId}) async {
    final snap = await _db.collection('users')
        .where('code', isEqualTo: code.trim()).get();
    return snap.docs.any((d) => d.id != excludeId);
  }

  static Future<void> addUser(Map<String, dynamic> data) async {
    await _db.collection('users').add({...data, 'createdAt': FieldValue.serverTimestamp()});
    await logAudit('เพิ่มผู้ใช้', detail: '${data['name'] ?? ''} (${data['code'] ?? ''}) · ${data['role'] ?? ''}');
  }

  /// รหัสผู้ใช้ทั้งหมดในระบบ (uppercase) — ใช้กันซ้ำตอน bulk import
  static Future<Set<String>> allUserCodes() async {
    final snap = await _db.collection('users').get();
    return snap.docs
        .map((d) => ((d.data()['code'] ?? '') as String).trim().toUpperCase())
        .where((c) => c.isNotEmpty)
        .toSet();
  }

  /// เพิ่มผู้ใช้หลายคนพร้อมกัน (batch) — สำหรับโอนย้ายข้อมูลจาก V4.1.2
  static Future<void> bulkAddUsers(List<Map<String, dynamic>> users) async {
    var batch = _db.batch();
    int ops = 0;
    for (final u in users) {
      final ref = _db.collection('users').doc();
      batch.set(ref, {...u, 'createdAt': FieldValue.serverTimestamp()});
      ops++;
      if (ops >= 400) { await batch.commit(); batch = _db.batch(); ops = 0; }
    }
    if (ops > 0) await batch.commit();
    await logAudit('นำเข้าผู้ใช้', detail: '${users.length} คน');
  }

  /// ดัชนี user ตามรหัส (uppercase) → {id, name, role} — ใช้ resolve รหัสตอน import ความสัมพันธ์
  static Future<Map<String, ({String id, String name, String role})>> userIndexByCode() async {
    final snap = await _db.collection('users').get();
    final map = <String, ({String id, String name, String role})>{};
    for (final d in snap.docs) {
      final code = ((d.data()['code'] ?? '') as String).trim().toUpperCase();
      if (code.isEmpty) continue;
      map[code] = (
        id: d.id,
        name: (d.data()['name'] ?? '') as String,
        role: (d.data()['role'] ?? '') as String,
      );
    }
    return map;
  }

  /// เพิ่มแพ็กเกจ (ความสัมพันธ์ครู-นักเรียน) หลายรายการพร้อมกัน (batch)
  static Future<void> bulkAddPackages(List<Map<String, dynamic>> packages) async {
    var batch = _db.batch();
    int ops = 0;
    for (final p in packages) {
      final ref = _db.collection('packages').doc();
      batch.set(ref, {...p, 'createdAt': FieldValue.serverTimestamp()});
      ops++;
      if (ops >= 400) { await batch.commit(); batch = _db.batch(); ops = 0; }
    }
    if (ops > 0) await batch.commit();
    await logAudit('นำเข้าความสัมพันธ์', detail: '${packages.length} รายการ');
  }

  static Future<void> updateUser(String id, Map<String, dynamic> data) async {
    await _db.collection('users').doc(id).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
  }

  static Future<void> deleteUser(String id) async {
    await _db.collection('users').doc(id).delete();
  }

  static Future<void> cascadeDeleteUser(String userId, String role) async {
    final batch = _db.batch();

    // Delete user
    batch.delete(_db.collection('users').doc(userId));

    // Delete packages
    final pkgField = role == 'student' ? 'studentId' : 'teacherId';
    final pkgs = await _db.collection('packages').where(pkgField, isEqualTo: userId).get();
    for (final doc in pkgs.docs) {
      batch.delete(doc.reference);
    }

    // Delete non-completed sessions (keep completed → รายงาน)
    final sessionField = role == 'student' ? 'studentId' : 'teacherId';
    final sessions = await _db.collection('sessions').where(sessionField, isEqualTo: userId).get();
    for (final doc in sessions.docs) {
      if ((doc.data()['status'] as String? ?? '') != 'completed') {
        batch.delete(doc.reference);
      }
    }

    // Delete teacher slot (teacher only)
    if (role == 'teacher') {
      batch.delete(_db.collection('teacherSlots').doc(userId));
    }

    await batch.commit();
    await logAudit('ลบผู้ใช้', detail: '$role · id $userId · ลบแพ็กเกจ ${pkgs.docs.length}');
  }

  // ── Leave Requests ───────────────────────────────────────────────────────

  static Stream<List<LeaveRequestModel>> watchLeaveRequests() {
    return _db.collection('leaveRequests').snapshots().map((s) {
      final list = s.docs.map(LeaveRequestModel.fromDoc).toList();
      list.sort((a, b) {
        if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
        return b.date.compareTo(a.date);
      });
      return list;
    });
  }

  static Stream<List<LeaveRequestModel>> watchMyLeaveRequests(String userId) {
    return _db.collection('leaveRequests')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) {
      final list = s.docs.map(LeaveRequestModel.fromDoc).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  static Future<void> addLeaveRequest(Map<String, dynamic> data) async {
    await _db.collection('leaveRequests').add({...data, 'createdAt': FieldValue.serverTimestamp()});
  }

  static Future<void> updateLeaveStatus(String id, String status, {String? adminNote, String? who}) async {
    await _db.collection('leaveRequests').doc(id).update({
      'status': status,
      if (adminNote != null && adminNote.isNotEmpty) 'adminNote': adminNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final label = status == 'approved' ? 'อนุมัติใบลา' : status == 'rejected' ? 'ปฏิเสธใบลา' : 'อัปเดตใบลา';
    await logAudit(label, detail: who ?? id);
  }

  static Future<void> deleteLeaveRequest(String id, {String? who}) async {
    await _db.collection('leaveRequests').doc(id).delete();
    await logAudit('ลบใบลา', detail: who ?? id);
  }

  // ── Teacher slots ─────────────────────────────────────────────────────────

  static Stream<TeacherSlotModel?> watchTeacherSlot(String teacherId) {
    return _db.collection('teacherSlots').doc(teacherId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return TeacherSlotModel.fromDoc(doc);
    });
  }

  static Stream<List<PackageModel>> watchPackagesForTeacher(String teacherId) {
    return _db.collection('packages').where('teacherId', isEqualTo: teacherId)
        .snapshots().map((s) => s.docs.map(PackageModel.fromDoc).toList());
  }

  static Future<void> saveTeacherSlot(String teacherId, Map<String, dynamic> data) async {
    await _db.collection('teacherSlots').doc(teacherId).set({
      ...data, 'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> updateTeacherSlots(
      String teacherId, String teacherName, String teacherCode,
      List<SlotItem> slots, {String? notes}) async {
    await _db.collection('teacherSlots').doc(teacherId).set({
      'teacherName': teacherName,
      'teacherCode': teacherCode,
      'slots': slots.map((s) => s.toMap()).toList(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteTeacherSlot(String teacherId) async {
    await _db.collection('teacherSlots').doc(teacherId).delete();
  }

  static Stream<UserModel?> watchUser(String id) {
    return _db.collection('users').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromDoc(doc);
    });
  }

  // ── Code-based login ─────────────────────────────────────────────────────

  static Future<AppUser?> getAppUserByCode(String code) async {
    final snap = await _db.collection('users').where('code', isEqualTo: code.trim()).limit(1).get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    final d = doc.data();
    final role = d['role'] as String? ?? '';
    if (role != 'teacher' && role != 'student') return null;
    return AppUser(uid: doc.id, role: role, name: d['name'] ?? '', code: d['code'] ?? '');
  }

  // ── App Settings ─────────────────────────────────────────────────────────

  static Stream<Map<String, dynamic>> watchSettings() {
    return _db.collection('settings').doc('app_settings').snapshots().map((doc) {
      if (!doc.exists) return <String, dynamic>{};
      return doc.data() ?? <String, dynamic>{};
    });
  }

  static Future<void> saveSettings(Map<String, dynamic> data) async {
    await _db.collection('settings').doc('app_settings').set({
      ...data, 'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Payroll ───────────────────────────────────────────────────────────────

  static Future<List<TeacherPayrollModel>> getTeacherPayrolls() async {
    final snap = await _db.collection('sevenj_teacher_payroll')
        .orderBy('createdAt', descending: true).get();
    return snap.docs.map(TeacherPayrollModel.fromDoc).toList();
  }

  static Future<void> addTeacherPayroll(Map<String, dynamic> data) async {
    await _db.collection('sevenj_teacher_payroll').add(data);
  }

  static Future<void> updateTeacherPayroll(String id, Map<String, dynamic> data) async {
    await _db.collection('sevenj_teacher_payroll').doc(id).update(data);
  }

  static Future<void> deleteTeacherPayroll(String id) async {
    await _db.collection('sevenj_teacher_payroll').doc(id).delete();
  }

  static Future<List<AdminPayrollModel>> getAdminPayrolls() async {
    final snap = await _db.collection('sevenj_admin_payroll')
        .orderBy('createdAt', descending: true).get();
    return snap.docs.map(AdminPayrollModel.fromDoc).toList();
  }

  static Future<void> addAdminPayroll(Map<String, dynamic> data) async {
    await _db.collection('sevenj_admin_payroll').add(data);
  }

  static Future<void> updateAdminPayroll(String id, Map<String, dynamic> data) async {
    await _db.collection('sevenj_admin_payroll').doc(id).update(data);
  }

  static Future<void> deleteAdminPayroll(String id) async {
    await _db.collection('sevenj_admin_payroll').doc(id).delete();
  }
}
