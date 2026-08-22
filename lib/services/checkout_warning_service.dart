import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/attendance.dart';
import '../models/event.dart';
import '../theme/app_theme.dart';
import 'attendance_service.dart';
import 'notification_service.dart';

class PendingCheckout {
  final Event event;
  final Attendance attendance;
  final DateTime targetCheckoutTime;
  final String sessionName;

  PendingCheckout(this.event, this.attendance, this.targetCheckoutTime, this.sessionName);
}

class CheckoutWarningService {
  /// Checks if any event requires a check-out warning.
  /// If so, it returns the `PendingCheckout`.
  static PendingCheckout? checkPendingCheckout(
    List<Attendance> attendanceList,
    Map<String, Event> eventsMap,
  ) {
    for (final att in attendanceList) {
      final event = eventsMap[att.eventId];
      if (event == null || event.status == 'completed' || event.status == 'archived') continue;

      // Check Morning Session
      if (att.timeInAm != null && att.timeOutAm == null) {
        final targetOut = AttendanceService.parseTimeFlexible(event.morningTimeOut, event.date) 
                       ?? AttendanceService.parseTimeFlexible(event.endTime, event.date);
        
        if (targetOut != null) {
          return PendingCheckout(event, att, targetOut, 'Morning');
        }
      }

      // Check Afternoon Session
      if (att.timeInPm != null && att.timeOutPm == null) {
        final targetOut = AttendanceService.parseTimeFlexible(event.afternoonTimeOut, event.date)
                       ?? AttendanceService.parseTimeFlexible(event.endTime, event.date);
        
        if (targetOut != null) {
          return PendingCheckout(event, att, targetOut, 'Afternoon');
        }
      }
    }
    return null;
  }

  /// Processes the warning: Schedules a local notification and optionally returns a Modal widget
  static Widget? processWarning(BuildContext context, PendingCheckout pending) {
    final now = DateTime.now();

    // Schedule local notification 
    // It is safe to call this repeatedly, flutter_local_notifications will just overwrite the same ID
    NotificationService.scheduleCheckoutReminder(
      id: pending.event.id.hashCode,
      eventName: pending.event.eventName,
      targetCheckoutTime: pending.targetCheckoutTime,
    );

    // Should we show the In-App Modal?
    // Show if we have passed the target checkout time and they still haven't checked out
    if (now.isAfter(pending.targetCheckoutTime) && now.isBefore(pending.targetCheckoutTime.add(const Duration(hours: 4)))) {
      return _buildWarningBanner(pending);
    }

    return null;
  }

  static Widget _buildWarningBanner(PendingCheckout pending) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TraceColors.error,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: TraceColors.error.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TraceColors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: TraceColors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHECK-OUT REQUIRED!',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: TraceColors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your ${pending.sessionName} session for "${pending.event.eventName}" has ended, but you have not logged out yet. Please Time-Out immediately to avoid being marked as Incomplete!',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: TraceColors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
