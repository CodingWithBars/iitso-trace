import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/attendance_service.dart';
import '../../models/attendance.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../../services/csv_report_service.dart';

class EventAttendanceScreen extends StatefulWidget {
  final String eventId;
  const EventAttendanceScreen({super.key, required this.eventId});

  @override
  State<EventAttendanceScreen> createState() => _EventAttendanceScreenState();
}

class StudentAttendanceDisplay {
  final Map<String, dynamic> studentData;
  final Attendance? attendance;
  StudentAttendanceDisplay(this.studentData, this.attendance);
}

class _EventAttendanceScreenState extends State<EventAttendanceScreen> {
  bool _isLoading = true;
  String _eventName = 'Attendance';

  List<Attendance> _allAttendance = [];
  final Map<String, Map<String, dynamic>> _studentsMap = {};

  String _searchQuery = '';
  String _selectedProgram = 'All';
  String _statusFilter = 'Present'; // 'Present', 'Absent', 'All'
  final List<String> _programs = ['All', 'BSBA', 'BSA', 'BTLED', 'BSIT'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // 1. Fetch event name
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .get();
      if (eventDoc.exists) {
        _eventName = eventDoc.data()?['event_name'] ?? 'Attendance';
      }

      // 2. Fetch attendance
      _allAttendance = await AttendanceService.getEventAttendance(
        widget.eventId,
      );

      // 3. Fetch all students (to join data)
      final studentsSnap = await FirebaseFirestore.instance
          .collection('students')
          .get();
      for (var doc in studentsSnap.docs) {
        _studentsMap[doc.id] = doc.data();
      }
    } catch (e) {
      debugPrint('Error fetching event attendance data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, int> _getProgramTotals() {
    final totals = {'BSBA': 0, 'BSA': 0, 'BSIT': 0, 'BTLED': 0};
    for (var att in _allAttendance) {
      final studentData = _studentsMap[att.studentId];
      if (studentData != null) {
        final course = (studentData['course']?.toString() ?? '').toUpperCase();
        if (totals.containsKey(course)) {
          totals[course] = totals[course]! + 1;
        }
      }
    }
    return totals;
  }

  List<StudentAttendanceDisplay> _getFilteredData() {
    final List<StudentAttendanceDisplay> result = [];

    for (var entry in _studentsMap.entries) {
      final sId = entry.key;
      final studentData = entry.value;
      final att = _allAttendance.cast<Attendance?>().firstWhere((a) => a!.studentId == sId, orElse: () => null);

      final isPresent = att != null;

      if (_statusFilter == 'Present' && !isPresent) continue;
      if (_statusFilter == 'Absent' && isPresent) continue;

      final course = (studentData['course']?.toString() ?? '').toUpperCase();
      final name = (studentData['name']?.toString() ?? '').toLowerCase();
      final studentIdStr = (studentData['student_id']?.toString() ?? '').toLowerCase();

      // Program filter
      if (_selectedProgram != 'All' && course != _selectedProgram) continue;

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!name.contains(q) && !studentIdStr.contains(q)) continue;
      }

      result.add(StudentAttendanceDisplay(studentData, att));
    }

    // Sort alphabetically
    result.sort((a, b) => (a.studentData['name'] ?? '').compareTo(b.studentData['name'] ?? ''));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: TraceColors.offWhite,
        appBar: TraceAppBar(title: 'Loading...'),
        body: Center(
          child: CircularProgressIndicator(color: TraceColors.navyBlue),
        ),
      );
    }

    final totals = _getProgramTotals();
    final filteredData = _getFilteredData();

    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: TraceAppBar(title: _eventName),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: TraceColors.gold,
        onPressed: () {
          // Pass the filtered present attendance to the CSV export
          final presentAttendance = filteredData
              .where((d) => d.attendance != null)
              .map((d) => d.attendance!)
              .toList();
          CsvReportService.generateAttendanceCsv(
            presentAttendance,
            _studentsMap,
          );
        },
        icon: const Icon(
          Icons.table_chart_rounded,
          color: TraceColors.navyBlue,
        ),
        label: Text(
          'Export CSV',
          style: GoogleFonts.inter(
            color: TraceColors.navyBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Program Attendance',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TraceColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 2x2 Grid of Programs
                  Row(
                    children: [
                      Expanded(
                        child: _buildProgramStat('BSBA', totals['BSBA'] ?? 0),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildProgramStat('BSA', totals['BSA'] ?? 0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildProgramStat('BSIT', totals['BSIT'] ?? 0),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildProgramStat('BTLED', totals['BTLED'] ?? 0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Search & Sort Bar
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: TraceColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: TextField(
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                            style: GoogleFonts.inter(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Search student...',
                              hintStyle: GoogleFonts.inter(
                                color: TraceColors.medGrey,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: TraceColors.medGrey,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: TraceColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedProgram,
                            icon: const Icon(
                              Icons.filter_list,
                              color: TraceColors.navyBlue,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: TraceColors.navyBlue,
                            ),
                            items: _programs
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedProgram = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Status Filter Toggle
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Present', 'Absent', 'All'].map((status) {
                        final isSelected = _statusFilter == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              status,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : TraceColors.navyBlue,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: status == 'Absent' ? TraceColors.error : TraceColors.navyBlue,
                            backgroundColor: Colors.white,
                            side: BorderSide(color: TraceColors.lightGrey.withValues(alpha: 0.5)),
                            onSelected: (val) {
                              if (val) setState(() => _statusFilter = status);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'List of students (${filteredData.length})',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TraceColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: filteredData.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No students found.',
                          style: GoogleFonts.inter(color: TraceColors.medGrey),
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = filteredData[index];
                      final studentData = item.studentData;
                      final isAbsent = item.attendance == null;
                      
                      final name = studentData['name'] ?? 'Unknown Student';
                      final course = (studentData['course'] ?? 'N/A')
                          .toString()
                          .toUpperCase();
                      final year = studentData['year_level'] ?? 'N/A';
                      final sId = studentData['student_id'] ?? 'N/A';
                      final avatarUrl = studentData['avatar_url'] ?? '';

                      String initials = '';
                      if (name.isNotEmpty) {
                        final parts = name.trim().split(' ');
                        if (parts.length > 1) {
                          initials = '${parts[0][0]}${parts.last[0]}'
                              .toUpperCase();
                        } else {
                          initials = name[0].toUpperCase();
                        }
                      }

                      ImageProvider? imageProvider;
                      if (avatarUrl.isNotEmpty) {
                        if (avatarUrl.startsWith('data:image')) {
                          try {
                            imageProvider = MemoryImage(
                              base64Decode(avatarUrl.split(',').last),
                            );
                          } catch (_) {}
                        } else {
                          imageProvider = NetworkImage(avatarUrl);
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TraceCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: TraceColors.royalBlue
                                    .withValues(alpha: 0.1),
                                backgroundImage: imageProvider,
                                child: imageProvider == null
                                    ? Text(
                                        initials,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w700,
                                          color: TraceColors.royalBlue,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: TraceColors.navyBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$course | $year | $sId',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: TraceColors.medGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isAbsent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: TraceColors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: TraceColors.error.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'ABSENT',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: TraceColors.error,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: filteredData.length),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildProgramStat(String program, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: TraceColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: TraceColors.royalBlue.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            program,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: TraceColors.navyBlue,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              '$count',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: TraceColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
