import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';
import '../../services/event_service.dart';
import '../../models/attendance.dart';
import '../../models/event.dart';
import '../../widgets/shared_widgets.dart';

class AdminStudentProfileScreen extends StatelessWidget {
  final String studentId;

  const AdminStudentProfileScreen({super.key, required this.studentId});

  ImageProvider? _getAvatarProvider(String url) {
    if (url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.split(',').last;
        return MemoryImage(base64Decode(base64Str));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: AppBar(
        backgroundColor: TraceColors.navyBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: TraceColors.white,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Student Profile',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: TraceColors.white,
          ),
        ),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirestoreService.db
            .collection('students')
            .where('student_id', isEqualTo: studentId)
            .limit(1)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Student not found.'));
          }

          final studentData =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final name = studentData['name'] ?? 'Unknown';
          final course = studentData['course'] ?? '';
          final year = studentData['year_level'] ?? '';
          final email = studentData['email'] ?? 'No email';
          final avatarUrl = studentData['avatar_url'] ?? '';
          final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar Profile Header
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: TraceColors.royalBlue.withValues(alpha: 0.1),
                    backgroundImage: _getAvatarProvider(avatarUrl),
                    child: avatarUrl.isEmpty
                        ? Text(
                            initials,
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: TraceColors.royalBlue,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: TraceColors.navyBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '$course | $year | $studentId',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: TraceColors.medGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  email,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: TraceColors.medGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Obligations Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Financial Obligations',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: TraceColors.navyBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildObligationsList(),
                
                const SizedBox(height: 32),
                
                // Attendance Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Attendance History',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: TraceColors.navyBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildAttendanceList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildObligationsList() {
    return FutureBuilder<QuerySnapshot>(
      future: FirestoreService.db
          .collection('student_obligations')
          .where('student_id', isEqualTo: studentId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'No financial obligations found.',
              style: GoogleFonts.inter(color: TraceColors.medGrey),
              textAlign: TextAlign.center,
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Obligation';
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final amountPaid = (data['amount_paid'] as num?)?.toDouble() ?? 0.0;
            final status = data['status'] ?? 'unpaid';

            Color statusColor;
            switch (status) {
              case 'paid':
                statusColor = TraceColors.success;
                break;
              case 'partially_paid':
                statusColor = TraceColors.warning;
                break;
              default:
                statusColor = TraceColors.error;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: TraceColors.navyBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱${amountPaid.toStringAsFixed(2)} / ₱${amount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            color: TraceColors.medGrey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes.remainder(60);
    if (hours == 0 && mins == 0) return '0h';
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  String _fmt(DateTime t) {
    return DateFormat('hh:mm a').format(t);
  }

  void _showAttendanceDetails(BuildContext context, Attendance a, Event? event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final det = DetailedAttendance.calculate(a, event);

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: TraceColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TraceColors.lightGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                a.eventName,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: TraceColors.navyBlue,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Overall Status:',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: TraceColors.medGrey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusChip.fromStatus(det.overallStatus),
                ],
              ),
              const SizedBox(height: 24),
              if (det.sessions.isNotEmpty) ...[
                Text(
                  'Attendance Logs',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TraceColors.navyBlue,
                  ),
                ),
                const SizedBox(height: 12),
                ...det.sessions.map((s) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TraceColors.offWhite,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: TraceColors.lightGrey.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${s.label} Session',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: TraceColors.navyBlue,
                              ),
                            ),
                            StatusChip.fromStatus(s.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildTimeRow('Time In:', s.timeIn),
                        _buildTimeRow('Time Out:', s.timeOut),
                      ],
                    ),
                  );
                }),
              ],
              if (det.sessions.isEmpty)
                Text(
                  'No time records available.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: TraceColors.medGrey,
                  ),
                ),
              const SizedBox(height: 16),
              const Divider(color: TraceColors.lightGrey),
              const SizedBox(height: 16),
              Text(
                'Duration Summary',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: TraceColors.navyBlue,
                ),
              ),
              const SizedBox(height: 12),
              _buildDurationRow(
                'Total Event Duration:',
                det.totalEventDuration,
                TraceColors.medGrey,
              ),
              _buildDurationRow(
                'Completed Hours:',
                det.completedDuration,
                TraceColors.success,
              ),
              _buildDurationRow(
                'Missed Hours:',
                det.missedDuration,
                TraceColors.error,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDurationRow(String label, Duration duration, Color color) {
    final hours = duration.inHours;
    final mins = duration.inMinutes.remainder(60);
    final text = '${hours}h ${mins}m';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 14, color: TraceColors.medGrey),
          ),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(String label, DateTime? time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 14, color: TraceColors.medGrey),
          ),
          Text(
            time != null ? _fmt(time) : '--:--',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: TraceColors.navyBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    return FutureBuilder(
      future: Future.wait([
        StudentService.getAttendanceForStudent(studentId),
        EventService.getAllEvents(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading attendance: ${snapshot.error}',
              style: GoogleFonts.inter(color: TraceColors.error),
            ),
          );
        }

        final data = snapshot.data as List;
        final attendances = data[0] as List<Attendance>;
        final eventsList = data[1] as List<Event>;
        final eventsMap = {for (var e in eventsList) e.id: e};

        if (attendances.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'No attendance records found.',
              style: GoogleFonts.inter(color: TraceColors.medGrey),
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: attendances.length,
          itemBuilder: (ctx, i) {
            final a = attendances[i];
            final event = eventsMap[a.eventId];
            final eventName = event?.eventName ?? a.eventName;

            final det = DetailedAttendance.calculate(a, event);

            return GestureDetector(
              onTap: () => _showAttendanceDetails(context, a, event),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          eventName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: TraceColors.navyBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip.fromStatus(det.overallStatus),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TraceColors.navyBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time Spent',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: TraceColors.medGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(det.completedDuration),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: TraceColors.success,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Missed',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: TraceColors.medGrey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(det.missedDuration),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: det.missedDuration.inMinutes > 0
                                    ? TraceColors.error
                                    : TraceColors.success,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
          },
        );
      },
    );
  }
}
