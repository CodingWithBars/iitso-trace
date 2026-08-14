import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../models/event.dart';

class EventsTab extends StatefulWidget {
  final void Function(Event event) onEventTap;
  final VoidCallback onNewEvent;
  final String currentRole;

  const EventsTab({
    super.key,
    required this.onEventTap,
    required this.onNewEvent,
    this.currentRole = 'admin',
  });

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Ongoing', 'Upcoming', 'Completed'];

  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final dt = DateTime(2000, 1, 1, hour, minute);
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return timeStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        return Colors.green;
      case 'upcoming':
        return Colors.grey.shade600;
      case 'cancelled':
        return Colors.red;
      case 'rescheduled':
      case 're-scheduled':
        return Colors.orange;
      case 'ongoing':
        return TraceColors.gold;
      default:
        return TraceColors.navyBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAddEvent = widget.currentRole != 'scanner' && widget.currentRole != 'treasurer';
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canAddEvent ? FloatingActionButton.extended(
        onPressed: widget.onNewEvent,
        backgroundColor: TraceColors.gold,
        icon: const Icon(Icons.add_rounded, color: TraceColors.navyBlue),
        label: Text(
          'Event',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: TraceColors.navyBlue,
          ),
        ),
      ) : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Event Management',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: TraceColors.navyBlue,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage campus events and attendance tracking.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: TraceColors.medGrey,
                  ),
                ),
              ],
            ),
          ),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: _filters
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f),
                        selected: _selectedFilter == f,
                        onSelected: (val) {
                          if (val) setState(() => _selectedFilter = f);
                        },
                        backgroundColor: Colors.white,
                        selectedColor: TraceColors.navyBlue,
                        checkmarkColor: Colors.white,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: _selectedFilter == f
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _selectedFilter == f
                              ? Colors.white
                              : TraceColors.navyBlue,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _selectedFilter == f
                                ? TraceColors.navyBlue
                                : TraceColors.lightGrey,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),

          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.db
                  .collection('events')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snap.data!.docs;
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final event = Event.fromMap(data, doc.id);
                  if (_selectedFilter == 'All') return true;
                  if (_selectedFilter == 'Ongoing') {
                    return event.computedStatus == 'ongoing';
                  }
                  if (_selectedFilter == 'Upcoming') {
                    return event.computedStatus == 'upcoming';
                  }
                  if (_selectedFilter == 'Completed') {
                    return event.computedStatus == 'completed';
                  }
                  return true;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.event_busy_rounded,
                            size: 48,
                            color: TraceColors.lightGrey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No $_selectedFilter events.',
                            style: GoogleFonts.inter(
                              color: TraceColors.medGrey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
                  itemCount: filteredDocs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final doc = filteredDocs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    final event = Event.fromMap(data, doc.id);

                    final statusColor = _getStatusColor(event.computedStatus);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GestureDetector(
                        onTap: () => widget.onEventTap(event),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Bar
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      event.computedStatus == 'completed'
                                          ? Icons.check_circle_outline
                                          : event.computedStatus == 'ongoing'
                                          ? Icons.play_circle_outline
                                          : Icons.schedule,
                                      size: 16,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      event.computedStatus.toUpperCase(),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: statusColor,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      DateFormat(
                                        'MMM dd, yyyy',
                                      ).format(event.date),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: TraceColors.medGrey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Body
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (event.bannerUrl.isNotEmpty) ...[
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: TraceColors.lightGrey
                                              .withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          image: DecorationImage(
                                            image:
                                                event.bannerUrl.startsWith(
                                                  'data:image',
                                                )
                                                ? MemoryImage(
                                                        base64Decode(
                                                          event.bannerUrl
                                                              .split(',')
                                                              .last,
                                                        ),
                                                      )
                                                      as ImageProvider
                                                : NetworkImage(event.bannerUrl),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            event.eventName,
                                            style: GoogleFonts.inter(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                              color: TraceColors.navyBlue,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            event.venue.isEmpty
                                                ? 'TBA'
                                                : event.venue,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: TraceColors.navyBlue
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: TraceColors.gold
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: TraceColors.gold
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.event,
                                                  size: 14,
                                                  color: TraceColors.navyBlue,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  event.startTime != null &&
                                                          event.endTime != null
                                                      ? '${_formatTime(event.startTime!)} - ${_formatTime(event.endTime!)}'
                                                      : event.isWholeDay
                                                      ? 'Whole Day'
                                                      : 'Half Day',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: TraceColors.navyBlue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
