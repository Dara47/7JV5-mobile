import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../utils/date_format.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static Stream<List<UserModel>> watchUsers({String? role}) {
    Query<Map<String, dynamic>> q = _db.collection('users');
    if (role != null) q = q.where('role', isEqualTo: role);
    return q.snapshots().map((s) => s.docs.map(UserModel.fromDoc).toList()
      ..sort((a, b) => a.code.compareTo(b.code)));
  }

  static Future<AppUser> getAppUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return AppUser(uid: uid, role: 'admin', name: 'Admin', code: 'A000');
    final d = doc.data()!;
    return AppUser(uid: uid, role: d['role'] ?? 'admin', name: d['name'] ?? '', code: d['code'] ?? '');
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

  static Stream<List<PackageModel>> watchPendingCutPackages() {
    final now = nowThai();
    const thaiDays = {1: 'จ', 2: 'อ', 3: 'พ', 4: 'พฤ', 5: 'ศ', 6: 'ส', 7: 'อา'};
    final todayDay = thaiDays[now.weekday]!;
    final todayStr = todayThaiStr();
    final nowMinutes = now.hour * 60 + now.minute;

    return _db.collection('packages')
        .where('scheduledDay', isEqualTo: todayDay)
        .snapshots()
        .map((s) {
      return s.docs.map(PackageModel.fromDoc).where((pkg) {
        if (pkg.scheduledEndTime == null) return false;
        // ถ้าตั้งวันที่เจาะจงไว้ ให้ตัดเฉพาะวันนั้นเท่านั้น (ไม่ใช่ทุก weekday ที่ตรง)
        if (pkg.scheduledDate != null && pkg.scheduledDate!.isNotEmpty &&
            pkg.scheduledDate != todayStr) return false;
        // show if already cut today OR still has sessions to cut
        final cutToday = pkg.lastCutDate == todayStr;
        if (!cutToday && pkg.remainingSessions <= 0) return false;
        try {
          final ep = pkg.scheduledEndTime!.split(':');
          final endM = int.parse(ep[0]) * 60 + int.parse(ep[1]);
          return nowMinutes >= endM;
        } catch (_) { return false; }
      }).toList()
        ..sort((a, b) => (a.scheduledTime ?? '').compareTo(b.scheduledTime ?? ''));
    });
  }

  static Future<void> cutPackageSession(PackageModel pkg) async {
    final today = todayThaiStr();
    // ถ้ามี session ของวันนี้อยู่แล้ว (เช่นที่ generate ตารางล่วงหน้าไว้) → อัปเดตเป็น completed
    final existing = await _db.collection('sessions')
        .where('packageId', isEqualTo: pkg.id)
        .where('date', isEqualTo: today)
        .limit(1).get();
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update({
        'status': 'completed',
        'startTime': pkg.scheduledTime ?? '',
        'endTime': pkg.scheduledEndTime ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _db.collection('sessions').add({
        'packageId': pkg.id,
        'studentId': pkg.studentId,
        'teacherId': pkg.teacherId,
        'studentName': pkg.studentName,
        'teacherName': pkg.teacherName,
        'date': today,
        'startTime': pkg.scheduledTime ?? '',
        'endTime': pkg.scheduledEndTime ?? '',
        'status': 'completed',
        'isLate': false,
        'isAbsent': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await _db.collection('packages').doc(pkg.id).update({
      'remainingSessions': FieldValue.increment(-1),
      'lastCutDate': today,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ตัดคาบทั้งหมดที่ยังไม่ตัดวันนี้ในคลิกเดียว (batch) — คืนจำนวนที่ตัดสำเร็จ
  static Future<int> cutAllPending(List<PackageModel> packages) async {
    final today = todayThaiStr();
    // โหลด session ของวันนี้ทั้งหมด เพื่อ reuse คาบที่ generate ตารางไว้ (กันซ้ำ)
    final todaySnap = await _db.collection('sessions').where('date', isEqualTo: today).get();
    final byPkg = <String, DocumentReference>{};
    for (final d in todaySnap.docs) {
      final pid = d.data()['packageId'] as String?;
      if (pid != null && !byPkg.containsKey(pid)) byPkg[pid] = d.reference;
    }
    final batch = _db.batch();
    int count = 0;
    for (final pkg in packages) {
      if (pkg.lastCutDate == today) continue;   // ตัดไปแล้ววันนี้
      if (pkg.remainingSessions <= 0) continue;  // ไม่มีคาบเหลือ
      final existingRef = byPkg[pkg.id];
      if (existingRef != null) {
        batch.update(existingRef, {
          'status': 'completed',
          'startTime': pkg.scheduledTime ?? '',
          'endTime': pkg.scheduledEndTime ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final sessionRef = _db.collection('sessions').doc();
        batch.set(sessionRef, {
          'packageId': pkg.id,
          'studentId': pkg.studentId,
          'teacherId': pkg.teacherId,
          'studentName': pkg.studentName,
          'teacherName': pkg.teacherName,
          'date': today,
          'startTime': pkg.scheduledTime ?? '',
          'endTime': pkg.scheduledEndTime ?? '',
          'status': 'completed',
          'isLate': false,
          'isAbsent': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      batch.update(_db.collection('packages').doc(pkg.id), {
        'remainingSessions': FieldValue.increment(-1),
        'lastCutDate': today,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      count++;
    }
    if (count > 0) await batch.commit();
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
      existingKeys.add('${pid}_$dt');
      if ((m['status'] as String?) == 'scheduled') {
        scheduledCount[pid] = (scheduledCount[pid] ?? 0) + 1;
      }
    }

    const dayMap = {'อา': 7, 'จ': 1, 'อ': 2, 'พ': 3, 'พฤ': 4, 'ศ': 5, 'ส': 6};
    WriteBatch batch = _db.batch();
    int batchOps = 0;
    int created = 0;

    for (final p in packages) {
      if (p.scheduledTime == null) continue;
      if (p.scheduledDay == null && p.scheduledDate == null) continue;
      int allowed = p.remainingSessions - (scheduledCount[p.id] ?? 0);
      if (allowed <= 0) continue;

      // วันที่ที่จะเกิดคาบในช่วง
      final dates = <DateTime>[];
      if (p.scheduledDate != null && p.scheduledDate!.isNotEmpty) {
        final d = parseDateStr(p.scheduledDate!);
        if (d != null) {
          final dd = DateTime(d.year, d.month, d.day);
          if (!dd.isBefore(today) && !dd.isAfter(endDate)) dates.add(dd);
        }
      } else {
        final wd = dayMap[p.scheduledDay];
        if (wd != null) {
          for (var dt = today; !dt.isAfter(endDate); dt = dt.add(const Duration(days: 1))) {
            if (dt.weekday == wd) dates.add(dt);
          }
        }
      }

      for (final dt in dates) {
        if (allowed <= 0) break;
        final ds = toStorageDateStr(dt);
        final key = '${p.id}_$ds';
        if (existingKeys.contains(key)) continue;
        final ref = _db.collection('sessions').doc();
        batch.set(ref, {
          'packageId': p.id,
          'studentId': p.studentId, 'teacherId': p.teacherId,
          'studentName': p.studentName, 'teacherName': p.teacherName,
          'date': ds,
          'startTime': p.scheduledTime ?? '',
          'endTime': p.scheduledEndTime ?? '',
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
        final num = int.tryParse(code.substring(1));
        if (num != null && num > max) max = num;
      }
    }
    return '$prefix${max + 1}';
  }

  static Future<void> addUser(Map<String, dynamic> data) async {
    await _db.collection('users').add({...data, 'createdAt': FieldValue.serverTimestamp()});
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

  static Future<void> updateLeaveStatus(String id, String status, {String? adminNote}) async {
    await _db.collection('leaveRequests').doc(id).update({
      'status': status,
      if (adminNote != null && adminNote.isNotEmpty) 'adminNote': adminNote,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> deleteLeaveRequest(String id) async {
    await _db.collection('leaveRequests').doc(id).delete();
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
