class Attendance {
  final String id;
  final String eventId;
  final String eventName;
  final String studentId;
  final DateTime date;

  // Restored AM/PM scan phases
  final DateTime? timeInAm;
  final DateTime? timeOutAm;
  final DateTime? timeInPm;
  final DateTime? timeOutPm;

  final String finalStatus;

  Attendance({
    required this.id,
    required this.eventId,
    this.eventName = 'Unknown Event',
    required this.studentId,
    required this.date,
    this.timeInAm,
    this.timeOutAm,
    this.timeInPm,
    this.timeOutPm,
    required this.finalStatus,
  });

  factory Attendance.fromMap(Map<String, dynamic> data, String documentId) {
    return Attendance(
      id: documentId,
      eventId: data['event_id'] ?? '',
      eventName: data['event_name'] ?? 'Unknown Event',
      studentId: data['student_id'] ?? '',
      date: data['date'] != null
          ? (data['date'] as dynamic).toDate()
          : DateTime.now(),
      timeInAm: data['time_in_am'] != null
          ? (data['time_in_am'] as dynamic).toDate()
          : null,
      timeOutAm: data['time_out_am'] != null
          ? (data['time_out_am'] as dynamic).toDate()
          : null,
      timeInPm: data['time_in_pm'] != null
          ? (data['time_in_pm'] as dynamic).toDate()
          : null,
      timeOutPm: data['time_out_pm'] != null
          ? (data['time_out_pm'] as dynamic).toDate()
          : null,
      finalStatus: data['final_status'] ?? 'Incomplete',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'event_name': eventName,
      'student_id': studentId,
      'date': date,
      'time_in_am': timeInAm,
      'time_out_am': timeOutAm,
      'time_in_pm': timeInPm,
      'time_out_pm': timeOutPm,
      'final_status': finalStatus,
    };
  }
}
