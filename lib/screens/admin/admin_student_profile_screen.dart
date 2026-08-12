import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class AdminStudentProfileScreen extends StatelessWidget {
  final String studentId;

  const AdminStudentProfileScreen({super.key, required this.studentId});

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
        title: Text(
          'Student Profile',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: TraceColors.white,
          ),
        ),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirestoreService.db
            .collection('students')
            .where('student_id', isEqualTo: studentId)
            .limit(1)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Student not found.'));
          }

          final studentData =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final name = studentData['name'] ?? 'Unknown';
          final course = studentData['course'] ?? '';
          final year = studentData['year_level'] ?? '';
          final email = studentData['email'] ?? 'No email';
          final avatarUrl = studentData['avatar_url'] ?? '';
          final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar Profile Header
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: TraceColors.royalBlue.withValues(alpha: 0.1),
                    backgroundImage: _getAvatarProvider(avatarUrl),
                    child: avatarUrl.isEmpty
                        ? Text(
                            initials,
                            style: GoogleFonts.inter(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: TraceColors.royalBlue,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: TraceColors.navyBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '$course | $year | $studentId',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: TraceColors.medGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  email,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: TraceColors.medGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Obligations Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Financial Obligations',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: TraceColors.navyBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildObligationsList(),
                
                const SizedBox(height: 32),
                
                // Attendance Section
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Attendance History',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: TraceColors.navyBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildAttendanceList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildObligationsList() {
    return FutureBuilder<QuerySnapshot>(
      future: FirestoreService.db
          .collection('student_obligations')
          .where('student_id', isEqualTo: studentId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'No financial obligations found.',
              style: GoogleFonts.inter(color: TraceColors.medGrey),
              textAlign: TextAlign.center,
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Obligation';
            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
            final amountPaid = (data['amount_paid'] as num?)?.toDouble() ?? 0.0;
            final status = data['status'] ?? 'unpaid';

            Color statusColor;
            switch (status) {
              case 'paid':
                statusColor = TraceColors.success;
                break;
              case 'partially_paid':
                statusColor = TraceColors.warning;
                break;
              default:
                statusColor = TraceColors.error;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: TraceColors.navyBlue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₱${amountPaid.toStringAsFixed(2)} / ₱${amount.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            color: TraceColors.medGrey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceList() {
    return FutureBuilder<QuerySnapshot>(
      future: FirestoreService.db
          .collection('attendance')
          .where('student_id', isEqualTo: studentId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              'No attendance records found.',
              style: GoogleFonts.inter(color: TraceColors.medGrey),
              textAlign: TextAlign.center,
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final eventId = data['event_id'] ?? 'Unknown Event';
            final status = data['status'] ?? 'Unknown';

            Color statusColor;
            if (status == 'Present') {
              statusColor = TraceColors.success;
            } else if (status == 'Half-Day' || status.contains('Partial')) {
              statusColor = TraceColors.warning;
            } else {
              statusColor = TraceColors.error;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Event ID: $eventId',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: TraceColors.navyBlue,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
