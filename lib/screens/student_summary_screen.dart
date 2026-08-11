import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/student_session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/student_service.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../models/event.dart';
import '../services/event_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'student/student_finances_tab.dart';

class StudentSummaryScreen extends ConsumerStatefulWidget {
  final String studentId;
  const StudentSummaryScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentSummaryScreen> createState() =>
      _StudentSummaryScreenState();
}

class _StudentSummaryScreenState extends ConsumerState<StudentSummaryScreen> {
  Student? _student;
  List<Attendance> _attendance = [];
  Map<String, Event> _events = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final student = await StudentService.getStudentByStudentId(
        widget.studentId,
      );
      if (student == null) {
        setState(() => _error = 'Student not found.');
        return;
      }

      final attendanceList = await StudentService.getAttendanceForStudent(
        student.id,
      );

      final events = await EventService.getAllEvents();
      final eventMap = {for (var e in events) e.id: e};

      if (mounted) {
        setState(() {
          _student = student;
          _attendance = attendanceList;
          _events = eventMap;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load records: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 48),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: TraceColors.navyBlue.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.event_busy_outlined,
            color: TraceColors.medGrey,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No Records Found',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: TraceColors.navyBlue,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'You haven\'t attended any events yet.',
          style: GoogleFonts.inter(fontSize: 13, color: TraceColors.medGrey),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: TraceColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TraceColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: TraceColors.error),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.inter(
                color: TraceColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        // Student info card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [TraceColors.navyBlue, TraceColors.royalBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: TraceColors.navyBlue.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: TraceColors.gold, width: 2),
                  color: TraceColors.gold.withValues(alpha: 0.15),
                ),
                child: ClipOval(
                  child: _student!.avatarUrl.isNotEmpty
                      ? (_student!.avatarUrl.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(
                                  _student!.avatarUrl.split(',').last,
                                ),
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    _student!.name.isNotEmpty
                                        ? _student!.name[0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: TraceColors.gold,
                                    ),
                                  ),
                                ),
                              )
                            : Image.network(
                                _student!.avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    _student!.name.isNotEmpty
                                        ? _student!.name[0].toUpperCase()
                                        : '?',
                                    style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: TraceColors.gold,
                                    ),
                                  ),
                                ),
                              ))
                      : Align(
                          alignment: Alignment.center,
                          child: Text(
                            _student!.name.isNotEmpty
                                ? _student!.name[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: TraceColors.gold,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _student!.name,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: TraceColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          color: TraceColors.gold,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _student!.studentId,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: TraceColors.gold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.school_outlined,
                          color: TraceColors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_student!.course} - ${_student!.yearLevel}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: TraceColors.white.withValues(alpha: 0.8),
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
        const SizedBox(height: 24),

        _buildStatsTriangle(),
        const SizedBox(height: 24),

        if (_attendance.isEmpty)
          _buildEmptyState()
        else
          ..._attendance.map((a) => _attendanceTile(a)),
      ],
    );
  }

  (Duration, Duration, Duration) _calculateDurations(
    Attendance a,
    Event? event,
  ) {
    if (event == null) return (Duration.zero, Duration.zero, Duration.zero);

    Duration totalEventDuration = Duration.zero;
    if (event.startTime != null &&
        event.endTime != null &&
        event.startTime!.isNotEmpty &&
        event.endTime!.isNotEmpty) {
      try {
        final start = DateFormat('HH:mm').parse(event.startTime!);
        final end = DateFormat('HH:mm').parse(event.endTime!);
        totalEventDuration = end.difference(start);
        if (totalEventDuration.isNegative) {
          totalEventDuration += const Duration(hours: 24);
        }

        if (event.isWholeDay &&
            event.morningTimeOut != null &&
            event.afternoonTimeIn != null) {
          try {
            final mOut = DateFormat('HH:mm').parse(event.morningTimeOut!);
            final aIn = DateFormat('HH:mm').parse(event.afternoonTimeIn!);
            Duration breakDuration = aIn.difference(mOut);
            if (!breakDuration.isNegative &&
                breakDuration < totalEventDuration) {
              totalEventDuration -= breakDuration;
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    DateTime now = DateTime.now();
    DateTime eventDate = event.date;

    DateTime? parseTime(String? tStr) {
      if (tStr == null || tStr.isEmpty) return null;
      try {
        final t = DateFormat('h:mm a').parse(tStr);
        return DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day,
          t.hour,
          t.minute,
        );
      } catch (_) {
        try {
          final t = DateFormat('HH:mm').parse(tStr);
          return DateTime(
            eventDate.year,
            eventDate.month,
            eventDate.day,
            t.hour,
            t.minute,
          );
        } catch (_) {
          return null;
        }
      }
    }

    DateTime? amEnd = parseTime(event.morningTimeOut ?? event.endTime);
    DateTime? pmEnd = parseTime(event.afternoonTimeOut ?? event.endTime);

    Duration amCompleted = Duration.zero;
    if (a.timeInAm != null) {
      if (a.timeOutAm != null) {
        amCompleted = a.timeOutAm!.difference(a.timeInAm!);
      } else {
        if (amEnd != null && now.isAfter(amEnd)) {
          amCompleted = Duration.zero;
        } else {
          amCompleted = now.difference(a.timeInAm!);
        }
      }
    }
    if (amCompleted.isNegative) amCompleted = Duration.zero;

    Duration pmCompleted = Duration.zero;
    if (a.timeInPm != null) {
      if (a.timeOutPm != null) {
        pmCompleted = a.timeOutPm!.difference(a.timeInPm!);
      } else {
        if (pmEnd != null && now.isAfter(pmEnd)) {
          pmCompleted = Duration.zero;
        } else {
          pmCompleted = now.difference(a.timeInPm!);
        }
      }
    }
    if (pmCompleted.isNegative) pmCompleted = Duration.zero;

    Duration completedDuration = amCompleted + pmCompleted;
    Duration missedDuration = totalEventDuration - completedDuration;
    if (missedDuration.isNegative) missedDuration = Duration.zero;

    return (totalEventDuration, completedDuration, missedDuration);
  }

  Widget _buildStatsTriangle() {
    Duration totalEventDurationAll = Duration.zero;
    Duration completedDurationAll = Duration.zero;
    Duration missedDurationAll = Duration.zero;

    for (final a in _attendance) {
      final event = _events[a.eventId];
      if (event == null) continue;

      final (total, completed, missed) = _calculateDurations(a, event);
      totalEventDurationAll += total;
      completedDurationAll += completed;
      missedDurationAll += missed;
    }

    String fmt(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return '${h}h ${m}m';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: TraceColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TraceColors.lightGrey.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: TraceColors.navyBlue.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    fmt(totalEventDurationAll),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TraceColors.gold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Total Event',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: TraceColors.medGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    fmt(completedDurationAll),
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: TraceColors.success,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Completed',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: TraceColors.navyBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    fmt(missedDurationAll),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TraceColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Missed',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: TraceColors.medGrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceTile(Attendance a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: TraceColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TraceColors.lightGrey.withValues(alpha: 0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showAttendanceDetails(a),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: TraceColors.royalBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.event_rounded,
                    color: TraceColors.royalBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.eventName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: TraceColors.navyBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to view details',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: TraceColors.medGrey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip.fromStatus(a.finalStatus),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAttendanceDetails(Attendance a) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final event = _events[a.eventId];

        final (totalEventDuration, completedDuration, missedDuration) =
            _calculateDurations(a, event);

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
                  StatusChip.fromStatus(a.finalStatus),
                ],
              ),
              const SizedBox(height: 24),
              if (a.timeInAm != null ||
                  a.timeOutAm != null ||
                  a.timeInPm != null ||
                  a.timeOutPm != null) ...[
                Text(
                  'Attendance Logs',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TraceColors.navyBlue,
                  ),
                ),
                const SizedBox(height: 8),
                if (event?.isWholeDay == true || event?.isAmOnly == true) ...[
                  _buildTimeRow('Morning In:', a.timeInAm),
                  _buildTimeRow('Morning Out:', a.timeOutAm),
                ],
                if (event?.isWholeDay == true || event?.isPmOnly == true) ...[
                  _buildTimeRow('Afternoon In:', a.timeInPm),
                  _buildTimeRow('Afternoon Out:', a.timeOutPm),
                ],
                const SizedBox(height: 16),
              ],
              if (a.timeInAm == null &&
                  a.timeOutAm == null &&
                  a.timeInPm == null &&
                  a.timeOutPm == null)
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
                totalEventDuration,
                TraceColors.medGrey,
              ),
              _buildDurationRow(
                'Completed Hours:',
                completedDuration,
                TraceColors.success,
              ),
              _buildDurationRow(
                'Missed Hours:',
                missedDuration,
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

  String _fmt(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  int _activeSegment = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: TraceAppBar(
        title: 'Student Portal',
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final sessionAsync = ref.watch(studentSessionProvider);
              final isLoggedIn =
                  sessionAsync.valueOrNull != null &&
                  sessionAsync.valueOrNull!.isNotEmpty;

              if (isLoggedIn) {
                return IconButton(
                  onPressed: () {
                    ref.read(studentSessionProvider.notifier).logout();
                    context.go('/');
                  },
                  icon: const Icon(
                    Icons.logout,
                    color: TraceColors.gold,
                    size: 20,
                  ),
                  tooltip: 'Logout',
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(
                      color: TraceColors.royalBlue,
                    ),
                  )
                : _error != null
                ? _buildErrorCard()
                : Column(
                    children: [
                      _buildSlickSegmentedControl(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildActiveSegmentView(),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlickSegmentedControl() {
    final segments = [
      {'label': 'Attendance', 'icon': Icons.insights_rounded},
      {'label': 'My Dues', 'icon': Icons.account_balance_wallet_rounded},
      {'label': 'Org Ledger', 'icon': Icons.receipt_long_rounded},
    ];

    return Container(
      decoration: BoxDecoration(
        color: TraceColors.navyBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: List.generate(segments.length, (index) {
          final isSelected = _activeSegment == index;
          final item = segments[index];

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeSegment = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? TraceColors.navyBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: TraceColors.navyBlue.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      size: 15,
                      color: isSelected ? TraceColors.gold : TraceColors.navyBlue,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : TraceColors.navyBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActiveSegmentView() {
    if (_activeSegment == 0) {
      return SingleChildScrollView(child: _buildResults());
    } else if (_activeSegment == 1) {
      return StudentFinancesTab(
        studentId: widget.studentId,
        initialTabIndex: 0,
        hideInnerTabBar: true,
      );
    } else {
      return StudentFinancesTab(
        studentId: widget.studentId,
        initialTabIndex: 1,
        hideInnerTabBar: true,
      );
    }
  }
}
