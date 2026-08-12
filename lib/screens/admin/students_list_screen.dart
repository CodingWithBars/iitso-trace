import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';

class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({super.key});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  String _selectedYear = 'All';
  bool _sortAscending = true;
  String _searchQuery = '';
  final List<String> _years = [
    'All',
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
  ];

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
        actions: [
          IconButton(
            icon: const Icon(Icons.restore_page_rounded, color: TraceColors.white),
            tooltip: 'Restore Archived Records',
            onPressed: () => _showRestoreRecordsDialog(),
          ),
        ],
        title: Text(
          'List of Students',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: TraceColors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tabs
            Container(
              color: TraceColors.navyBlue,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: _years.asMap().entries.map((entry) {
                  final i = entry.key;
                  final year = entry.value;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedYear = year),
                      child: Container(
                        margin: EdgeInsets.only(
                          right: i == _years.length - 1 ? 0 : 8,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _selectedYear == year
                              ? TraceColors.gold
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: _selectedYear == year
                              ? null
                              : Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          year,
                          style: GoogleFonts.inter(
                            color: _selectedYear == year
                                ? TraceColors.navyBlue
                                : TraceColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12, // slightly smaller to fit 5 items
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.db.collection('students').snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allDocs = snap.data?.docs ?? [];
                  var filteredDocs = _selectedYear == 'All'
                      ? allDocs
                      : allDocs.where((doc) {
                          final yearLevel =
                              (doc.data() as Map<String, dynamic>)['year_level']
                                  ?.toString() ??
                              '';
                          return yearLevel == _selectedYear;
                        }).toList();

                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    filteredDocs = filteredDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      final id = (data['student_id'] ?? '').toString().toLowerCase();
                      final course = (data['course'] ?? '').toString().toLowerCase();
                      return name.contains(q) || id.contains(q) || course.contains(q);
                    }).toList();
                  }

                  filteredDocs.sort((a, b) {
                    final nameA =
                        ((a.data() as Map<String, dynamic>)['name'] ?? '')
                            .toString()
                            .toLowerCase();
                    final nameB =
                        ((b.data() as Map<String, dynamic>)['name'] ?? '')
                            .toString()
                            .toLowerCase();
                    return _sortAscending
                        ? nameA.compareTo(nameB)
                        : nameB.compareTo(nameA);
                  });

                  return Column(
                    children: [
                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search by name, ID, or course...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 16,
                            ),
                            fillColor: Colors.white,
                            filled: true,
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Text(
                              'Total Student: ${filteredDocs.length}',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: TraceColors.navyBlue,
                              ),
                            ),
                            const Spacer(),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<bool>(
                                value: _sortAscending,
                                icon: const Icon(
                                  Icons.sort_by_alpha,
                                  size: 20,
                                  color: TraceColors.navyBlue,
                                ),
                                isDense: true,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: TraceColors.navyBlue,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: true,
                                    child: Text('A-Z'),
                                  ),
                                  DropdownMenuItem(
                                    value: false,
                                    child: Text('Z-A'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _sortAscending = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: filteredDocs.isEmpty
                            ? Center(
                                child: Text(
                                  'No students found for this year level.',
                                  style: GoogleFonts.inter(
                                    color: TraceColors.medGrey,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: filteredDocs.length,
                                itemBuilder: (ctx, i) {
                                  final data =
                                      filteredDocs[i].data()
                                          as Map<String, dynamic>;
                                  final name = data['name'] ?? 'Unknown';
                                  final course = data['course'] ?? '';
                                  final year = data['year_level'] ?? '';
                                  final studentId = data['student_id'] ?? '';
                                  final avatarUrl = data['avatar_url'] ?? '';
                                  final initials = name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: TraceColors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: TraceColors.navyBlue
                                              .withValues(alpha: 0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () {
                                          if (studentId.isNotEmpty) {
                                            context.push('/admin/students/$studentId');
                                          }
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor: TraceColors.royalBlue
                                              .withValues(alpha: 0.1),
                                          backgroundImage: _getAvatarProvider(
                                            avatarUrl,
                                          ),
                                          child: avatarUrl.isEmpty
                                              ? Text(
                                                  initials,
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        TraceColors.royalBlue,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: TraceColors.navyBlue,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '$course | $year | $studentId',
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  color: TraceColors.medGrey,
                                                ),
                                              ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  void _showRestoreRecordsDialog() {
    final emailCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    bool isRestoring = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(
            'Restore Archived Records',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the incorrect email used by the student to retrieve their archived records and transfer them to their correct Student ID.',
                style: GoogleFonts.inter(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Wrong/Archived Email',
                  hintText: 'e.g. wrong@gmail.com',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: idCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correct Student ID',
                  hintText: 'e.g. 2024-0001',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: TraceColors.gold),
              onPressed: isRestoring
                  ? null
                  : () async {
                      final wrongEmail = emailCtrl.text.trim();
                      final correctId = idCtrl.text.trim();
                      if (wrongEmail.isEmpty || correctId.isEmpty) return;

                      setLocal(() => isRestoring = true);
                      try {
                        final restoredCount =
                            await StudentService.restoreArchivedRecords(
                          wrongEmail: wrongEmail,
                          correctStudentId: correctId,
                          adminName: 'Admin', // Placeholder for admin name
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                restoredCount > 0
                                    ? 'Successfully restored $restoredCount records.'
                                    : 'No archived records found for $wrongEmail.',
                              ),
                              backgroundColor: restoredCount > 0
                                  ? TraceColors.success
                                  : TraceColors.error,
                            ),
                          );
                        }
                      } catch (e) {
                        setLocal(() => isRestoring = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error restoring records: $e'),
                              backgroundColor: TraceColors.error,
                            ),
                          );
                        }
                      }
                    },
              child: isRestoring
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Restore', style: GoogleFonts.inter(color: TraceColors.navyBlue, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
