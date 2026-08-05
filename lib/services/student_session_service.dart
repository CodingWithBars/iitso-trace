import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> login(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStudentId, id);
    state = AsyncData(id);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStudentId);
    state = const AsyncData(null);
  }
}
