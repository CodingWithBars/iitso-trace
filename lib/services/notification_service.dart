import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

/// Background message handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'trace_high_importance',
    'Trace Notifications',
    description: 'Important notifications from the Trace app',
    importance: Importance.max,
    playSound: true,
  );

  /// Call once at app startup from main.dart
  static Future<void> initialize() async {
    if (kIsWeb) return; // FCM web setup differs

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Android local notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);

    // Init local notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(settings: initSettings);

    // Show notification on foreground message
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _showLocalNotification(
          title: notification.title ?? 'Trace',
          body: notification.body ?? '',
          payload: message.data['route'],
        );
      }
    });
  }

  /// Save the device FCM token to Firestore for push targeting.
  /// Call after a student or admin logs in.
  static Future<void> saveToken({
    required String userId,
    required String role, // 'student' | 'admin'
  }) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await FirestoreService.db.collection('fcm_tokens').doc(userId).set({
        'token': token,
        'role': role,
        'updated_at': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  /// Remove token on logout
  static Future<void> clearToken(String userId) async {
    try {
      await FirestoreService.db.collection('fcm_tokens').doc(userId).delete();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Topic-based subscriptions (students subscribe; admin subscribes to admin topic)
  // ---------------------------------------------------------------------------

  /// Student subscribes to their notification topics.
  static Future<void> subscribeStudent() async {
    await _messaging.subscribeToTopic('students');
    await _messaging.subscribeToTopic('events');
    await _messaging.subscribeToTopic('announcements');
  }

  /// Admin subscribes to admin-only topic.
  static Future<void> subscribeAdmin() async {
    await _messaging.subscribeToTopic('admin');
    await _messaging.subscribeToTopic('claims');
  }

  static Future<void> unsubscribeAll() async {
    for (final topic in [
      'students',
      'events',
      'announcements',
      'admin',
      'claims',
    ]) {
      await _messaging.unsubscribeFromTopic(topic);
    }
  }

  // ---------------------------------------------------------------------------
  // Local notification display (foreground)
  // ---------------------------------------------------------------------------
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // ---------------------------------------------------------------------------
  // Helper: send in-app notification record to Firestore (for inbox)
  // Called by server or admin actions to notify students/admins
  // ---------------------------------------------------------------------------
  static Future<void> createInAppNotification({
    required String title,
    required String body,
    required String targetRole, // 'student' | 'admin' | 'all'
    String? entityType,
    String? entityId,
    String? route,
  }) async {
    await FirestoreService.db.collection('notifications').add({
      'title': title,
      'body': body,
      'target_role': targetRole,
      'entity_type': entityType ?? '',
      'entity_id': entityId ?? '',
      'route': route ?? '',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
