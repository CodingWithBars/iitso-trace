import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/attendance_service.dart';
import '../../models/attendance.dart';
import '../../theme/app_theme.dart';
import '../../models/event.dart';
import '../../widgets/shared_widgets.dart';
import '../../services/csv_report_service.dart';
import '../../services/financial_service.dart';
import '../../services/auth_service.dart';

class EventAttendanceScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventAttendanceScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventAttendanceScreen> createState() => _EventAttendanceScreenState();
}

class StudentAttendanceDisplay {
  final Map<String, dynamic> studentData;
  final Attendance? attendance;
  StudentAttendanceDisplay(this.studentData, this.attendance);
}

class _EventAttendanceScreenState extends ConsumerState<EventAttendanceScreen> {
  bool _isLoading = true;
  String _eventName = 'Attendance';
  Event? _event;

  List<Attendance> _allAttendance = [];
  final Map<String, Map<String, dynamic>> _studentsMap = {};

  String _searchQuery = '';
  String _selectedYear = 'All';
  String _statusFilter = 'All'; // 'All', 'Present', 'Pending', 'Absent', 'Late', 'Excused'
  final List<String> _years = ['All', '1st Year', '2nd Year', '3rd Year', '4th Year'];

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
        _event = Event.fromMap(eventDoc.data()!, eventDoc.id);
        _eventName = _event?.eventName ?? 'Attendance';
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

  Future<void> _applySanctions() async {
    final event = _event;
    if (event == null) return;
    final role = ref.read(adminRoleProvider).value;
    final recordedBy = ref.read(authServiceProvider).currentUser?.email ?? 'Admin';
    
    // Check permission
    if (role != 'superadmin' && role != 'admin' && role != 'treasurer') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to apply sanctions.')),
        );
      }
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply Sanctions'),
        content: Text(
          event.sanctionAmount != null && event.sanctionAmount! > 0
              ? 'This will create a ₱${event.sanctionAmount!.toStringAsFixed(2)} sanction record for every student NOT in attendance. Continue?'
              : 'This will create a non-monetary sanction record (${event.sanctionDescription}) for every student NOT in attendance. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TraceColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    final count = await FinancialService.applyEventSanctions(event, recordedBy);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count sanction record(s) created for absent students.'),
          backgroundColor: count > 0 ? TraceColors.error : TraceColors.medGrey,
        ),
      );
    }
  }

  Future<void> _applyContributions() async {
    final event = _event;
    if (event == null || (event.eventContribution ?? 0) <= 0) return;
    final recordedBy = ref.read(authServiceProvider).currentUser?.email ?? 'Admin';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply Event Contribution'),
        content: Text(
          'This will create a ₱${event.eventContribution!.toStringAsFixed(2)} contribution obligation for ALL registered students. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TraceColors.navyBlue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !mounted) return;
    
    final count = await FinancialService.applyEventContribution(event, recordedBy);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count contribution record(s) created for students.'),
          backgroundColor: TraceColors.navyBlue,
        ),
      );
    }
  }

  Future<double?> _showLateHoursDialog() async {
    final TextEditingController controller = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Late Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How many hours was the student late?'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'e.g., 1.5',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TraceColors.navyBlue),
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val >= 0) {
                Navigator.pop(ctx, val);
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _markIndividualStatus(
    String sId,
    Map<String, dynamic> studentData,
    String status,
    Attendance? existingAtt,
  ) async {
    if (_event == null) return;
    
    double? manualLateHours;
    if (status == 'Late') {
      manualLateHours = await _showLateHoursDialog();
      if (manualLateHours == null) return; // user cancelled
    }

    setState(() => _isLoading = true);

    try {
      if (existingAtt != null) {
        final updateData = <String, dynamic>{'final_status': status};
        if (manualLateHours != null) updateData['manual_late_hours'] = manualLateHours;
        await FirebaseFirestore.instance.collection('attendance').doc(existingAtt.id).update(updateData);
      } else {
        final newData = <String, dynamic>{
          'event_id': _event!.id,
          'student_id': sId,
          'student_name': studentData['name'] ?? 'Unknown',
          'event_name': _eventName,
          'final_status': status,
          'created_at': Timestamp.now(),
          'date': Timestamp.now(),
          'is_offline_scan': false,
        };
        if (manualLateHours != null) newData['manual_late_hours'] = manualLateHours;
        await FirebaseFirestore.instance.collection('attendance').add(newData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Student marked as $status.'),
            backgroundColor: TraceColors.navyBlue,
          ),
        );
      }
      await _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: TraceColors.error),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _bulkMarkStatus(String status) async {
    if (_event == null) return;
    
    double? manualLateHours;
    if (status == 'Late') {
      manualLateHours = await _showLateHoursDialog();
      if (manualLateHours == null) return; // cancelled
    }

    // Guard: widget may have been disposed while _showLateHoursDialog was open
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mark Missing as $status'),
        content: Text('Assign "$status" status to all students without an attendance record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TraceColors.navyBlue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    
    try {
      int count = 0;
      final batch = FirebaseFirestore.instance.batch();
      
      for (var entry in _studentsMap.entries) {
        final sId = entry.key;
        final studentData = entry.value;
        final att = _allAttendance.cast<Attendance?>().firstWhere((a) => a?.studentId == sId, orElse: () => null);
        
        if (att == null) {
          final docRef = FirebaseFirestore.instance.collection('attendance').doc();
          final newData = <String, dynamic>{
            'event_id': _event!.id,
            'student_id': sId,
            'student_name': studentData['name'] ?? 'Unknown',
            'event_name': _eventName,
            'final_status': status,
            'created_at': Timestamp.now(),
            'date': Timestamp.now(),
            'is_offline_scan': false,
          };
          if (manualLateHours != null) newData['manual_late_hours'] = manualLateHours;
          batch.set(docRef, newData);
          count++;
        }
      }
      
      if (count > 0) {
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$count students marked as $status.'),
              backgroundColor: TraceColors.navyBlue,
            ),
          );
        }
        await _fetchData(); // Reload data
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All students already have attendance records.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: TraceColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Map<String, int> _getYearTotals() {
    final totals = {'1ST YEAR': 0, '2ND YEAR': 0, '3RD YEAR': 0, '4TH YEAR': 0};
    for (var att in _allAttendance) {
      final studentData = _studentsMap[att.studentId];
      if (studentData != null) {
        final year = (studentData['year_level']?.toString() ?? '').toUpperCase();
        if (totals.containsKey(year)) {
          totals[year] = totals[year]! + 1;
        }
      }
    }
    return totals;
  }

  Map<String, int> _getYearTotalStudents() {
    final totals = {'1ST YEAR': 0, '2ND YEAR': 0, '3RD YEAR': 0, '4TH YEAR': 0};
    for (var student in _studentsMap.values) {
      final year = (student['year_level']?.toString() ?? '').toUpperCase();
      if (totals.containsKey(year)) {
        totals[year] = totals[year]! + 1;
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

      final attStatus = isPresent 
          ? att.finalStatus.toLowerCase() 
          : (_event?.computedStatus == 'upcoming' ? 'pending' : 'absent');

      if (_statusFilter != 'All') {
        if (_statusFilter == 'Pending' && attStatus != 'pending') continue;
        if (_statusFilter == 'Absent' && attStatus != 'absent') continue;
        if (_statusFilter == 'Late' && attStatus != 'late') continue;
        if (_statusFilter == 'Excused' && attStatus != 'excused') continue;
        if (_statusFilter == 'Present') {
          if (attStatus == 'pending' || attStatus == 'absent' || attStatus == 'late' || attStatus == 'excused') {
            continue;
          }
        }
      }

      final year = (studentData['year_level']?.toString() ?? '').toLowerCase();
      final name = (studentData['name']?.toString() ?? '').toLowerCase();
      final studentIdStr = (studentData['student_id']?.toString() ?? '').toLowerCase();

      // Year filter
      if (_selectedYear != 'All') {
        final selectedYearLower = _selectedYear.toLowerCase();
        if (year != selectedYearLower) {
          continue;
        }
      }

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

    final totals = _getYearTotals();
    final totalStudents = _getYearTotalStudents();
    final filteredData = _getFilteredData();

    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: TraceAppBar(
        title: _eventName,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: TraceColors.white),
            tooltip: 'Export CSV',
            onPressed: () async {
              await CsvReportService.generateAttendanceCsv(
                _eventName,
                filteredData,
                _event?.computedStatus ?? 'past',
              );
            },
          ),
          const SizedBox(width: 8),
        ],
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
                    'Year Level Attendance',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TraceColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Horizontal scrolling row for Programs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildProgramStat('1st Year', totals['1ST YEAR'] ?? 0, totalStudents['1ST YEAR'] ?? 0),
                        const SizedBox(width: 8),
                        _buildProgramStat('2nd Year', totals['2ND YEAR'] ?? 0, totalStudents['2ND YEAR'] ?? 0),
                        const SizedBox(width: 8),
                        _buildProgramStat('3rd Year', totals['3RD YEAR'] ?? 0, totalStudents['3RD YEAR'] ?? 0),
                        const SizedBox(width: 8),
                        _buildProgramStat('4th Year', totals['4TH YEAR'] ?? 0, totalStudents['4TH YEAR'] ?? 0),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Accountability banner (shows if event has sanctions/contributions set)
                  if (_event != null && 
                      ((_event!.sanctionAmount ?? 0) > 0 ||
                       (_event!.sanctionDescription?.isNotEmpty ?? false) ||
                       (_event!.eventContribution ?? 0) > 0)) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: TraceColors.navyBlue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: TraceColors.navyBlue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Accountability',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    color: TraceColors.navyBlue,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if ((_event!.sanctionAmount ?? 0) > 0)
                                  Text(
                                    '⚖️  Sanction for absent: ₱${_event!.sanctionAmount!.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(fontSize: 12, color: TraceColors.error),
                                  ),
                                if (_event!.sanctionDescription?.isNotEmpty ?? false)
                                  Text(
                                    '⚖️  Sanction for absent: ${_event!.sanctionDescription}',
                                    style: GoogleFonts.inter(fontSize: 12, color: TraceColors.error),
                                  ),
                                if ((_event!.eventContribution ?? 0) > 0)
                                  Text(
                                    '💰  Event contribution: ₱${_event!.eventContribution!.toStringAsFixed(2)} per student',
                                    style: GoogleFonts.inter(fontSize: 12, color: TraceColors.royalBlue),
                                  ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, color: TraceColors.navyBlue),
                            tooltip: 'Bulk Actions',
                            onSelected: (value) {
                              if (value == 'excused') _bulkMarkStatus('Excused');
                              if (value == 'absent') _bulkMarkStatus('Absent');
                              if (value == 'sanctions') _applySanctions();
                              if (value == 'contributions') _applyContributions();
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'excused',
                                child: Text('Mark Missing as Excused', style: GoogleFonts.inter(fontSize: 13)),
                              ),
                              PopupMenuItem(
                                value: 'absent',
                                child: Text('Mark Missing as Absent', style: GoogleFonts.inter(fontSize: 13)),
                              ),
                              if ((_event!.sanctionAmount ?? 0) > 0 ||
                                  (_event!.sanctionDescription?.isNotEmpty ?? false))
                                PopupMenuItem(
                                  value: 'sanctions',
                                  child: Text('Apply Sanctions to Absentees', style: GoogleFonts.inter(fontSize: 13, color: TraceColors.error)),
                                ),
                              if ((_event!.eventContribution ?? 0) > 0)
                                PopupMenuItem(
                                  value: 'contributions',
                                  child: Text('Assign Contribution to All', style: GoogleFonts.inter(fontSize: 13, color: TraceColors.navyBlue)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

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
                            value: _selectedYear,
                            icon: const Icon(
                              Icons.filter_list,
                              color: TraceColors.navyBlue,
                            ),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: TraceColors.navyBlue,
                            ),
                            items: _years
                                .map(
                                  (y) => DropdownMenuItem(
                                    value: y,
                                    child: Text(y),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedYear = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Status Filter Toggle
                  // Status Filter Toggle
                  ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                      },
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['All', 'Present', 'Pending', 'Absent', 'Late', 'Excused'].map((status) {
                          final isSelected = _statusFilter == status;
                          Color activeColor;
                          switch (status) {
                            case 'Present': activeColor = TraceColors.success; break;
                            case 'Pending': activeColor = Colors.grey; break;
                            case 'Absent': activeColor = TraceColors.error; break;
                            case 'Late': activeColor = Colors.orange; break;
                            case 'Excused': activeColor = Colors.yellow.shade700; break;
                            default: activeColor = TraceColors.navyBlue;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                status,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : activeColor,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: activeColor,
                              backgroundColor: Colors.white,
                              side: BorderSide(color: isSelected ? activeColor : TraceColors.lightGrey.withValues(alpha: 0.5)),
                              onSelected: (val) {
                                if (val) setState(() => _statusFilter = status);
                              },
                            ),
                          );
                        }).toList(),
                      ),
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
                              Builder(
                                builder: (context) {
                                  final String statusText;
                                  final Color statusColor;
                                  if (isAbsent) {
                                    statusText = _event?.computedStatus == 'upcoming' ? 'PENDING' : 'ABSENT';
                                    statusColor = _event?.computedStatus == 'upcoming' ? Colors.grey : TraceColors.error;
                                  } else {
                                    statusText = (item.attendance?.finalStatus.toUpperCase() ?? 'PRESENT');
                                    switch (statusText) {
                                      case 'PENDING': statusColor = Colors.grey; break;
                                      case 'ABSENT': statusColor = TraceColors.error; break;
                                      case 'LATE': statusColor = Colors.orange; break;
                                      case 'EXCUSED': statusColor = Colors.yellow.shade700; break;
                                      case 'PRESENT':
                                      default: statusColor = TraceColors.success;
                                    }
                                  }

                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: statusColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: TraceColors.navyBlue, size: 20),
                                tooltip: 'Update Status',
                                onSelected: (val) => _markIndividualStatus(sId, studentData, val, item.attendance),
                                itemBuilder: (context) => [
                                  PopupMenuItem(value: 'Present', child: Text('Mark Present', style: GoogleFonts.inter(fontSize: 13))),
                                  PopupMenuItem(value: 'Absent', child: Text('Mark Absent', style: GoogleFonts.inter(fontSize: 13))),
                                  PopupMenuItem(value: 'Excused', child: Text('Mark Excused', style: GoogleFonts.inter(fontSize: 13))),
                                  PopupMenuItem(value: 'Late', child: Text('Mark Late', style: GoogleFonts.inter(fontSize: 13))),
                                ],
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

  Widget _buildProgramStat(String program, int count, int totalStudents) {
    return Container(
      width: 140, // Fixed width for horizontal scrolling list
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: TraceColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: TraceColors.royalBlue.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                program,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: TraceColors.navyBlue,
                ),
              ),
              Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: TraceColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'total: $totalStudents',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: TraceColors.medGrey,
            ),
          ),
        ],
      ),
    );
  }
}
