class Event {
  final String id; // Firestore document ID
  final String eventName;
  final String description;
  final String venue;
  final DateTime date;
  final DateTime? cutOffTime;
  final bool timeInClosed;

  final String status; // 'upcoming', 'ongoing', 'completed', 'cancelled'
  final String bannerUrl;

  // Scheduled base times (stored as "HH:mm" strings)
  final String? startTime;
  final String? endTime;

  final bool isWholeDay;
  final bool isPmOnly;
  final bool isAmOnly;

  final String? morningTimeIn;
  final String? morningTimeOut;
  final String? afternoonTimeIn;
  final String? afternoonTimeOut;

  Event({
    required this.id,
    required this.eventName,
    required this.description,
    required this.venue,
    required this.date,
    this.cutOffTime,
    this.timeInClosed = false,
    required this.status,
    required this.bannerUrl,
    this.startTime,
    this.endTime,
    this.isWholeDay = false,
    this.isPmOnly = false,
    this.isAmOnly = false,
    this.morningTimeIn,
    this.morningTimeOut,
    this.afternoonTimeIn,
    this.afternoonTimeOut,
  });

  factory Event.fromMap(Map<String, dynamic> data, String documentId) {
    return Event(
      id: documentId,
      eventName: data['event_name'] ?? '',
      description: data['description'] ?? '',
      venue: data['venue'] ?? '',
      date: data['date'] != null
          ? (data['date'] as dynamic).toDate()
          : DateTime.now(),
      cutOffTime: data['cut_off_time'] != null
          ? (data['cut_off_time'] as dynamic).toDate()
          : null,
      timeInClosed: data['time_in_closed'] ?? false,
      status: data['status'] ?? 'upcoming',
      bannerUrl: data['banner_url'] ?? '',
      startTime: data['start_time'],
      endTime: data['end_time'],
      isWholeDay: data['is_whole_day'] ?? false,
      isPmOnly: data['is_pm_only'] ?? false,
      isAmOnly: data['is_am_only'] ?? false,
      morningTimeIn: data['morning_time_in'],
      morningTimeOut: data['morning_time_out'],
      afternoonTimeIn: data['afternoon_time_in'],
      afternoonTimeOut: data['afternoon_time_out'],
    );
  }

  String get computedStatus {
    if (status == 'completed' || status == 'cancelled') return status;

    final endStr = endTime;
    final startStr = startTime;

    if (endStr == null || endStr.isEmpty) return status;

    try {
      final endParts = endStr.split(':');
      final endHour = int.parse(endParts[0]);
      final endMinute = int.parse(endParts[1]);
      final endDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        endHour,
        endMinute,
      );

      final now = DateTime.now();

      if (now.isAfter(endDateTime)) {
        return 'completed';
      }

      if (startStr != null && startStr.isNotEmpty) {
        final startParts = startStr.split(':');
        final startHour = int.parse(startParts[0]);
        final startMinute = int.parse(startParts[1]);
        final startDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          startHour,
          startMinute,
        );

        if (now.isAfter(startDateTime) && now.isBefore(endDateTime)) {
          return 'ongoing';
        }
      }
    } catch (_) {}

    return status;
  }

  Map<String, dynamic> toMap() {
    return {
      'event_name': eventName,
      'description': description,
      'venue': venue,
      'date': date,
      'cut_off_time': cutOffTime,
      'time_in_closed': timeInClosed,
      'status': status,
      'banner_url': bannerUrl,
      'start_time': startTime,
      'end_time': endTime,
      'is_whole_day': isWholeDay,
      'is_pm_only': isPmOnly,
      'is_am_only': isAmOnly,
      'morning_time_in': morningTimeIn,
      'morning_time_out': morningTimeOut,
      'afternoon_time_in': afternoonTimeIn,
      'afternoon_time_out': afternoonTimeOut,
    };
  }
}
