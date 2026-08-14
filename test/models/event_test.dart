import 'package:flutter_test/flutter_test.dart';
import 'package:trace/models/event.dart';

void main() {
  group('Event Model Tests', () {
    test('computedStatus returns original status if completed or cancelled', () {
      final event1 = Event(
        id: '1',
        eventName: 'Test',
        description: 'Test',
        venue: 'Test',
        date: DateTime.now(),
        status: 'completed',
        bannerUrl: '',
      );
      
      final event2 = Event(
        id: '2',
        eventName: 'Test',
        description: 'Test',
        venue: 'Test',
        date: DateTime.now(),
        status: 'cancelled',
        bannerUrl: '',
      );

      expect(event1.computedStatus, 'completed');
      expect(event2.computedStatus, 'cancelled');
    });

    test('computedStatus correctly identifies ongoing event', () {
      final now = DateTime.now();
      // Set start time to 1 hour ago, end time to 1 hour from now
      final startTimeStr = '${now.subtract(const Duration(hours: 1)).hour.toString().padLeft(2, '0')}:${now.subtract(const Duration(hours: 1)).minute.toString().padLeft(2, '0')}';
      final endTimeStr = '${now.add(const Duration(hours: 1)).hour.toString().padLeft(2, '0')}:${now.add(const Duration(hours: 1)).minute.toString().padLeft(2, '0')}';

      final event = Event(
        id: '3',
        eventName: 'Test Ongoing',
        description: '',
        venue: '',
        date: now, // Today
        status: 'upcoming',
        bannerUrl: '',
        startTime: startTimeStr,
        endTime: endTimeStr,
      );

      expect(event.computedStatus, 'ongoing');
    });

    test('computedStatus correctly identifies completed event', () {
      final now = DateTime.now();
      // Set end time to 1 hour ago
      final endTimeStr = '${now.subtract(const Duration(hours: 1)).hour.toString().padLeft(2, '0')}:${now.subtract(const Duration(hours: 1)).minute.toString().padLeft(2, '0')}';

      final event = Event(
        id: '4',
        eventName: 'Test Completed',
        description: '',
        venue: '',
        date: now, // Today
        status: 'upcoming',
        bannerUrl: '',
        endTime: endTimeStr,
      );

      expect(event.computedStatus, 'completed');
    });
  });
}
