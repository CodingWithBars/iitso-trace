import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/event_service.dart';
import '../../models/event.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import 'package:intl/intl.dart';

class AttendanceEventsScreen extends StatelessWidget {
  const AttendanceEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: const TraceAppBar(title: 'Attendance Report'),
      body: FutureBuilder<List<Event>>(
        future: EventService.getAllEvents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: TraceColors.navyBlue),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading events',
                style: GoogleFonts.inter(color: TraceColors.error),
              ),
            );
          }

          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return Center(
              child: Text(
                'No events found.',
                style: GoogleFonts.inter(color: TraceColors.medGrey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TraceCard(
                  onTap: () => context.push('/admin/attendance/${event.id}'),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.eventName,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: TraceColors.navyBlue,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 14,
                                      color: TraceColors.gold,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormat(
                                        'MMM dd, yyyy',
                                      ).format(event.date),
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: TraceColors.medGrey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: TraceColors.gold,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${event.startTime} - ${event.endTime}',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: TraceColors.medGrey,
                                      ),
                                    ),
                                  ],
                                ),
                                if (event.venue.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: TraceColors.gold,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        event.venue,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: TraceColors.medGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          StatusChip(
                            label: _getDynamicStatus(event),
                            color: _getStatusColor(_getDynamicStatus(event)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: TraceColors.lightGrey),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _AttendanceCount(eventId: event.id),
                          Row(
                            children: [
                              Text(
                                'View Details',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: TraceColors.navyBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: TraceColors.navyBlue,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getDynamicStatus(Event event) {
    if (event.status.toLowerCase() == 'completed') return 'COMPLETED';
    final now = DateTime.now();

    DateTime? endTime;
    if (event.endTime != null && event.endTime!.isNotEmpty) {
      try {
        final t = DateFormat('h:mm a').parse(event.endTime!);
        endTime = DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
          t.hour,
          t.minute,
        );
      } catch (_) {
        try {
          final t = DateFormat('HH:mm').parse(event.endTime!);
          endTime = DateTime(
            event.date.year,
            event.date.month,
            event.date.day,
            t.hour,
            t.minute,
          );
        } catch (_) {}
      }
    }

    if (endTime != null && now.isAfter(endTime.add(const Duration(hours: 1)))) {
      return 'COMPLETED';
    }

    final isToday =
        event.date.year == now.year &&
        event.date.month == now.month &&
        event.date.day == now.day;
    if (isToday) return 'ONGOING';

    if (now.isAfter(event.date)) return 'COMPLETED';

    return 'UPCOMING';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ongoing':
        return TraceColors.success;
      case 'upcoming':
        return TraceColors.royalBlue;
      case 'completed':
        return TraceColors.medGrey;
      default:
        return TraceColors.medGrey;
    }
  }
}

class _AttendanceCount extends StatelessWidget {
  final String eventId;
  const _AttendanceCount({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseFirestore.instance
          .collection('attendance')
          .where('event_id', isEqualTo: eventId)
          .get(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return Text(
            'Attended: ...',
            style: GoogleFonts.inter(fontSize: 14, color: TraceColors.medGrey),
          );
        }

        final attendedCount = snapshot.data!.docs
            .map((d) => (d.data() as Map<String, dynamic>)['student_id'])
            .toSet()
            .length;

        return Text(
          'Attended: $attendedCount',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: TraceColors.navyBlue,
            fontWeight: FontWeight.w600,
          ),
        );
      },
    );
  }
}
