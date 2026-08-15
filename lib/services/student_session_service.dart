import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';
import 'offline_cache_service.dart';

final studentSessionProvider =
    AsyncNotifierProvider<StudentSessionNotifier, String?>(
      () => StudentSessionNotifier(),
    );

class StudentSessionNotifier extends AsyncNotifier<String?> {
  static const String _keyStudentId = 'trace_student_id';

  @override
  Future<String?> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyStudentId);
  }

  /// Persists the session and caches the student profile + pin hash
  /// so offline re-login works without internet.
  Future<void> login(String id, {Student? student, String? pinHash}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStudentId, id);
    state = AsyncData(id);

    // Persist profile for offline login fallback
    if (student != null && pinHash != null) {
      await OfflineCacheService.saveStudentProfile(student, pinHash);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStudentId);
    state = const AsyncData(null);

    // Note: We intentionally keep the cached profile so the student
    // can still log in offline next time without credentials.
    // If you want to fully clear on logout, uncomment:
    // final studentId = prefs.getString(_keyStudentId); // read before remove
    // await prefs.remove(_keyStudentId);
    // await OfflineCacheService.clearStudentProfile(studentId ?? '');
  }
}
