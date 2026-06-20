import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

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
    final now = DateTime.now();
    const thaiDays = {1: 'จ', 2: 'อ', 3: 'พ', 4: 'พฤ', 5: 'ศ', 6: 'ส', 7: 'อา'};
    final todayDay = thaiDays[now.weekday]!;
    final nowMinutes = now.hour * 60 + now.minute;

    return _db.collection('packages')
        .where('scheduledDay', isEqualTo: todayDay)
        .snapshots()
        .map((s) {
      return s.docs.map(PackageModel.fromDoc).where((pkg) {
        if (pkg.remainingSessions <= 0) return false;
        if (pkg.scheduledEndTime == null) return false;
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
    final today = DateTime.now().toIso8601String().substring(0, 10);
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
    await _db.collection('packages').doc(pkg.id).update({
      'remainingSessions': FieldValue.increment(-1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  static Future<void> adjustSessions(String id, {int totalDelta = 0, int remainingDelta = 0}) async {
    await _db.collection('packages').doc(id).update({
      if (totalDelta != 0) 'totalSessions': FieldValue.increment(totalDelta),
      if (remainingDelta != 0) 'remainingSessions': FieldValue.increment(remainingDelta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  static Future<void> deleteTeacherSlot(String teacherId) async {
    await _db.collection('teacherSlots').doc(teacherId).delete();
  }
}
