import 'package:flutter_test/flutter_test.dart';
import 'package:trace/services/attendance_service.dart';
import 'package:trace/models/event.dart';

void main() {
  group('AttendanceService Time Parsing', () {
    test('parseTimeFlexible handles 24-hr format', () {
      final base = DateTime(2025, 1, 1);
      final result = AttendanceService.parseTimeFlexible('14:30', base);
      expect(result, isNotNull);
      expect(result!.hour, 14);
      expect(result.minute, 30);
    });

    test('parseTimeFlexible handles 12-hr AM format', () {
      final base = DateTime(2025, 1, 1);
      final result = AttendanceService.parseTimeFlexible('08:15 AM', base);
      expect(result, isNotNull);
      expect(result!.hour, 8);
      expect(result.minute, 15);
    });

    test('parseTimeFlexible handles 12-hr PM format', () {
      final base = DateTime(2025, 1, 1);
      final result = AttendanceService.parseTimeFlexible('02:45 PM', base);
      expect(result, isNotNull);
      expect(result!.hour, 14);
      expect(result.minute, 45);
    });
  });

  group('AttendanceService Late Detection', () {
    final baseDate = DateTime(2025, 1, 1);
    
    test('isLateForPhase returns false if within grace period', () {
      final event = Event(
        id: '1',
        eventName: 'Test',
        description: '',
        venue: '',
        date: baseDate,
        status: 'upcoming',
        bannerUrl: '',
        morningTimeIn: '08:00',
      );

      final scanTime = DateTime(2025, 1, 1, 8, 14); // 14 mins past
      final isLate = AttendanceService.isLateForPhase(ScanPhase.timeInAm, scanTime, event);
      expect(isLate, isFalse);
    });

    test('isLateForPhase returns true if past grace period', () {
      final event = Event(
        id: '1',
        eventName: 'Test',
        description: '',
        venue: '',
        date: baseDate,
        status: 'upcoming',
        bannerUrl: '',
        morningTimeIn: '08:00',
      );

      final scanTime = DateTime(2025, 1, 1, 8, 16); // 16 mins past
      final isLate = AttendanceService.isLateForPhase(ScanPhase.timeInAm, scanTime, event);
      expect(isLate, isTrue);
    });

    test('isLateForPhase returns true if timeInClosed is true', () {
      final event = Event(
        id: '1',
        eventName: 'Test',
        description: '',
        venue: '',
        date: baseDate,
        status: 'upcoming',
        bannerUrl: '',
        morningTimeIn: '08:00',
        timeInClosed: true,
      );

      final scanTime = DateTime(2025, 1, 1, 7, 50); // Before 8:00, but closed
      final isLate = AttendanceService.isLateForPhase(ScanPhase.timeInAm, scanTime, event);
      expect(isLate, isTrue);
    });
  });

  group('AttendanceService Phase Validation', () {
    final baseDate = DateTime(2025, 1, 1);

    test('Whole day event allows all phases', () {
      final event = Event(
        id: '1',
        eventName: 'Test',
        description: '',
        venue: '',
        date: baseDate,
        status: 'upcoming',
        bannerUrl: '',
        isWholeDay: true,
      );

      expect(AttendanceService.isPhaseValidForEvent(ScanPhase.timeInAm, event), isTrue);
      expect(AttendanceService.isPhaseValidForEvent(ScanPhase.timeOutAm, event), isTrue);
      expect(AttendanceService.isPhaseValidForEvent(ScanPhase.timeInPm, event), isTrue);
      expect(AttendanceService.isPhaseValidForEvent(ScanPhase.timeOutPm, event), isTrue);
    });

    test('AM only event rejects PM phases', () {
      final event = Event(
        id: '1',
        eventName: 'Test',
        description: '',
        venue: '',
        date: baseDate,
        status: 'upcoming',
        bannerUrl: '',
        isAmOnly: true,
      );

      expect(AttendanceService.isPhaseValidForEvent(ScanPhase.timeInAm, event), isTrue);
      expect(AttendanceService.isPhaseValidForEvent(ScanPhase.timeInPm, event), isFalse);
    });
  });
}
