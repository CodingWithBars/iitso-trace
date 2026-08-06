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
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class StudentDashboardScreen extends ConsumerStatefulWidget {
  final String? initialStudentId;
  const StudentDashboardScreen({super.key, this.initialStudentId});

  @override
  ConsumerState<StudentDashboardScreen> createState() =>
      _StudentDashboardScreenState();
}

class _StudentDashboardScreenState
    extends ConsumerState<StudentDashboardScreen> {
  final _idController = TextEditingController();
  bool _isLoading = false;
  Student? _student;
  List<Attendance> _attendanceList = [];
  Map<String, Event> _eventsMap = {};
  bool _searched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialStudentId != null) {
      _idController.text = widget.initialStudentId!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final id = _idController.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _searched = true;
    });
    final student = await StudentService.getStudentByStudentId(id);
    if (student == null) {
      setState(() {
        _student = null;
        _attendanceList = [];
        _isLoading = false;
        _error = 'Student not found. Please check your Student ID.';
      });
      return;
    }
    final attendance = await StudentService.getAttendanceForStudent(student.id);

    final Map<String, Event> eventMap = {};
    for (var a in attendance) {
      if (!eventMap.containsKey(a.eventId)) {
        try {
          final doc = await FirestoreService.db
              .collection('events')
              .doc(a.eventId)
              .get();
          if (doc.exists) {
            eventMap[a.eventId] = Event.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }
        } catch (_) {}
      }
    }

    setState(() {
      _student = student;
      _attendanceList = attendance;
      _eventsMap = eventMap;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: TraceAppBar(
        title: 'Search Student',
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final authService = ref.watch(authServiceProvider);
              final isAdmin = authService.isLoggedIn;

              if (isAdmin) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () => context.push('/admin/dashboard'),
                    icon: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: TraceColors.gold,
                      size: 20,
                    ),
                    tooltip: 'Admin Dashboard',
                  ),
                );
              }

              final sessionAsync = ref.watch(studentSessionProvider);
              final studentId = sessionAsync.valueOrNull;
              final isStudentLoggedIn =
                  studentId != null && studentId.isNotEmpty;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: () {
                    if (isStudentLoggedIn) {
                      context.push('/student/id/$studentId');
                    } else {
                      context.push('/student-login');
                    }
                  },
                  icon: Icon(
                    isStudentLoggedIn ? Icons.badge_outlined : Icons.login,
                    color: TraceColors.gold,
                    size: 18,
                  ),
                  label: Text(
                    isStudentLoggedIn ? 'My ID' : 'Login',
                    style: GoogleFonts.inter(
                      color: TraceColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                // Search card
                TraceCard(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  TraceColors.royalBlue,
                                  TraceColors.midBlue,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_search_rounded,
                              color: TraceColors.gold,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attendance Lookup',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: TraceColors.navyBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _idController,
                              decoration: const InputDecoration(
                                labelText: 'Student ID',
                                hintText: 'e.g. 2024-00001',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              onSubmitted: (_) => _search(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GoldButton(
                            label: 'Search',
                            icon: Icons.search_rounded,
                            isLoading: _isLoading,
                            onPressed: _search,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(
                      color: TraceColors.royalBlue,
                    ),
                  )
                else if (_error != null)
                  _buildErrorCard()
                else if (_student != null)
                  _buildResults()
                else if (!_searched)
                  _buildEmptyState(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: TraceColors.royalBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.manage_search_rounded,
              size: 40,
              color: TraceColors.royalBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Student Records',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: TraceColors.navyBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter Student ID above to view \nattendance history for all events.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 14, color: TraceColors.medGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TraceColors.errorLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TraceColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.person_off_rounded,
            color: TraceColors.error,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: TraceColors.error,
                fontWeight: FontWeight.w600,
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
                        fontWeight: FontWeight.w800,
                        color: TraceColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_student!.course} • ${_student!.yearLevel}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: TraceColors.gold,
                      ),
                    ),
                    Text(
                      'ID: ${_student!.studentId}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: TraceColors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Attendance list
        TraceCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attendance History',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: TraceColors.navyBlue,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: TraceColors.royalBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_attendanceList.length} Events',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: TraceColors.royalBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_attendanceList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No attendance records found.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: TraceColors.medGrey,
                      ),
                    ),
                  ),
                )
              else
                ..._attendanceList.map((a) => _attendanceTile(a)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _attendanceTile(Attendance a) {
    final event = _eventsMap[a.eventId];
    final title = event?.eventName ?? 'Unknown Event';
    final dateStr = event != null
        ? DateFormat('MMM dd, yyyy').format(event.date)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TraceColors.offWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TraceColors.lightGrey.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: TraceColors.lightGrey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              image: event != null && event.bannerUrl.isNotEmpty
                  ? DecorationImage(
                      image: event.bannerUrl.startsWith('data:image')
                          ? MemoryImage(
                                  base64Decode(event.bannerUrl.split(',').last),
                                )
                                as ImageProvider
                          : NetworkImage(event.bannerUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: event == null || event.bannerUrl.isEmpty
                ? const Icon(
                    Icons.event_rounded,
                    color: TraceColors.royalBlue,
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: TraceColors.navyBlue,
                  ),
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: TraceColors.medGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 2),
                if (a.timeInAm != null)
                  Text(
                    'AM In: ${_fmt(a.timeInAm!)}${a.timeOutAm != null ? '  |  Out: ${_fmt(a.timeOutAm!)}' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: TraceColors.medGrey,
                    ),
                  ),
                if (a.timeInPm != null)
                  Text(
                    'PM In: ${_fmt(a.timeInPm!)}${a.timeOutPm != null ? '  |  Out: ${_fmt(a.timeOutPm!)}' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: TraceColors.medGrey,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip.fromStatus(a.finalStatus),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }
}
