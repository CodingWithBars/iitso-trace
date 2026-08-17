import 'package:intl/intl.dart';
import 'event.dart';

class Attendance {
  final String id;
  final String eventId;
  final String eventName;
  final String studentId;
  final DateTime date;

  // Restored AM/PM scan phases
  final DateTime? timeInAm;
  final DateTime? timeOutAm;
  final DateTime? timeInPm;
  final DateTime? timeOutPm;

  final double? manualLateHours;

  final String finalStatus;

  Attendance({
    required this.id,
    required this.eventId,
    this.eventName = 'Unknown Event',
    required this.studentId,
    required this.date,
    this.timeInAm,
    this.timeOutAm,
    this.timeInPm,
    this.timeOutPm,
    this.manualLateHours,
    required this.finalStatus,
  });

  factory Attendance.fromMap(Map<String, dynamic> data, String documentId) {
    return Attendance(
      id: documentId,
      eventId: data['event_id'] ?? '',
      eventName: data['event_name'] ?? 'Unknown Event',
      studentId: data['student_id'] ?? '',
      date: data['date'] != null
          ? (data['date'] as dynamic).toDate()
          : DateTime.now(),
      timeInAm: data['time_in_am'] != null
          ? (data['time_in_am'] as dynamic).toDate()
          : null,
      timeOutAm: data['time_out_am'] != null
          ? (data['time_out_am'] as dynamic).toDate()
          : null,
      timeInPm: data['time_in_pm'] != null
          ? (data['time_in_pm'] as dynamic).toDate()
          : null,
      timeOutPm: data['time_out_pm'] != null
          ? (data['time_out_pm'] as dynamic).toDate()
          : null,
      manualLateHours: data['manual_late_hours'] != null
          ? (data['manual_late_hours'] as num).toDouble()
          : null,
      finalStatus: data['final_status'] ?? 'Incomplete',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'event_name': eventName,
      'student_id': studentId,
      'date': date,
      'time_in_am': timeInAm,
      'time_out_am': timeOutAm,
      'time_in_pm': timeInPm,
      'time_out_pm': timeOutPm,
      if (manualLateHours != null) 'manual_late_hours': manualLateHours,
      'final_status': finalStatus,
    };
  }
}

class SessionDetails {
  final String label;
  final String status;
  final DateTime? timeIn;
  final DateTime? timeOut;

  SessionDetails({
    required this.label,
    required this.status,
    this.timeIn,
    this.timeOut,
  });
}



class DetailedAttendance {
  final String overallStatus;
  final List<SessionDetails> sessions;
  final Duration totalEventDuration;
  final Duration completedDuration;
  final Duration missedDuration;

  DetailedAttendance({
    required this.overallStatus,
    required this.sessions,
    required this.totalEventDuration,
    required this.completedDuration,
    required this.missedDuration,
  });

  static DetailedAttendance calculate(Attendance a, Event? event) {
    if (event == null) {
      return DetailedAttendance(
        overallStatus: a.finalStatus,
        sessions: [],
        totalEventDuration: Duration.zero,
        completedDuration: Duration.zero,
        missedDuration: Duration.zero,
      );
    }

    DateTime now = DateTime.now();
    DateTime eventDate = event.date;

    DateTime? parseTime(String? tStr) {
      if (tStr == null || tStr.isEmpty) return null;
      try {
        final t = DateFormat('h:mm a').parse(tStr);
        return DateTime(eventDate.year, eventDate.month, eventDate.day, t.hour, t.minute);
      } catch (_) {
        try {
          final t = DateFormat('HH:mm').parse(tStr);
          return DateTime(eventDate.year, eventDate.month, eventDate.day, t.hour, t.minute);
        } catch (_) {
          return null;
        }
      }
    }

    final scheduledAmIn = parseTime(event.morningTimeIn);
    final scheduledAmOut = parseTime(event.morningTimeOut);
    final scheduledPmIn = parseTime(event.afternoonTimeIn);
    final scheduledPmOut = parseTime(event.afternoonTimeOut);

    Duration totalEventDuration = Duration.zero;
    if (event.startTime != null && event.endTime != null && event.startTime!.isNotEmpty && event.endTime!.isNotEmpty) {
      final start = parseTime(event.startTime);
      final end = parseTime(event.endTime);
      
      if (start != null && end != null) {
        totalEventDuration = end.difference(start);
        if (totalEventDuration.isNegative) totalEventDuration += const Duration(hours: 24);

        if (event.isWholeDay && scheduledAmOut != null && scheduledPmIn != null) {
          Duration breakDuration = scheduledPmIn.difference(scheduledAmOut);
          if (!breakDuration.isNegative && breakDuration < totalEventDuration) {
            totalEventDuration -= breakDuration;
          }
        }
      }
    }

    String determineSessionStatus(DateTime? scheduledIn, DateTime? scheduledOut, DateTime? actualIn, DateTime? actualOut) {
      if (scheduledIn == null) return 'N/A';
      
      final checkOutTime = scheduledOut ?? scheduledIn.add(const Duration(hours: 4));

      if (actualIn != null) {
        if (actualOut == null && (now.isAfter(checkOutTime) || event.status == 'completed' || event.status == 'archived')) {
          return 'Void'; // Enforce accountability: no checkout = void
        }
        final diff = actualIn.difference(scheduledIn).inMinutes;
        return diff > 15 ? 'Late' : 'Present';
      }

      if (now.isAfter(checkOutTime) || event.status == 'completed' || event.status == 'archived') {
        return 'Missed';
      }
      return 'Pending';
    }

    List<SessionDetails> sessions = [];
    if (event.isWholeDay || event.isAmOnly) {
      sessions.add(SessionDetails(
        label: 'Morning',
        status: determineSessionStatus(scheduledAmIn, scheduledAmOut, a.timeInAm, a.timeOutAm),
        timeIn: a.timeInAm,
        timeOut: a.timeOutAm,
      ));
    }
    if (event.isWholeDay || event.isPmOnly) {
      sessions.add(SessionDetails(
        label: 'Afternoon',
        status: determineSessionStatus(scheduledPmIn, scheduledPmOut, a.timeInPm, a.timeOutPm),
        timeIn: a.timeInPm,
        timeOut: a.timeOutPm,
      ));
    }

    DateTime? amEnd = scheduledAmOut ?? parseTime(event.endTime);
    DateTime? pmEnd = scheduledPmOut ?? parseTime(event.endTime);

    Duration amCompleted = Duration.zero;
    if (a.timeInAm != null) {
      if (a.timeOutAm != null) {
        amCompleted = a.timeOutAm!.difference(a.timeInAm!);
      } else {
        if (amEnd != null && now.isAfter(amEnd)) {
          amCompleted = Duration.zero;
        } else {
          amCompleted = now.difference(a.timeInAm!);
        }
      }
    }
    if (amCompleted.isNegative) amCompleted = Duration.zero;

    Duration pmCompleted = Duration.zero;
    if (a.timeInPm != null) {
      if (a.timeOutPm != null) {
        pmCompleted = a.timeOutPm!.difference(a.timeInPm!);
      } else {
        if (pmEnd != null && now.isAfter(pmEnd)) {
          pmCompleted = Duration.zero;
        } else {
          pmCompleted = now.difference(a.timeInPm!);
        }
      }
    }
    if (pmCompleted.isNegative) pmCompleted = Duration.zero;

    Duration completedDuration = amCompleted + pmCompleted;
    Duration missedDuration = totalEventDuration - completedDuration;
    if (missedDuration.isNegative) missedDuration = Duration.zero;

    String computedOverallStatus = a.finalStatus;
    
    bool hasMissedSession = sessions.any((s) => s.status == 'Missed');
    bool hasLateSession = sessions.any((s) => s.status == 'Late');
    bool hasVoidSession = sessions.any((s) => s.status == 'Void');
    bool allMissed = sessions.every((s) => s.status == 'Missed');
    
    if (event.computedStatus == 'completed' || hasVoidSession) {
      if (hasVoidSession) {
        computedOverallStatus = 'Void';
      } else if (allMissed) {
        // If there are no scan timestamps, this record was manually created by an admin.
        // We must respect the manually assigned status.
        computedOverallStatus = a.finalStatus;
        if (a.finalStatus == 'Present' || a.finalStatus == 'Excused') {
          completedDuration = totalEventDuration;
          missedDuration = Duration.zero;
        } else if (a.finalStatus == 'Late' && a.manualLateHours != null) {
          missedDuration = Duration(minutes: (a.manualLateHours! * 60).round());
          completedDuration = totalEventDuration - missedDuration;
          if (completedDuration.isNegative) completedDuration = Duration.zero;
        } else if (a.finalStatus == 'Absent' || a.finalStatus == 'Incomplete') {
          missedDuration = totalEventDuration;
          completedDuration = Duration.zero;
        }
      } else if (hasMissedSession || completedDuration < totalEventDuration) {
        computedOverallStatus = 'Incomplete';
      } else if (hasLateSession) {
        computedOverallStatus = (completedDuration < totalEventDuration) ? 'Incomplete' : 'Late';
      } else {
        computedOverallStatus = 'Present';
      }
    } else {
      if (allMissed && ['Present', 'Excused', 'Late', 'Absent'].contains(a.finalStatus)) {
         computedOverallStatus = a.finalStatus;
         if (a.finalStatus == 'Present' || a.finalStatus == 'Excused') {
           completedDuration = totalEventDuration;
           missedDuration = Duration.zero;
         } else if (a.finalStatus == 'Late' && a.manualLateHours != null) {
           missedDuration = Duration(minutes: (a.manualLateHours! * 60).round());
           completedDuration = totalEventDuration - missedDuration;
           if (completedDuration.isNegative) completedDuration = Duration.zero;
         }
      } else if (hasMissedSession) {
         computedOverallStatus = 'Incomplete';
      }
    }

    return DetailedAttendance(
      overallStatus: computedOverallStatus.toUpperCase(),
      sessions: sessions,
      totalEventDuration: totalEventDuration,
      completedDuration: completedDuration,
      missedDuration: missedDuration,
    );
  }
}
