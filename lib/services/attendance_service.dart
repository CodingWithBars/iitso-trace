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
  wrongPhase,
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
  /// Normalise a stored time string to DateTime on the given baseDate.
  /// Handles both "HH:mm" (24-hr) and "h:mm a" / "hh:mm a" (12-hr AM/PM).
  static DateTime? parseTimeFlexible(String? timeStr, DateTime baseDate) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final s = timeStr.trim();

    // Try 24-hr format first: "HH:mm"
    final colon = s.indexOf(':');
    if (colon > 0 && !s.contains(' ')) {
      try {
        final hour = int.parse(s.substring(0, colon));
        final minute = int.parse(s.substring(colon + 1));
        if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
          return DateTime(
            baseDate.year,
            baseDate.month,
            baseDate.day,
            hour,
            minute,
          );
        }
      } catch (_) {}
    }

    // Try 12-hr format: "h:mm a" or "hh:mm a"
    try {
      final parts = s.split(' ');
      if (parts.length >= 2) {
        final timeParts = parts[0].split(':');
        var hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final isPm = parts[1].toUpperCase() == 'PM';
        if (hour == 12) {
          hour = isPm ? 12 : 0;
        } else if (isPm) {
          hour += 12;
        }
        return DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
          hour,
          minute,
        );
      }
    } catch (_) {}

    return null;
  }

  /// Returns true if the scan at [now] is late relative to the scheduled time.
  /// Grace period: 15 minutes after the scheduled time-in.
  static bool isLateForPhase(ScanPhase phase, DateTime now, Event event) {
    // If the admin manually closed time-in, all subsequent time-in scans are late.
    if (event.timeInClosed &&
        (phase == ScanPhase.timeInAm || phase == ScanPhase.timeInPm)) {
      return true;
    }
    // Explicit cut-off time set
    if (event.cutOffTime != null &&
        now.isAfter(event.cutOffTime!) &&
        (phase == ScanPhase.timeInAm || phase == ScanPhase.timeInPm)) {
      return true;
    }

    // Check scheduled time with 15-min grace period
    if (phase == ScanPhase.timeInAm && event.morningTimeIn != null) {
      final scheduled = parseTimeFlexible(event.morningTimeIn, event.date);
      if (scheduled != null &&
          now.isAfter(scheduled.add(const Duration(minutes: 15)))) {
        return true;
      }
    } else if (phase == ScanPhase.timeInPm && event.afternoonTimeIn != null) {
      final scheduled = parseTimeFlexible(event.afternoonTimeIn, event.date);
      if (scheduled != null &&
          now.isAfter(scheduled.add(const Duration(minutes: 15)))) {
        return true;
      }
    }
    return false;
  }

  /// Validates whether the given phase is applicable for the event type.
  static bool isPhaseValidForEvent(ScanPhase phase, Event event) {
    switch (phase) {
      case ScanPhase.timeInAm:
      case ScanPhase.timeOutAm:
        return event.isWholeDay || event.isAmOnly;
      case ScanPhase.timeInPm:
      case ScanPhase.timeOutPm:
        return event.isWholeDay || event.isPmOnly;
    }
  }

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

      // --- Phase validation ---
      if (!isPhaseValidForEvent(phase, event)) {
        return ScanResult(
          status: ScanResultStatus.wrongPhase,
          message:
              'This scan phase (${phase.label}) is not applicable for this event.',
        );
      }

      if (isOfflineMode && offlineStudents != null) {
        final matches =
            offlineStudents.where((s) => s.qrHash == qrHash).toList();
        if (matches.isEmpty) {
          return ScanResult(status: ScanResultStatus.studentNotFound);
        }
        student = matches.first;

        if (offlineAttendance != null) {
          final existingKey = offlineAttendance.keys.firstWhere(
            (k) => offlineAttendance[k]?['student_id'] == student!.studentId,
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

        // Skip archived students
        if (student.isArchived) {
          return ScanResult(status: ScanResultStatus.studentNotFound);
        }

        // 2. Get or create attendance record
        final attendanceSnap = await FirestoreService.attendance
            .where('event_id', isEqualTo: event.id)
            .where('student_id', isEqualTo: student.studentId)
            .limit(1)
            .get();

        if (attendanceSnap.docs.isNotEmpty) {
          attendanceDocId = attendanceSnap.docs.first.id;
          attendanceData =
              attendanceSnap.docs.first.data() as Map<String, dynamic>;
        }
      }

      final now = DateTime.now();
      final isLate = isLateForPhase(phase, now, event);

      if (attendanceData == null) {
        // First scan — validate phase makes sense
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
          'student_id': student.studentId,
          'student_name': student.name,
          'event_name': event.eventName,
          phase.field: Timestamp.fromDate(now),
          'final_status': isLate ? 'Late' : 'Incomplete',
          'created_at': FieldValue.serverTimestamp(),
          'is_offline_scan': isOfflineMode,
        };

        final newDocId = '${event.id}_${student.studentId}';
        final newDocRef = FirestoreService.attendance.doc(newDocId);
        
        if (isOfflineMode) {
          if (offlineAttendance != null) offlineAttendance[newDocId] = newData;
          newDocRef.set(newData, SetOptions(merge: true)); // Fire and forget
        } else {
          await newDocRef.set(newData, SetOptions(merge: true));
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

      // Already has a record for this phase
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

      // Check if all required slots are now complete
      final updatedData = {
        ...attendanceData,
        phase.field: Timestamp.fromDate(now),
      };

      // Preserve any existing late status, merge with new late detection
      final previouslyLate = (attendanceData['final_status'] as String?) == 'Late';
      final nowLate = previouslyLate || (isLate && (phase == ScanPhase.timeInAm || phase == ScanPhase.timeInPm));

      final isComplete = _isAttendanceComplete(updatedData, event);
      final finalStatus = isComplete
          ? (nowLate ? 'Late' : 'Present')
          : (nowLate ? 'Late' : 'Incomplete');

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
        // Recompute status
        final wasLate = (data['final_status'] as String?) == 'Late';
        final isComplete = _isAttendanceComplete(data, event);
        data['final_status'] = isComplete
            ? (wasLate ? 'Late' : 'Present')
            : (wasLate ? 'Late' : 'Incomplete');
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

    final data = Map<String, dynamic>.from(
      docSnap.data() as Map<String, dynamic>,
    );
    data.remove(phase.field);
    final wasLate = (data['final_status'] as String?) == 'Late';
    final isComplete = _isAttendanceComplete(data, event);
    final finalStatus = isComplete
        ? (wasLate ? 'Late' : 'Present')
        : (wasLate ? 'Late' : 'Incomplete');

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
