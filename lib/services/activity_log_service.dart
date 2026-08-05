import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

/// Writes a single structured entry to the `activity_logs` Firestore collection.
/// The log stream is displayed on the Admin Dashboard Overview.
class ActivityLogService {
  static const _col = 'activity_logs';

  static Future<void> log({
    required String action,
    required String message,
    String? entityType,
    String? entityId,
    String? actorName,
  }) async {
    try {
      String resolvedActor = actorName ?? 'System';
      final email = FirebaseAuth.instance.currentUser?.email;

      if (email != null && email.isNotEmpty) {
        if (resolvedActor == 'Admin' ||
            resolvedActor == 'System' ||
            resolvedActor == 'Scanner') {
          resolvedActor = email;
        } else if (resolvedActor != email && !resolvedActor.contains(email)) {
          // If the actor is something else, maybe append the email for clarity
          // But actually, just leave it as is if it's a student's name doing self-registration.
          // Wait, self-registration doesn't have an admin logged in.
        }
      }

      await FirestoreService.db.collection(_col).add({
        'action': action,
        'message': message,
        'entity_type': entityType ?? '',
        'entity_id': entityId ?? '',
        'actor_name': resolvedActor,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Logging should never crash the app
    }
  }

  /// Streams the 50 most recent log entries, newest first.
  static Stream<QuerySnapshot> stream() => FirestoreService.db
      .collection(_col)
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots();
}
