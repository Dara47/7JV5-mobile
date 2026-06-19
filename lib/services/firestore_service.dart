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
}
