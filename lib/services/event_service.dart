import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event.dart';
import 'activity_log_service.dart';
import 'notification_service.dart';

class EventService {
  static Future<void> createEvent(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    if (!payload.containsKey('date'))
      payload['date'] = FieldValue.serverTimestamp();
    final docRef = await FirebaseFirestore.instance
        .collection('events')
        .add(payload);
    final name = data['event_name'] ?? 'Event';
    await ActivityLogService.log(
      action: 'event_created',
      message: 'New event created: "$name"',
      entityType: 'event',
      entityId: docRef.id,
      actorName: 'Admin',
    );
    await NotificationService.createInAppNotification(
      title: 'New Event: $name',
      body: 'A new event has been posted. Check it out!',
      targetRole: 'student',
      entityType: 'event',
      entityId: docRef.id,
      route: '/',
    );
  }

  static Future<void> updateEvent(String id, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('events').doc(id).update(data);
    final name = data['event_name'] ?? id;
    final status = data['status'];
    final logMsg = status != null
        ? 'Event "$name" status changed to: $status'
        : 'Event "$name" updated';
    await ActivityLogService.log(
      action: status != null ? 'event_status_changed' : 'event_updated',
      message: logMsg,
      entityType: 'event',
      entityId: id,
      actorName: 'Admin',
    );
    if (status != null) {
      await NotificationService.createInAppNotification(
        title: 'Event Update: $name',
        body: 'Event status changed to $status',
        targetRole: 'all',
        entityType: 'event',
        entityId: id,
      );
    }
  }

  static Future<List<Event>> getAllEvents() async {
    final snap = await FirebaseFirestore.instance
        .collection('events')
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map((doc) => Event.fromMap(doc.data(), doc.id)).toList();
  }

  static Future<void> deleteEvent(String id, String eventName) async {
    await FirebaseFirestore.instance.collection('events').doc(id).delete();
    await ActivityLogService.log(
      action: 'event_deleted',
      message: 'Event deleted: $eventName',
      entityType: 'event',
      entityId: id,
      actorName: 'Admin',
    );
  }
}
