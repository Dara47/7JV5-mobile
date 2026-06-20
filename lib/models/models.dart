import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String role;
  final String name;
  final String code;
  AppUser({required this.uid, required this.role, required this.name, required this.code});
  bool get isAdmin => role == 'admin';
  bool get isTeacher => role == 'teacher';
  bool get isStudent => role == 'student';
}

class UserModel {
  final String id;
  final String code;
  final String name;
  final String role;
  final String status;
  final int? age;
  final String? googleMeetLink;

  UserModel({required this.id, required this.code, required this.name,
      required this.role, required this.status, this.age, this.googleMeetLink});

  bool get isStudent => role == 'student';
  bool get isTeacher => role == 'teacher';
  bool get isActive => status == 'active';

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id, code: d['code'] ?? '', name: d['name'] ?? '',
      role: d['role'] ?? 'student', status: d['status'] ?? 'active',
      age: d['age'], googleMeetLink: d['googleMeetLink'],
    );
  }
}

class PackageModel {
  final String id;
  final String studentId;
  final String teacherId;
  final String studentName;
  final String teacherName;
  final String studentCode;
  final String teacherCode;
  final int totalSessions;
  final int remainingSessions;
  final String status;
  final String? scheduledDay;      // 'อา','จ','อ','พ','พฤ','ศ','ส'
  final String? scheduledTime;     // '16:00'
  final String? scheduledEndTime;  // '17:00'
  final String? notes;
  final String? lastCutDate;       // 'YYYY-MM-DD' of last cut

  PackageModel({
    required this.id, required this.studentId, required this.teacherId,
    required this.studentName, required this.teacherName, required this.studentCode,
    required this.teacherCode, required this.totalSessions,
    required this.remainingSessions, required this.status,
    this.scheduledDay, this.scheduledTime, this.scheduledEndTime, this.notes,
    this.lastCutDate,
  });

  int get usedSessions => totalSessions - remainingSessions;
  bool get isExpired => remainingSessions <= 0;
  bool get isLowBalance => remainingSessions <= 3 && remainingSessions > 0;
  bool get isActive => remainingSessions > 3;

  String get statusLabel {
    if (isExpired) return 'หมดคาบ';
    if (isLowBalance) return 'ใกล้หมด';
    return 'ใช้งานอยู่';
  }

  Color get statusColor {
    if (isExpired) return const Color(0xFFE53935);
    if (isLowBalance) return const Color(0xFFFB8C00);
    return const Color(0xFF43A047);
  }

  String get scheduleLabel {
    if (scheduledDay == null) return '-';
    final t = scheduledTime ?? '';
    final e = scheduledEndTime != null ? '–$scheduledEndTime' : '';
    return '$scheduledDay  $t$e';
  }

  bool get isCurrentlyInSession {
    if (scheduledDay == null || scheduledTime == null) return false;
    final now = DateTime.now();
    const dayMap = {'อา': 7, 'จ': 1, 'อ': 2, 'พ': 3, 'พฤ': 4, 'ศ': 5, 'ส': 6};
    if (dayMap[scheduledDay] != now.weekday) return false;
    try {
      final sp = scheduledTime!.split(':');
      final startM = int.parse(sp[0]) * 60 + int.parse(sp[1]);
      final nowM = now.hour * 60 + now.minute;
      int endM = startM + 60;
      if (scheduledEndTime != null) {
        final ep = scheduledEndTime!.split(':');
        endM = int.parse(ep[0]) * 60 + int.parse(ep[1]);
      }
      return nowM >= startM && nowM < endM;
    } catch (_) { return false; }
  }

  static const days = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

  factory PackageModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PackageModel(
      id: doc.id, studentId: d['studentId'] ?? '', teacherId: d['teacherId'] ?? '',
      studentName: d['studentName'] ?? '', teacherName: d['teacherName'] ?? '',
      studentCode: d['studentCode'] ?? '', teacherCode: d['teacherCode'] ?? '',
      totalSessions: d['totalSessions'] ?? 0, remainingSessions: d['remainingSessions'] ?? 0,
      status: d['status'] ?? 'active',
      scheduledDay: d['scheduledDay'], scheduledTime: d['scheduledTime'],
      scheduledEndTime: d['scheduledEndTime'], notes: d['notes'],
      lastCutDate: d['lastCutDate'],
    );
  }

  Map<String, dynamic> toMap() => {
    'studentId': studentId, 'teacherId': teacherId,
    'studentName': studentName, 'teacherName': teacherName,
    'studentCode': studentCode, 'teacherCode': teacherCode,
    'totalSessions': totalSessions, 'remainingSessions': remainingSessions,
    'status': status,
    if (scheduledDay != null) 'scheduledDay': scheduledDay,
    if (scheduledTime != null) 'scheduledTime': scheduledTime,
    if (scheduledEndTime != null) 'scheduledEndTime': scheduledEndTime,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };
}

class SessionModel {
  final String id;
  final String packageId;
  final String studentId;
  final String teacherId;
  final String studentName;
  final String teacherName;
  final String date;
  final String startTime;
  final String endTime;
  final String status;
  final String? language;
  final String? skill;
  final bool isLate;
  final bool isAbsent;
  final String? notes;

  SessionModel({
    required this.id, required this.packageId, required this.studentId,
    required this.teacherId, required this.studentName, required this.teacherName,
    required this.date, required this.startTime, required this.endTime,
    required this.status, this.language, this.skill,
    this.isLate = false, this.isAbsent = false, this.notes,
  });

  bool get isScheduled => status == 'scheduled';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  String get timeRange => '$startTime–$endTime';

  int get durationMinutes {
    try {
      final s = startTime.split(':');
      final e = endTime.split(':');
      return (int.parse(e[0]) * 60 + int.parse(e[1])) -
             (int.parse(s[0]) * 60 + int.parse(s[1]));
    } catch (_) { return 0; }
  }

  String get durationLabel {
    final m = durationMinutes;
    if (m <= 0) return '-';
    if (m % 60 == 0) return '${m ~/ 60} ชม';
    return '${m ~/ 60}ชม ${m % 60}น';
  }

  static String statusLabel(String s) {
    switch (s) {
      case 'scheduled': return 'รอเรียน';
      case 'in_progress': return 'กำลังเรียน';
      case 'completed': return 'เรียนแล้ว';
      case 'cancelled': return 'ยกเลิก';
      default: return s;
    }
  }

  static const languages = ['English', 'จีน', 'ญี่ปุ่น', 'เกาหลี', 'ฝรั่งเศส', 'เยอรมัน'];
  static const skills = ['Speaking', 'Listening', 'Reading', 'Writing', 'Grammar', 'Vocabulary', 'Conversation', 'IELTS', 'TOEIC', 'Business'];

  factory SessionModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SessionModel(
      id: doc.id, packageId: d['packageId'] ?? '',
      studentId: d['studentId'] ?? '', teacherId: d['teacherId'] ?? '',
      studentName: d['studentName'] ?? '', teacherName: d['teacherName'] ?? '',
      date: d['date'] ?? '', startTime: d['startTime'] ?? '',
      endTime: d['endTime'] ?? '', status: d['status'] ?? 'scheduled',
      language: d['language'], skill: d['skill'],
      isLate: d['isLate'] ?? false, isAbsent: d['isAbsent'] ?? false,
      notes: d['notes'],
    );
  }

  Map<String, dynamic> toMap() => {
    'packageId': packageId, 'studentId': studentId, 'teacherId': teacherId,
    'studentName': studentName, 'teacherName': teacherName,
    'date': date, 'startTime': startTime, 'endTime': endTime,
    'status': status,
    if (language != null) 'language': language,
    if (skill != null) 'skill': skill,
    'isLate': isLate, 'isAbsent': isAbsent,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };
}

class LeaveRequestModel {
  final String id;
  final String userId;
  final String userName;
  final String userCode;
  final String userRole;
  final String date;
  final String reason;
  final String status; // 'pending', 'approved', 'rejected'
  final String? adminNote;

  LeaveRequestModel({
    required this.id, required this.userId, required this.userName,
    required this.userCode, required this.userRole, required this.date,
    required this.reason, required this.status, this.adminNote,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get statusLabel {
    switch (status) {
      case 'pending': return 'รอพิจารณา';
      case 'approved': return 'อนุมัติ';
      case 'rejected': return 'ปฏิเสธ';
      default: return status;
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending': return const Color(0xFFF57C00);
      case 'approved': return const Color(0xFF2E7D32);
      case 'rejected': return const Color(0xFFC62828);
      default: return Colors.grey;
    }
  }

  String get roleLabel => userRole == 'teacher' ? 'ครู' : 'นักเรียน';

  String get shortDate {
    if (date.length < 10) return date;
    return '${date.substring(8)}/${date.substring(5, 7)}/${date.substring(0, 4)}';
  }

  factory LeaveRequestModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return LeaveRequestModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      userName: d['userName'] ?? '',
      userCode: d['userCode'] ?? '',
      userRole: d['userRole'] ?? '',
      date: d['date'] ?? '',
      reason: d['reason'] ?? '',
      status: d['status'] ?? 'pending',
      adminNote: d['adminNote'],
    );
  }
}

class TeacherSlotModel {
  final String teacherId;
  final String teacherName;
  final String teacherCode;
  final String? scheduledDay;
  final String? scheduledTime;
  final String? scheduledEndTime;
  final String? notes;

  TeacherSlotModel({
    required this.teacherId, required this.teacherName, required this.teacherCode,
    this.scheduledDay, this.scheduledTime, this.scheduledEndTime, this.notes,
  });

  String get scheduleLabel {
    if (scheduledDay == null) return 'ยังไม่ได้ตั้งเวลา';
    final t = scheduledTime ?? '';
    final e = scheduledEndTime != null ? '–$scheduledEndTime' : '';
    return '$scheduledDay  $t$e';
  }

  bool get isCurrentlyTeaching {
    if (scheduledDay == null || scheduledTime == null) return false;
    final now = DateTime.now();
    const dayMap = {'อา': 7, 'จ': 1, 'อ': 2, 'พ': 3, 'พฤ': 4, 'ศ': 5, 'ส': 6};
    if (dayMap[scheduledDay] != now.weekday) return false;
    try {
      final sp = scheduledTime!.split(':');
      final startM = int.parse(sp[0]) * 60 + int.parse(sp[1]);
      final nowM = now.hour * 60 + now.minute;
      int endM = startM + 60;
      if (scheduledEndTime != null) {
        final ep = scheduledEndTime!.split(':');
        endM = int.parse(ep[0]) * 60 + int.parse(ep[1]);
      }
      return nowM >= startM && nowM < endM;
    } catch (_) { return false; }
  }

  factory TeacherSlotModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TeacherSlotModel(
      teacherId: doc.id,
      teacherName: d['teacherName'] ?? '', teacherCode: d['teacherCode'] ?? '',
      scheduledDay: d['scheduledDay'], scheduledTime: d['scheduledTime'],
      scheduledEndTime: d['scheduledEndTime'], notes: d['notes'],
    );
  }

  Map<String, dynamic> toMap() => {
    'teacherName': teacherName, 'teacherCode': teacherCode,
    if (scheduledDay != null) 'scheduledDay': scheduledDay,
    if (scheduledTime != null) 'scheduledTime': scheduledTime,
    if (scheduledEndTime != null) 'scheduledEndTime': scheduledEndTime,
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };
}
