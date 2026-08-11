import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student.dart';
import '../models/event.dart';
import '../models/attendance.dart';
import 'auth_service.dart';
import 'activity_log_service.dart';

enum ScanPhase { timeInAm, timeOutAm, timeInPm, timeOutPm }

extension ScanPhaseExt on ScanPhase {
  String get label {
    switch (this) {
      case ScanPhase.timeInAm:
        return 'Morning In';
      case ScanPhase.timeOutAm:
        return 'Morning Out';
      case ScanPhase.timeInPm:
        return 'Afternoon In';
      case ScanPhase.timeOutPm:
        return 'Afternoon Out';
    }
  }

  String get field {
    switch (this) {
      case ScanPhase.timeInAm:
        return 'time_in_am';
      case ScanPhase.timeOutAm:
        return 'time_out_am';
      case ScanPhase.timeInPm:
        return 'time_in_pm';
      case ScanPhase.timeOutPm:
        return 'time_out_pm';
    }
  }
}

enum ScanResultStatus {
  timeInSuccess,
  timeOutSuccess,
  alreadyTimedIn,
  alreadyTimedOut,
  lateEntry,
  attendanceComplete,
  studentNotFound,
  eventNotActive,
  error,
}

class ScanResult {
  final ScanResultStatus status;
  final String? studentName;
  final String? studentId;
  final String? studentAvatarUrl;
  final DateTime? timestamp;
  final String? message;
  final String? attendanceDocId;

  ScanResult({
    required this.status,
    this.studentName,
    this.studentId,
    this.studentAvatarUrl,
    this.timestamp,
    this.message,
    this.attendanceDocId,
  });
}

class AttendanceService {
  static Future<ScanResult> processScan({
    required String qrHash,
    required Event event,
    required ScanPhase phase,
    bool isOfflineMode = false,
    List<Student>? offlineStudents,
    Map<String, Map<String, dynamic>>? offlineAttendance,
  }) async {
    try {
      Student? student;
      Map<String, dynamic>? attendanceData;
      String? attendanceDocId;

      if (isOfflineMode && offlineStudents != null) {
        final matches = offlineStudents
            .where((s) => s.qrHash == qrHash)
            .toList();
        if (matches.isEmpty) {
          return ScanResult(status: ScanResultStatus.studentNotFound);
        }
        student = matches.first;

        if (offlineAttendance != null) {
          final existingKey = offlineAttendance.keys.firstWhere(
            (k) => offlineAttendance[k]?['student_id'] == student!.id,
            orElse: () => '',
          );
          if (existingKey.isNotEmpty) {
            attendanceDocId = existingKey;
            attendanceData = offlineAttendance[existingKey];
          }
        }
      } else {
        // 1. Find student by QR hash
        final studentSnap = await FirestoreService.students
            .where('qr_hash', isEqualTo: qrHash)
            .limit(1)
            .get();

        if (studentSnap.docs.isEmpty) {
          return ScanResult(status: ScanResultStatus.studentNotFound);
        }

        student = Student.fromMap(
          studentSnap.docs.first.data() as Map<String, dynamic>,
          studentSnap.docs.first.id,
        );

        // 2. Get or create attendance record
        final attendanceSnap = await FirestoreService.attendance
            .where('event_id', isEqualTo: event.id)
            .where('student_id', isEqualTo: student.id)
            .limit(1)
            .get();

        if (attendanceSnap.docs.isNotEmpty) {
          attendanceDocId = attendanceSnap.docs.first.id;
          attendanceData =
              attendanceSnap.docs.first.data() as Map<String, dynamic>;
        }
      }

      final now = DateTime.now();
      final isLate =
          event.timeInClosed ||
          (event.cutOffTime != null && now.isAfter(event.cutOffTime!));

      if (attendanceData == null) {
        // First scan — create record
        if (phase == ScanPhase.timeOutAm) {
          return ScanResult(
            status: ScanResultStatus.error,
            studentName: student.name,
            studentAvatarUrl: student.avatarUrl,
            message: 'No Morning In record found. Please Time-In first.',
          );
        }
        if (phase == ScanPhase.timeOutPm) {
          return ScanResult(
            status: ScanResultStatus.error,
            studentName: student.name,
            studentAvatarUrl: student.avatarUrl,
            message: 'No Afternoon In record found. Please Time-In first.',
          );
        }

        final newData = {
          'event_id': event.id,
          'student_id': student.id,
          'student_name': student.name,
          'event_name': event.eventName,
          phase.field: Timestamp.fromDate(now),
          'final_status': _computeStatus(phase, now, event),
          'created_at': FieldValue.serverTimestamp(),
          'is_offline_scan': isOfflineMode,
        };

        String newDocId = '';
        if (isOfflineMode) {
          final newDocRef = FirestoreService.attendance.doc();
          newDocId = newDocRef.id;
          if (offlineAttendance != null) offlineAttendance[newDocId] = newData;
          newDocRef.set(newData); // Fire and forget
        } else {
          final newDocRef = await FirestoreService.attendance.add(newData);
          newDocId = newDocRef.id;
          await ActivityLogService.log(
            action: 'attendance_scan',
            message:
                '${student.name} scanned for ${phase.label} (${event.eventName})',
            entityType: 'attendance',
            entityId: newDocId,
            actorName: 'Scanner',
          );
        }

        return ScanResult(
          status: isLate
              ? ScanResultStatus.lateEntry
              : ScanResultStatus.timeInSuccess,
          studentName: student.name,
          studentId: student.studentId,
          studentAvatarUrl: student.avatarUrl,
          timestamp: now,
          attendanceDocId: newDocId,
        );
      }

      if (attendanceData[phase.field] != null) {
        return ScanResult(
          status: (phase == ScanPhase.timeInAm || phase == ScanPhase.timeInPm)
              ? ScanResultStatus.alreadyTimedIn
              : ScanResultStatus.alreadyTimedOut,
          studentName: student.name,
          studentId: student.studentId,
          studentAvatarUrl: student.avatarUrl,
          timestamp: (attendanceData[phase.field] as Timestamp).toDate(),
          attendanceDocId: attendanceDocId,
        );
      }

      // Check if all required slots complete
      final updatedData = {
        ...attendanceData,
        phase.field: Timestamp.fromDate(now),
      };
      final finalStatus = _computeStatusFromData(
        updatedData,
        phase,
        now,
        event,
      );
      updatedData['final_status'] = finalStatus;

      final updateFields = {
        phase.field: Timestamp.fromDate(now),
        'final_status': finalStatus,
        if (isOfflineMode) 'is_offline_scan': true,
      };

      if (isOfflineMode) {
        if (offlineAttendance != null) {
          offlineAttendance[attendanceDocId!] = updatedData;
        }
        FirestoreService.attendance
            .doc(attendanceDocId)
            .update(updateFields); // Fire and forget
      } else {
        await FirestoreService.attendance
            .doc(attendanceDocId)
            .update(updateFields);
        await ActivityLogService.log(
          action: 'attendance_scan',
          message:
              '${student.name} scanned for ${phase.label} (${event.eventName})',
          entityType: 'attendance',
          entityId: attendanceDocId,
          actorName: 'Scanner',
        );
      }

      final isComplete = _isAttendanceComplete(updatedData, event);

      return ScanResult(
        status: isComplete
            ? ScanResultStatus.attendanceComplete
            : ((phase == ScanPhase.timeOutAm || phase == ScanPhase.timeOutPm)
                  ? ScanResultStatus.timeOutSuccess
                  : (isLate
                        ? ScanResultStatus.lateEntry
                        : ScanResultStatus.timeInSuccess)),
        studentName: student.name,
        studentId: student.studentId,
        studentAvatarUrl: student.avatarUrl,
        timestamp: now,
        attendanceDocId: attendanceDocId,
      );
    } catch (e) {
      return ScanResult(
        status: ScanResultStatus.error,
        message: 'Error processing scan: ${e.toString()}',
      );
    }
  }

  static Future<void> voidScan({
    required String attendanceDocId,
    required ScanPhase phase,
    required Event event,
    bool isOfflineMode = false,
    Map<String, Map<String, dynamic>>? offlineAttendance,
  }) async {
    if (isOfflineMode) {
      if (offlineAttendance != null &&
          offlineAttendance.containsKey(attendanceDocId)) {
        final data = offlineAttendance[attendanceDocId]!;
        data.remove(phase.field);
        data['final_status'] = _computeStatusFromData(
          data,
          phase,
          DateTime.now(),
          event,
        );
        FirestoreService.attendance.doc(attendanceDocId).update({
          phase.field: FieldValue.delete(),
          'final_status': data['final_status'],
        });
      }
      return;
    }

    final docRef = FirestoreService.attendance.doc(attendanceDocId);
    final docSnap = await docRef.get();
    if (!docSnap.exists) return;

    final data = docSnap.data() as Map<String, dynamic>;
    data.remove(phase.field);
    final finalStatus = _computeStatusFromData(
      data,
      phase,
      DateTime.now(),
      event,
    );

    await docRef.update({
      phase.field: FieldValue.delete(),
      'final_status': finalStatus,
    });

    await ActivityLogService.log(
      action: 'attendance_voided',
      message: 'Scan voided for ${phase.label} (${event.eventName})',
      entityType: 'attendance',
      entityId: attendanceDocId,
      actorName: 'Scanner',
    );
  }

  static String _computeStatus(ScanPhase phase, DateTime now, Event event) {
    if (event.timeInClosed ||
        (event.cutOffTime != null && now.isAfter(event.cutOffTime!))) {
      return 'Late';
    }
    return 'Incomplete';
  }

  static String _computeStatusFromData(
    Map<String, dynamic> data,
    ScanPhase phase,
    DateTime now,
    Event event,
  ) {
    if (_isAttendanceComplete(data, event)) return 'Present';
    return 'Incomplete';
  }

  static bool _isAttendanceComplete(Map<String, dynamic> data, Event event) {
    bool hasAmIn = data['time_in_am'] != null;
    bool hasAmOut = data['time_out_am'] != null;
    bool hasPmIn = data['time_in_pm'] != null;
    bool hasPmOut = data['time_out_pm'] != null;

    if (event.isWholeDay) {
      return hasAmIn && hasAmOut && hasPmIn && hasPmOut;
    } else if (event.isAmOnly) {
      return hasAmIn && hasAmOut;
    } else if (event.isPmOnly) {
      return hasPmIn && hasPmOut;
    }
    return false;
  }

  static Future<List<Attendance>> getEventAttendance(String eventId) async {
    final snap = await FirestoreService.attendance
        .where('event_id', isEqualTo: eventId)
        .get();
    return snap.docs
        .map((d) => Attendance.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }
}
