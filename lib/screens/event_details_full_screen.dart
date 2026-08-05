import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/event.dart';

class EventDetailsFullScreen extends StatelessWidget {
  final Event event;
  final Widget? bottomActions;

  const EventDetailsFullScreen({
    super.key,
    required this.event,
    this.bottomActions,
  });

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

  @override
  Widget build(BuildContext context) {
    final isWholeDay = event.isWholeDay;
    final isAfternoonHalfDay = event.isPmOnly;

    return Scaffold(
      backgroundColor: TraceColors.white,
      body: SafeArea(
        bottom: false,
        child: Container(
          color: TraceColors.navyBlue,
          child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _EventDetailsHeaderDelegate(
                  event: event,
                  safeAreaTop: 0,
                  buildBanner: _buildBannerImage,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (event.description.isNotEmpty) ...[
                      Text(
                        'Event Details',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: TraceColors.gold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        event.description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: TraceColors.white.withValues(alpha: 0.8),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    Text(
                      'Schedule of Attendance',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: TraceColors.gold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!isWholeDay) ...[
                      _buildScheduleRow(
                        context,
                        isAfternoonHalfDay ? 'Afternoon In' : 'Morning In',
                        (isAfternoonHalfDay
                                ? event.afternoonTimeIn
                                : event.morningTimeIn) ??
                            '--',
                      ),
                      _buildScheduleRow(
                        context,
                        isAfternoonHalfDay ? 'Afternoon Out' : 'Morning Out',
                        (isAfternoonHalfDay
                                ? event.afternoonTimeOut
                                : event.morningTimeOut) ??
                            '--',
                      ),
                    ] else ...[
                      _buildScheduleRow(
                        context,
                        'Morning In',
                        event.morningTimeIn ?? '--',
                      ),
                      _buildScheduleRow(
                        context,
                        'Morning Out',
                        event.morningTimeOut ?? '--',
                      ),
                      const SizedBox(height: 8),
                      _buildScheduleRow(
                        context,
                        'Afternoon In',
                        event.afternoonTimeIn ?? '--',
                      ),
                      _buildScheduleRow(
                        context,
                        'Afternoon Out',
                        event.afternoonTimeOut ?? '--',
                      ),
                    ],
                    if (bottomActions != null) ...[
                      const SizedBox(height: 32),
                      bottomActions!,
                    ],
                    const SizedBox(height: 48),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDisplayTime(BuildContext context, String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--';
    try {
      final parts = timeStr.split(':');
      final time = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
      return time.format(context);
    } catch (_) {
      return timeStr;
    }
  }

  Widget _buildScheduleRow(BuildContext context, String label, String timeStr) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: TraceColors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          Text(
            _formatDisplayTime(context, timeStr),
            style: GoogleFonts.inter(
              color: TraceColors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventDetailsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Event event;
  final double safeAreaTop;
  final Widget Function(String, {BoxFit fit}) buildBanner;

  _EventDetailsHeaderDelegate({
    required this.event,
    required this.safeAreaTop,
    required this.buildBanner,
  });

  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final dt = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return timeStr;
    }
  }

  @override
  double get minExtent => safeAreaTop + 80;

  @override
  double get maxExtent => safeAreaTop + 320;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress =
        shrinkOffset / (maxExtent - minExtent); // 0 (expanded) to 1 (shrunk)
    final clampedProgress = progress.clamp(0.0, 1.0);
    final isShrunk = clampedProgress > 0.8;
    final dateStr = DateFormat('MMM dd, yyyy').format(event.date);

    return Container(
      color: TraceColors.navyBlue,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (event.bannerUrl.isNotEmpty && clampedProgress < 1.0)
            Positioned.fill(
              bottom: 80,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _FullScreenImage(
                        url: event.bannerUrl,
                        buildBanner: buildBanner,
                      ),
                    ),
                  );
                },
                child: Opacity(
                  opacity: 1 - clampedProgress,
                  child: buildBanner(event.bannerUrl, fit: BoxFit.cover),
                ),
              ),
            ),
          if (event.bannerUrl.isNotEmpty && clampedProgress < 1.0)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              height: 80,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      TraceColors.navyBlue.withValues(alpha: 0.0),
                      TraceColors.navyBlue,
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            top: safeAreaTop + 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Content
          Positioned(
            bottom: 16,
            left: 24,
            right: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (event.bannerUrl.isNotEmpty && isShrunk) ...[
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: TraceColors.lightGrey,
                    backgroundImage: event.bannerUrl.startsWith('data:image')
                        ? MemoryImage(
                                base64Decode(event.bannerUrl.split(',').last),
                              )
                              as ImageProvider
                        : NetworkImage(event.bannerUrl),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          event.eventName.isEmpty
                              ? 'Event Details'
                              : event.eventName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: isShrunk ? 18 : 24,
                            color: TraceColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${event.venue.isEmpty ? 'N/A' : event.venue} • $dateStr • ${event.isWholeDay ? 'Whole Day' : 'Half Day'}',
                          style: GoogleFonts.inter(
                            fontSize: isShrunk ? 12 : 14,
                            color: TraceColors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      if (event.startTime != null && event.endTime != null) ...[
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_formatTime(event.startTime!)} - ${_formatTime(event.endTime!)}',
                            style: GoogleFonts.inter(
                              fontSize: isShrunk ? 12 : 14,
                              color: TraceColors.gold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

class _FullScreenImage extends StatelessWidget {
  final String url;
  final Widget Function(String, {BoxFit fit}) buildBanner;

  const _FullScreenImage({required this.url, required this.buildBanner});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(child: buildBanner(url, fit: BoxFit.contain)),
      ),
    );
  }
}
