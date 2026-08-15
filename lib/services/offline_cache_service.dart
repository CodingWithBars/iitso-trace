import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';

/// Central offline cache service.
///
/// Stores two kinds of data in [SharedPreferences]:
///
/// 1. **Student profiles** (`_kProfilePrefix + studentId`)
///    JSON-encoded map containing all fields from [Student] plus the
///    raw `pin_hash` from Firestore.  Written on every successful login
///    and refreshed on each splash when online.
///
/// 2. **Scanner data** (`_kScannerPrefix + eventId`)
///    JSON-encoded map with a list of student records and their current
///    attendance state for a specific event.  Written when the admin
///    taps "Download Offline Data" (or auto-download) and loaded
///    automatically on scanner open.
class OfflineCacheService {
  static const String _kProfilePrefix  = 'offline_profile_';
  static const String _kScannerPrefix  = 'offline_scanner_';
  static const String _kSyncTimePrefix = 'offline_sync_';

  // ──────────────────────────────────────────────────────────────
  // STUDENT PROFILE CACHE
  // ──────────────────────────────────────────────────────────────

  /// Saves [student] data + [pinHash] so the user can log in offline.
  static Future<void> saveStudentProfile(
    Student student,
    String pinHash,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'id': student.id,
        'student_id': student.studentId,
        'name': student.name,
        'course': student.course,
        'year_level': student.yearLevel,
        'qr_hash': student.qrHash,
        'email': student.email,
        'avatar_url': student.avatarUrl,
        'is_archived': student.isArchived,
        'pin_hash': pinHash,
        'cached_at': DateTime.now().toIso8601String(),
      };
      await prefs.setString(
        '$_kProfilePrefix${student.studentId}',
        jsonEncode(map),
      );
    } catch (e) {
      debugPrint('OfflineCacheService.saveStudentProfile error: $e');
    }
  }

  /// Returns cached profile data for [studentId], or `null` if not found.
  static Future<Map<String, dynamic>?> getStudentProfile(
    String studentId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kProfilePrefix$studentId');
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('OfflineCacheService.getStudentProfile error: $e');
      return null;
    }
  }

  /// Clears cached profile for [studentId] (e.g. on explicit logout).
  static Future<void> clearStudentProfile(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kProfilePrefix$studentId');
    } catch (e) {
      debugPrint('OfflineCacheService.clearStudentProfile error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // SCANNER / EVENT DATA CACHE
  // ──────────────────────────────────────────────────────────────

  /// Persists [students] and [attendance] for [eventId].
  ///
  /// [attendance] is the same `Map<docId, data>` used by the scanner.
  static Future<void> saveOfflineScannerData({
    required String eventId,
    required List<Student> students,
    required Map<String, Map<String, dynamic>> attendance,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final studentList = students.map((s) => s.toMap()
        ..['id'] = s.id
        ..['student_id'] = s.studentId).toList();

      // Convert Timestamp-like values to ISO strings for JSON safety.
      final safeAttendance = attendance.map((docId, data) {
        final safe = data.map((key, value) {
          if (value != null && value.toString().contains('Timestamp')) {
            return MapEntry(key, value.toString());
          }
          return MapEntry(key, value);
        });
        return MapEntry(docId, safe);
      });

      final payload = {
        'students': studentList,
        'attendance': safeAttendance,
      };

      await prefs.setString(
        '$_kScannerPrefix$eventId',
        jsonEncode(payload),
      );
      await prefs.setString(
        '$_kSyncTimePrefix$eventId',
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      debugPrint('OfflineCacheService.saveOfflineScannerData error: $e');
    }
  }

  /// Returns `{students: List<Student>, attendance: Map<docId, data>}` for
  /// [eventId], or `null` if nothing was cached.
  static Future<OfflineScannerCache?> getOfflineScannerData(
    String eventId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kScannerPrefix$eventId');
      if (raw == null) return null;

      final payload = jsonDecode(raw) as Map<String, dynamic>;

      final studentList = (payload['students'] as List<dynamic>)
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return Student.fromMap(m, m['id'] as String? ?? '');
          })
          .toList();

      final attendanceMap = (payload['attendance'] as Map<String, dynamic>)
          .map((docId, data) => MapEntry(
                docId,
                Map<String, dynamic>.from(data as Map),
              ));

      return OfflineScannerCache(
        students: studentList,
        attendance: attendanceMap,
      );
    } catch (e) {
      debugPrint('OfflineCacheService.getOfflineScannerData error: $e');
      return null;
    }
  }

  /// Returns the DateTime when scanner data for [eventId] was last synced,
  /// or `null` if never cached.
  static Future<DateTime?> getLastSyncTime(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kSyncTimePrefix$eventId');
      if (raw == null) return null;
      return DateTime.parse(raw);
    } catch (e) {
      return null;
    }
  }

  /// Returns true if cached scanner data for [eventId] is older than [maxAge].
  static Future<bool> isScannerDataStale(
    String eventId, {
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final lastSync = await getLastSyncTime(eventId);
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) > maxAge;
  }

  /// Clears scanner cache for [eventId].
  static Future<void> clearOfflineScannerData(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_kScannerPrefix$eventId');
      await prefs.remove('$_kSyncTimePrefix$eventId');
    } catch (e) {
      debugPrint('OfflineCacheService.clearOfflineScannerData error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────

  /// Human-readable "synced X ago" or "synced just now" label.
  static String syncAgoLabel(DateTime syncTime) {
    final diff = DateTime.now().difference(syncTime);
    if (diff.inSeconds < 60) return 'synced just now';
    if (diff.inMinutes < 60) return 'synced ${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return 'synced ${diff.inHours}h ago';
    return 'synced ${diff.inDays}d ago';
  }
}

/// Value returned by [OfflineCacheService.getOfflineScannerData].
class OfflineScannerCache {
  final List<Student> students;
  final Map<String, Map<String, dynamic>> attendance;

  const OfflineScannerCache({
    required this.students,
    required this.attendance,
  });
}
