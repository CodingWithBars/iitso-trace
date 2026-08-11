import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../services/student_session_service.dart';
import '../../services/auth_service.dart';
import '../shared_widgets.dart';
import '../../models/event.dart';
import '../../screens/event_details_full_screen.dart';

class HeroSection extends ConsumerWidget {
  final bool isWide;

  const HeroSection({super.key, required this.isWide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: TraceColors.heroGradient),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: TraceColors.gold.withValues(alpha: 0.12),
                  width: 40,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: TraceColors.gold.withValues(alpha: 0.08),
                  width: 50,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: isWide ? 80 : 52),
            child: isWide
                ? Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 80),
                          child: _buildHeroText(context, ref),
                        ),
                      ),
                      const SizedBox(width: 60),
                      Expanded(
                        child: _buildUpcomingEventCard(context, isWide: true),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildHeroText(context, ref),
                      ),
                      const SizedBox(height: 40),
                      _buildUpcomingEventCard(context, isWide: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroText(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transparent Records\n& Attendance for\nCampus Events',
          style: GoogleFonts.inter(
            fontSize: MediaQuery.of(context).size.width > 800 ? 44 : 30,
            fontWeight: FontWeight.w800,
            color: TraceColors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'A modern, real-time system for student attendance tracking, event management, and full financial transparency.',
          style: GoogleFonts.inter(
            fontSize: 15,
            color: TraceColors.white.withValues(alpha: 0.75),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 36),
        if (kIsWeb)
          _buildWebDownloadButton(context)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final studentId = ref.watch(studentSessionProvider).valueOrNull;
              final isLoggedInStudent = studentId != null && studentId.isNotEmpty;

              if (isMobile) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isLoggedInStudent) ...[
                      GoldButton(
                        label: 'Register for QR Code',
                        icon: Icons.qr_code_2_rounded,
                        onPressed: () => context.push('/register'),
                        fullWidth: true,
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/dashboard'),
                        icon: const Icon(
                          Icons.person_search_rounded,
                          color: TraceColors.white,
                        ),
                        label: Text(
                          'Search Student',
                          style: GoogleFonts.inter(
                            color: TraceColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: TraceColors.white,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return Row(
                  children: [
                    if (!isLoggedInStudent) ...[
                      Expanded(
                        child: GoldButton(
                          label: 'Register for QR Code',
                          icon: Icons.qr_code_2_rounded,
                          onPressed: () => context.push('/register'),
                          fullWidth: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/dashboard'),
                        icon: const Icon(
                          Icons.person_search_rounded,
                          color: TraceColors.white,
                        ),
                        label: Text(
                          'Search Student',
                          style: GoogleFonts.inter(
                            color: TraceColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: TraceColors.white,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        if (!kIsWeb) ...[
          Consumer(
            builder: (context, ref, _) {
              final studentId = ref.watch(studentSessionProvider).valueOrNull;
              final isLoggedInStudent = studentId != null && studentId.isNotEmpty;
              if (isLoggedInStudent) return const SizedBox();

              return Column(
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.push('/claim-id'),
                      icon: const Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: TraceColors.gold,
                      ),
                      label: Text(
                        'Claim My Student ID',
                        style: GoogleFonts.inter(
                          color: TraceColors.gold,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          decorationColor: TraceColors.gold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildWebDownloadButton(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: MediaQuery.of(context).size.width < 600
              ? double.infinity
              : 300,
          child: GoldButton(
            label: 'Download Android APK',
            icon: Icons.android_rounded,
            onPressed: () async {
              final uri = Uri.parse('https://tinyurl.com/mtptean6');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open download link.')),
                  );
                }
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingEventCard(BuildContext context, {required bool isWide}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.db
          .collection('events')
          .where('status', whereIn: ['upcoming', 'ongoing'])
          .orderBy('date')
          .limit(10)
          .snapshots(),
      builder: (ctx, snap) {
        final hasEvents = snap.hasData && snap.data!.docs.isNotEmpty;

        if (!hasEvents) {
          return Padding(
            padding: EdgeInsets.only(
              left: isWide ? 0 : 24,
              right: isWide ? 80 : 24,
            ),
            child: _buildSingleEventCard(context, null),
          );
        }

        var docs = snap.data!.docs.toList();

        // We remove the strict yesterday check since events can span multiple days 
        // or be manually marked as 'ongoing' by the admin. The query already 
        // filters for 'ongoing' and 'upcoming' statuses.

        if (docs.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(
              left: isWide ? 0 : 24,
              right: isWide ? 80 : 24,
            ),
            child: _buildSingleEventCard(context, null),
          );
        }

        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          final dateA =
              (dataA['date'] as Timestamp?)?.toDate() ?? DateTime.now();
          final dateB =
              (dataB['date'] as Timestamp?)?.toDate() ?? DateTime.now();

          final cmp = dateA.compareTo(dateB);
          if (cmp != 0) return cmp;

          final timeInA = dataA['is_whole_day'] == true
              ? dataA['morning_time_in']
              : dataA['time_in'];
          final timeInB = dataB['is_whole_day'] == true
              ? dataB['morning_time_in']
              : dataB['time_in'];

          final tA = timeInA?.toString() ?? '23:59';
          final tB = timeInB?.toString() ?? '23:59';

          return tA.compareTo(tB);
        });

        final topDocs = docs.take(2).toList();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(
            left: isWide ? 0 : 24,
            right: isWide ? 80 : 24,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: topDocs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final isLast = doc == topDocs.last;
                return Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 16),
                  child: _buildSingleEventCard(context, data),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBannerImage(String url, {BoxFit fit = BoxFit.cover}) {
    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.split(',').last;
        return Image.memory(base64Decode(base64Str), fit: fit);
      } catch (_) {
        return Container(color: TraceColors.lightGrey);
      }
    }
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, _, _) => Container(color: TraceColors.lightGrey),
    );
  }

  Widget _buildSingleEventCard(
    BuildContext context,
    Map<String, dynamic>? data,
  ) {
    final hasEvent = data != null;
    if (!hasEvent) {
      return Container(
        width: 330,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: TraceColors.gold.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
            ),
          ],
        ),
        child: Text(
          'No upcoming events.',
          style: GoogleFonts.inter(
            color: TraceColors.white.withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      );
    }

    final event = Event.fromMap(data, '');
    final isOngoing = event.status == 'ongoing';
    final isWholeDay = event.isWholeDay;
    final isAfternoonHalfDay = event.isPmOnly;

    return Container(
      width: 330,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isOngoing ? TraceColors.success : TraceColors.gold)
              .withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 24),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showEventDetails(context, data),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (event.bannerUrl.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _buildBannerImage(event.bannerUrl),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 72,
                      width: double.infinity,
                      child: AutoSizeText(
                        event.eventName,
                        maxLines: 3,
                        minFontSize: 14,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: TraceColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (event.venue.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: TraceColors.gold,
                            size: 13,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              event.venue,
                              style: GoogleFonts.inter(
                                color: TraceColors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Color(0xFF1E88E5),
                          size: 13,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _formatDate(event.date),
                            style: GoogleFonts.inter(
                              color: TraceColors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (isWholeDay) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Morning / Afternoon',
                            style: GoogleFonts.inter(
                              color: TraceColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '- "Whole day event"',
                            style: GoogleFonts.inter(
                              color: TraceColors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '[Time In] : ${event.morningTimeIn ?? '--'}',
                              style: GoogleFonts.inter(
                                color: TraceColors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            ' | ',
                            style: GoogleFonts.inter(
                              color: TraceColors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '[Time Out] : ${event.morningTimeOut ?? '--'}',
                              style: GoogleFonts.inter(
                                color: TraceColors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Afternoon',
                        style: GoogleFonts.inter(
                          color: TraceColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '[Time In] : ${event.afternoonTimeIn ?? '--'}',
                              style: GoogleFonts.inter(
                                color: TraceColors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            ' | ',
                            style: GoogleFonts.inter(
                              color: TraceColors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '[Time Out] : ${event.afternoonTimeOut ?? '--'}',
                              style: GoogleFonts.inter(
                                color: TraceColors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isAfternoonHalfDay ? 'Afternoon' : 'Morning',
                            style: GoogleFonts.inter(
                              color: TraceColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '- "Half day event"',
                            style: GoogleFonts.inter(
                              color: TraceColors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '[Time In] : ${(isAfternoonHalfDay ? event.afternoonTimeIn : event.morningTimeIn) ?? '--'}',
                              style: GoogleFonts.inter(
                                color: TraceColors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            ' | ',
                            style: GoogleFonts.inter(
                              color: TraceColors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '[Time Out] : ${(isAfternoonHalfDay ? event.afternoonTimeOut : event.morningTimeOut) ?? '--'}',
                              style: GoogleFonts.inter(
                                color: TraceColors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEventDetails(BuildContext context, Map<String, dynamic> data) {
    final event = Event.fromMap(data, '');
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailsFullScreen(event: event)),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
