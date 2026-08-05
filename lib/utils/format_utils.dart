import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FormatUtils {
  static String formatAmount(double val) {
    return NumberFormat('#,##0.00', 'en_US').format(val);
  }

  static String? formatTimeOfDay(TimeOfDay? t) {
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  static TimeOfDay? parseTimeOfDay(String? s) {
    if (s == null || s.isEmpty || !s.contains(':')) return null;
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static TimeOfDay? shiftTime(TimeOfDay? base, int deltaMinutes) {
    if (base == null) return null;
    final total = base.hour * 60 + base.minute + deltaMinutes;
    if (total < 0) return const TimeOfDay(hour: 0, minute: 0);
    if (total > 24 * 60 - 1) return const TimeOfDay(hour: 23, minute: 59);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }
}
