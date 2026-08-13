import 'dart:convert';
import 'dart:io' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CsvReportService {
  static String listToCsv(List<List<dynamic>> rows) {
    return rows
        .map((row) {
          return row
              .map((item) {
                String str = item.toString();
                if (str.contains(',') ||
                    str.contains('"') ||
                    str.contains('\n')) {
                  str = '"${str.replaceAll('"', '""')}"';
                }
                return str;
              })
              .join(',');
        })
        .join('\n');
  }

  static Future<void> downloadCsv(String csvData, String fileName) async {
    if (kIsWeb) {
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      try {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/$fileName';
        final file = io.File(path);
        await file.writeAsString(csvData);
        await Share.shareXFiles([XFile(path)], text: 'CSV Report: $fileName');
      } catch (e) {
        debugPrint('Error saving CSV: $e');
      }
    }
  }

  static Future<void> generateFundsCsv(List<QueryDocumentSnapshot> docs) async {
    List<List<dynamic>> rows = [];

    // Header row
    rows.add(['Date', 'Type', 'Amount (PHP)', 'Description', 'Event ID']);

    final dateFormat = DateFormat('MM/dd/yyyy hh:mm a');

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dateStr = data['date'] != null
          ? dateFormat.format((data['date'] as Timestamp).toDate())
          : '';
      final typeStr = (data['type'] ?? '').toString().toUpperCase();
      final amt = (data['amount'] ?? 0).toDouble();
      final desc = data['description'] ?? '';
      final eventId = data['eventId'] ?? '';

      rows.add([dateStr, typeStr, amt, desc, eventId]);
    }

    String csv = listToCsv(rows);
    await downloadCsv(csv, 'Funds_Ledger_Report.csv');
  }

  static Future<void> generateAttendanceCsv(
    List<dynamic> attendanceList,
    Map<String, dynamic> studentsMap,
  ) async {
    List<List<dynamic>> rows = [];

    // Header row
    rows.add(['Time In', 'Student Name', 'Program', 'Year Level', 'Status']);

    final dateFormat = DateFormat('MM/dd/yyyy hh:mm a');

    for (var att in attendanceList) {
      final timeStr = dateFormat.format(att.timestamp);
      final studentData =
          studentsMap[att.studentId] as Map<String, dynamic>? ?? {};
      final name = studentData['name'] ?? 'Unknown';
      final program = studentData['course'] ?? '';
      final year = studentData['year_level'] ?? '';
      final status = att.status;

      rows.add([timeStr, name, program, year, status]);
    }

    String csv = listToCsv(rows);
    await downloadCsv(csv, 'Event_Attendance_Report.csv');
  }

  static double _parseTimeStr(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 0.0;
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return hour + (minute / 60.0);
    } catch (_) {
      return 0.0;
    }
  }

  static double _parseDateTime(dynamic dt) {
    if (dt == null) return 0.0;
    DateTime date;
    if (dt is Timestamp) {
      date = dt.toDate();
    } else if (dt is DateTime) {
      date = dt;
    } else {
      return 0.0;
    }
    return date.hour + (date.minute / 60.0);
  }

  static Future<void> generateSemesterReport() async {
    try {
      final studentsSnap = await FirebaseFirestore.instance
          .collection('students')
          .get();
      final eventsSnap = await FirebaseFirestore.instance
          .collection('events')
          .get();
      final attendanceSnap = await FirebaseFirestore.instance
          .collection('attendance')
          .get();

      // Calculate total event hours for the semester
      double totalEventHours = 0.0;
      for (var doc in eventsSnap.docs) {
        final data = doc.data();
        final mIn = _parseTimeStr(data['morning_time_in']);
        final mOut = _parseTimeStr(data['morning_time_out']);
        final aIn = _parseTimeStr(data['afternoon_time_in']);
        final aOut = _parseTimeStr(data['afternoon_time_out']);

        if (mOut > mIn) totalEventHours += (mOut - mIn);
        if (aOut > aIn) totalEventHours += (aOut - aIn);
      }

      // Group attendance by student
      Map<String, double> studentAttendedHours = {};
      Map<String, int> studentEventsAttended = {};

      for (var doc in attendanceSnap.docs) {
        final data = doc.data();
        final studentId = data['student_id']?.toString() ?? '';
        if (studentId.isEmpty) continue;

        final tInAm = _parseDateTime(data['time_in_am']);
        final tOutAm = _parseDateTime(data['time_out_am']);
        final tInPm = _parseDateTime(data['time_in_pm']);
        final tOutPm = _parseDateTime(data['time_out_pm']);

        double attended = 0.0;
        if (tOutAm > tInAm) attended += (tOutAm - tInAm);
        if (tOutPm > tInPm) attended += (tOutPm - tInPm);

        studentAttendedHours[studentId] =
            (studentAttendedHours[studentId] ?? 0.0) + attended;
        studentEventsAttended[studentId] =
            (studentEventsAttended[studentId] ?? 0) + 1;
      }

      List<List<dynamic>> rows = [];
      rows.add([
        'Student Name',
        'Student ID',
        'Program',
        'Year Level',
        'Events Attended',
        'Total Attended Hours',
        'Total Event Hours (Semester)',
        'Attendance Rate (%)',
      ]);

      for (var doc in studentsSnap.docs) {
        final data = doc.data();
        final sId = data['student_id']?.toString() ?? '';
        final name = data['name'] ?? 'Unknown';
        final program = data['course'] ?? '';
        final year = data['year_level'] ?? '';

        final attendedHours = studentAttendedHours[sId] ?? 0.0;
        final eventsAttended = studentEventsAttended[sId] ?? 0;

        double rate = 0.0;
        if (totalEventHours > 0) {
          rate = (attendedHours / totalEventHours) * 100;
          if (rate > 100) {
            rate = 100.0; // Cap at 100% in case they arrived early/left late
          }
        }

        rows.add([
          name,
          sId,
          program,
          year,
          eventsAttended,
          attendedHours.toStringAsFixed(2),
          totalEventHours.toStringAsFixed(2),
          '${rate.toStringAsFixed(1)}%',
        ]);
      }

      String csv = listToCsv(rows);
      await downloadCsv(csv, 'Semester_Comprehensive_Report.csv');
    } catch (e) {
      debugPrint('Error generating semester report: $e');
    }
  }
}
