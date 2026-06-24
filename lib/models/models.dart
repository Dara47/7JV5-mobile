import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_format.dart';

class AppUser {
  final String uid;
  final String role;
  final String name;
  final String code;
  final String email;
  AppUser({required this.uid, required this.role, required this.name, required this.code, this.email = ''});
  bool get isAdmin => role == 'admin';
  bool get isTeacher => role == 'teacher';
  bool get isStudent => role == 'student';
}

/// บันทึกการกระทำของผู้ดูแล (ใครทำอะไร เมื่อไหร่)
class AuditLogModel {
  final String id;
  final String action;     // เช่น 'ตัดคาบ', 'อนุมัติใบลา'
  final String detail;     // รายละเอียดเป้าหมาย
  final String adminName;
  final String adminEmail;
  final Timestamp? createdAt;

  AuditLogModel({
    required this.id, required this.action, required this.detail,
    required this.adminName, required this.adminEmail, this.createdAt,
  });

  factory AuditLogModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AuditLogModel(
      id: doc.id,
      action: d['action'] ?? '',
      detail: d['detail'] ?? '',
      adminName: d['adminName'] ?? '',
      adminEmail: d['adminEmail'] ?? '',
      createdAt: d['createdAt'] as Timestamp?,
    );
  }

  /// 'dd/MM/yyyy(+543) HH:mm' เวลาไทย
  String get timeLabel {
    if (createdAt == null) return '-';
    final t = createdAt!.toDate().toUtc().add(const Duration(hours: 7));
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(t.day)}/${p(t.month)}/${t.year + 543} ${p(t.hour)}:${p(t.minute)}';
  }
}

class UserModel {
  final String id;
  final String code;
  final String name;
  final String role;
  final String status;
  final int? age;
  final String? googleMeetLink;
  final int? defaultSessions;
  final int totalAdded;
  final int totalRemoved;

  UserModel({required this.id, required this.code, required this.name,
      required this.role, required this.status, this.age, this.googleMeetLink,
      this.defaultSessions, this.totalAdded = 0, this.totalRemoved = 0});

  bool get isStudent => role == 'student';
  bool get isTeacher => role == 'teacher';
  bool get isActive => status == 'active';

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id, code: d['code'] ?? '', name: d['name'] ?? '',
      role: d['role'] ?? 'student', status: d['status'] ?? 'active',
      age: d['age'], googleMeetLink: d['googleMeetLink'],
      defaultSessions: d['defaultSessions'],
      totalAdded: d['totalAdded'] ?? 0,
      totalRemoved: d['totalRemoved'] ?? 0,
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
  // ── ตารางเรียน — slot แรก (mirror ของ slots[0]) เก็บไว้เพื่อ backward-compat ──
  final String? scheduledDay;      // 'อา','จ','อ','พ','พฤ','ศ','ส'
  final String? scheduledDate;     // 'YYYY-MM-DD' (วันที่เจาะจง — optional)
  final String? scheduledTime;     // '16:00'
  final String? scheduledEndTime;  // '17:00'
  /// ช่วงเวลาเรียนทั้งหมด (หลาย slot ใช้โควตาคาบร่วมกัน) — ว่าง = ใช้ scheduled* ด้านบน
  final List<SlotItem> slots;
  final String? notes;
  final String? lastCutDate;       // 'YYYY-MM-DD' of last cut

  PackageModel({
    required this.id, required this.studentId, required this.teacherId,
    required this.studentName, required this.teacherName, required this.studentCode,
    required this.teacherCode, required this.totalSessions,
    required this.remainingSessions, required this.status,
    this.scheduledDay, this.scheduledDate, this.scheduledTime, this.scheduledEndTime,
    this.slots = const [], this.notes,
    this.lastCutDate,
  });

  /// ช่วงเวลาที่ใช้จริง — ถ้ามี slots ใช้ slots, ไม่งั้น fallback เป็น slot เดี่ยวจาก scheduled*
  List<SlotItem> get effectiveSlots {
    if (slots.isNotEmpty) return slots;
    if (scheduledDay != null && scheduledTime != null) {
      return [SlotItem(
        day: scheduledDay!,
        startTime: scheduledTime!,
        endTime: scheduledEndTime ?? scheduledTime!,
        date: scheduledDate,
      )];
    }
    return const [];
  }

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
    final list = effectiveSlots;
    if (list.isEmpty) return '-';
    return list.map((sl) {
      final datePart = (sl.date != null && sl.date!.isNotEmpty)
          ? '${thaiShortDateFromStr(sl.date!)} ' : '';
      final e = sl.endTime.isNotEmpty ? '–${sl.endTime}' : '';
      return '$datePart${sl.day}  ${sl.startTime}$e';
    }).join('   •   ');
  }

  bool get isCurrentlyInSession => effectiveSlots.any((s) => s.isCurrentlyActive);

  static const days = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

  factory PackageModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return PackageModel(
      id: doc.id, studentId: d['studentId'] ?? '', teacherId: d['teacherId'] ?? '',
      studentName: d['studentName'] ?? '', teacherName: d['teacherName'] ?? '',
      studentCode: d['studentCode'] ?? '', teacherCode: d['teacherCode'] ?? '',
      totalSessions: d['totalSessions'] ?? 0, remainingSessions: d['remainingSessions'] ?? 0,
      status: d['status'] ?? 'active',
      scheduledDay: d['scheduledDay'], scheduledDate: d['scheduledDate'],
      scheduledTime: d['scheduledTime'],
      scheduledEndTime: d['scheduledEndTime'],
      slots: (d['slots'] as List?)
          ?.map((m) => SlotItem.fromMap(m as Map<String, dynamic>))
          .toList() ?? const [],
      notes: d['notes'],
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
    if (scheduledDate != null) 'scheduledDate': scheduledDate,
    if (scheduledTime != null) 'scheduledTime': scheduledTime,
    if (scheduledEndTime != null) 'scheduledEndTime': scheduledEndTime,
    if (slots.isNotEmpty) 'slots': slots.map((s) => s.toMap()).toList(),
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };
}

/// คาบที่รอตัดวันนี้ (1 รายการ = 1 ช่วงเวลาของแพ็กเกจ) — รองรับหลาย slot/วัน
class PendingCut {
  final PackageModel pkg;
  final SlotItem slot;
  PendingCut(this.pkg, this.slot);
}

class SessionModel {
  final String id;
  final String packageId;
  final String studentId;
  final String teacherId;
  final String studentName;
  final String teacherName;
  final String? studentCode;
  final String? teacherCode;
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
    this.studentCode, this.teacherCode,
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
      studentCode: d['studentCode'], teacherCode: d['teacherCode'],
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
  final String teacherName; // ครูที่ลาเรียนในชั่วโมงสอน (สำหรับนักเรียน)
  final String teacherCode;
  final String studentName; // นักเรียนที่ลาสอนในชั่วโมงเรียน (สำหรับครู)
  final String studentCode;

  LeaveRequestModel({
    required this.id, required this.userId, required this.userName,
    required this.userCode, required this.userRole, required this.date,
    required this.reason, required this.status, this.adminNote,
    this.teacherName = '', this.teacherCode = '',
    this.studentName = '', this.studentCode = '',
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

  String get shortDate => thaiDateFromStr(date);

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
      teacherName: d['teacherName'] ?? '',
      teacherCode: d['teacherCode'] ?? '',
      studentName: d['studentName'] ?? '',
      studentCode: d['studentCode'] ?? '',
    );
  }

  bool get hasTeacher => teacherName.isNotEmpty || teacherCode.isNotEmpty;
  bool get hasStudent => studentName.isNotEmpty || studentCode.isNotEmpty;

  /// "ชื่อครู (รหัส)" — สำหรับแสดงผล
  String get teacherLabel {
    if (teacherName.isNotEmpty && teacherCode.isNotEmpty) return '$teacherName ($teacherCode)';
    return teacherName.isNotEmpty ? teacherName : teacherCode;
  }

  /// "ชื่อนักเรียน (รหัส)" — สำหรับแสดงผล
  String get studentLabel {
    if (studentName.isNotEmpty && studentCode.isNotEmpty) return '$studentName ($studentCode)';
    return studentName.isNotEmpty ? studentName : studentCode;
  }
}

class SlotItem {
  final String day;
  final String startTime;
  final String endTime;
  final String? date; // 'YYYY-MM-DD' (วันที่เจาะจง — optional)

  const SlotItem({required this.day, required this.startTime, required this.endTime, this.date});

  bool get isCurrentlyActive {
    final now = nowThai();
    // ถ้ามีวันที่เจาะจง ต้องตรงวันนั้นเป๊ะ
    if (date != null && date!.isNotEmpty) {
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (date != today) return false;
    } else {
      const dayMap = {'อา': 7, 'จ': 1, 'อ': 2, 'พ': 3, 'พฤ': 4, 'ศ': 5, 'ส': 6};
      if (dayMap[day] != now.weekday) return false;
    }
    try {
      final sp = startTime.split(':');
      final ep = endTime.split(':');
      final startM = int.parse(sp[0]) * 60 + int.parse(sp[1]);
      final endM = int.parse(ep[0]) * 60 + int.parse(ep[1]);
      final nowM = now.hour * 60 + now.minute;
      return nowM >= startM && nowM < endM;
    } catch (_) { return false; }
  }

  Map<String, dynamic> toMap() => {
    'day': day, 'startTime': startTime, 'endTime': endTime,
    if (date != null && date!.isNotEmpty) 'date': date,
  };

  factory SlotItem.fromMap(Map<String, dynamic> m) => SlotItem(
    day: m['day'] as String? ?? '',
    startTime: m['startTime'] as String? ?? '',
    endTime: m['endTime'] as String? ?? '',
    date: m['date'] as String?,
  );
}

class TeacherSlotModel {
  final String teacherId;
  final String teacherName;
  final String teacherCode;
  final List<SlotItem> slots;
  final String? notes;

  TeacherSlotModel({
    required this.teacherId, required this.teacherName, required this.teacherCode,
    this.slots = const [], this.notes,
  });

  bool get isCurrentlyTeaching => slots.any((s) => s.isCurrentlyActive);

  String get scheduleLabel {
    if (slots.isEmpty) return 'ยังไม่ได้ตั้งเวลา';
    return slots.map((s) {
      final datePart = (s.date != null && s.date!.isNotEmpty)
          ? '${thaiShortDateFromStr(s.date!)} ' : '';
      return '$datePart${s.day} ${s.startTime}–${s.endTime}';
    }).join(' / ');
  }

  factory TeacherSlotModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    List<SlotItem> slots = [];
    if (d['slots'] != null) {
      slots = (d['slots'] as List)
          .map((m) => SlotItem.fromMap(m as Map<String, dynamic>))
          .toList();
    } else if (d['scheduledDay'] != null) {
      // backward compat: old single-slot format
      slots = [SlotItem(
        day: d['scheduledDay'] as String,
        startTime: d['scheduledTime'] as String? ?? '',
        endTime: d['scheduledEndTime'] as String? ?? '',
      )];
    }
    return TeacherSlotModel(
      teacherId: doc.id,
      teacherName: d['teacherName'] ?? '', teacherCode: d['teacherCode'] ?? '',
      slots: slots, notes: d['notes'],
    );
  }

  Map<String, dynamic> toMap() => {
    'teacherName': teacherName, 'teacherCode': teacherCode,
    'slots': slots.map((s) => s.toMap()).toList(),
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
  };
}


// ── Payroll Models ────────────────────────────────────────────────────────────

class PayrollRole {
  final String role;
  final double rate;
  final double count;
  PayrollRole({required this.role, required this.rate, required this.count});
  double get total => rate * count;
  factory PayrollRole.fromMap(Map<String, dynamic> m) => PayrollRole(
    role: m['role'] ?? '',
    rate: (m['rate'] as num?)?.toDouble() ?? 0,
    count: (m['count'] as num?)?.toDouble() ?? 0,
  );
  Map<String, dynamic> toMap() => {'role': role, 'rate': rate, 'count': count};
}

class PayrollDeduction {
  final String label;
  final double amount;
  PayrollDeduction({required this.label, required this.amount});
  factory PayrollDeduction.fromMap(Map<String, dynamic> m) => PayrollDeduction(
    label: m['label'] ?? '',
    amount: (m['amount'] as num?)?.toDouble() ?? 0,
  );
  Map<String, dynamic> toMap() => {'label': label, 'amount': amount};
}

class TeacherPayrollModel {
  final String id;
  final String teacherName;
  final String? teacherId;
  final List<PayrollRole> roles;
  final List<PayrollDeduction> deductions;
  final double totalSessions;
  final double totalAmount;
  final double totalDeductions;
  final String? dateFrom;
  final String? dateTo;
  final String? weekLabel;
  final String? note;
  final String status;
  final String createdAt;
  TeacherPayrollModel({required this.id, required this.teacherName, this.teacherId,
    required this.roles, required this.deductions,
    this.totalSessions = 0, this.totalAmount = 0, this.totalDeductions = 0,
    this.dateFrom, this.dateTo, this.weekLabel, this.note,
    required this.status, required this.createdAt});
  bool get isPaid => status == 'paid';
  factory TeacherPayrollModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TeacherPayrollModel(
      id: doc.id,
      teacherName: d['teacherName'] ?? '',
      teacherId: d['teacherId'],
      roles: (d['roles'] as List<dynamic>? ?? []).map((r) => PayrollRole.fromMap(r as Map<String, dynamic>)).toList(),
      deductions: (d['deductions'] as List<dynamic>? ?? []).map((r) => PayrollDeduction.fromMap(r as Map<String, dynamic>)).toList(),
      totalSessions: (d['totalSessions'] as num?)?.toDouble() ?? 0,
      totalAmount: (d['totalAmount'] as num?)?.toDouble() ?? 0,
      totalDeductions: (d['totalDeductions'] as num?)?.toDouble() ?? 0,
      dateFrom: d['dateFrom'], dateTo: d['dateTo'],
      weekLabel: d['weekLabel'], note: d['note'],
      status: d['status'] ?? 'pending',
      createdAt: d['createdAt'] ?? '',
    );
  }
}

class AdminPayrollModel {
  final String id;
  final String adminName;
  final List<PayrollRole> roles;
  final List<PayrollDeduction> deductions;
  final double totalAmount;
  final double totalDeductions;
  final String? dateFrom;
  final String? dateTo;
  final String? weekLabel;
  final String? note;
  final String status;
  final String createdAt;
  AdminPayrollModel({required this.id, required this.adminName,
    required this.roles, required this.deductions,
    this.totalAmount = 0, this.totalDeductions = 0,
    this.dateFrom, this.dateTo, this.weekLabel, this.note,
    required this.status, required this.createdAt});
  bool get isPaid => status == 'paid';
  factory AdminPayrollModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AdminPayrollModel(
      id: doc.id,
      adminName: d['adminName'] ?? '',
      roles: (d['roles'] as List<dynamic>? ?? []).map((r) => PayrollRole.fromMap(r as Map<String, dynamic>)).toList(),
      deductions: (d['deductions'] as List<dynamic>? ?? []).map((r) => PayrollDeduction.fromMap(r as Map<String, dynamic>)).toList(),
      totalAmount: (d['totalAmount'] as num?)?.toDouble() ?? 0,
      totalDeductions: (d['totalDeductions'] as num?)?.toDouble() ?? 0,
      dateFrom: d['dateFrom'], dateTo: d['dateTo'],
      weekLabel: d['weekLabel'], note: d['note'],
      status: d['status'] ?? 'pending',
      createdAt: d['createdAt'] ?? '',
    );
  }
}
