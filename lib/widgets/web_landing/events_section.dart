import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../models/event.dart';
import '../../screens/event_details_full_screen.dart';
import 'web_landing_helpers.dart';

class EventsSection extends StatelessWidget {
  const EventsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F4F9),
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final isWide = constraints.maxWidth > 700;
          final hPad = isWide ? 80.0 : 24.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: buildSectionHeader(
                  'Upcoming & Ongoing Events',
                  TraceColors.navyBlue,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Text(
                  'Stay informed about events happening on campus.',
                  style: GoogleFonts.inter(
                    color: TraceColors.medGrey,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('events')
                    .orderBy('date', descending: false)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          color: TraceColors.royalBlue,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'Error loading events: ${snap.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  }

                  final docs = (snap.data?.docs ?? []).where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = (data['status'] ?? '')
                        .toString()
                        .toLowerCase();
                    return status == 'upcoming' || status == 'ongoing';
                  }).toList();

                  if (docs.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: buildEmptyState(
                        'No upcoming or ongoing events right now.',
                        Icons.event_busy_rounded,
                      ),
                    );
                  }

                  // On mobile: vertical stack. On wide: 2-column wrap.
                  if (isWide) {
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return SizedBox(
                            width:
                                (constraints.maxWidth - hPad * 2 - 20) /
                                2.clamp(1, 2),
                            child: _eventCard(context, data),
                          );
                        }).toList(),
                      ),
                    );
                  } else {
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: Column(
                        children: docs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _eventCard(context, data),
                          );
                        }).toList(),
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEventDetails(BuildContext context, Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailsFullScreen(event: event)),
    );
  }

  Widget _eventCard(BuildContext context, Map<String, dynamic> data) {
    final event = Event.fromMap(data, '');
    Color borderColor;
    Color badgeColor;
    String statusLabel;
    switch (event.status.toLowerCase()) {
      case 'ongoing':
        borderColor = const Color(0xFFFFD700);
        badgeColor = const Color(0xFFFFD700);
        statusLabel = 'Ongoing';
        break;
      case 'upcoming':
        borderColor = const Color(0xFF4FC3F7);
        badgeColor = const Color(0xFF4FC3F7);
        statusLabel = 'Upcoming';
        break;
      default:
        borderColor = TraceColors.medGrey;
        badgeColor = TraceColors.medGrey;
        statusLabel = event.status;
    }

    return Container(
      decoration: BoxDecoration(
        color: TraceColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEventDetails(context, event),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          if (event.bannerUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: buildBannerImage(event.bannerUrl),
            )
          else
            Container(
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [TraceColors.royalBlue, TraceColors.navyBlue],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.event_rounded,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 36,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: badgeColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    statusLabel.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: badgeColor == const Color(0xFFFFD700)
                          ? const Color(0xFF8B6800)
                          : badgeColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  event.eventName,
                  style: GoogleFonts.inter(
                    color: TraceColors.navyBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.venue.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 13,
                        color: TraceColors.gold,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          event.venue,
                          style: GoogleFonts.inter(
                            color: TraceColors.medGrey,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: Color(0xFF4FC3F7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatDate(event.date),
                      style: GoogleFonts.inter(
                        color: TraceColors.medGrey,
                        fontSize: 12,
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
      ),
    );
  }
}
