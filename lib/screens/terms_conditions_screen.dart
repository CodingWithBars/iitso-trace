import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: AppBar(
        backgroundColor: TraceColors.navyBlue,
        title: Text(
          'Terms & Conditions',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TERMS & CONDITIONS',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: TraceColors.navyBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last Updated: July 31, 2026',
                style: GoogleFonts.inter(color: TraceColors.medGrey),
              ),
              const SizedBox(height: 24),

              Text(
                'By utilizing the trace application or presenting your student credentials at our digital scanning checkpoints, you agree to comply with and be bound by the following Terms and Conditions.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: TraceColors.navyBlue.withValues(alpha: 0.8),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),

              _buildSection(
                '1. Account and Credential Accountability',
                '• Students must use their own official credentials (ID cards, barcodes, or assigned system QR codes) within trace for attendance tracking.\n\n'
                    '• Strict Prohibition of Proxy Scanning: Scanning credentials belonging to another student, or allowing another student to scan your credentials, constitutes a breach of academic integrity and student code of conduct. Violations will result in the immediate forfeiture of attendance points for both parties and will be reported to the campus disciplinary board.',
              ),

              _buildSection(
                '2. Scanning and Attendance Evaluation Rules',
                '• Checkpoint Responsibility: It is the sole responsibility of the student to ensure they are successfully scanned at all designated event gates managed by trace (In and Out).\n\n'
                    '• System Logic Rules: Students acknowledge that missing a required scanning gate (e.g., timing in without timing out) will automatically cause the system to tag their status as Incomplete or Absent based on the event matrix rules.\n\n'
                    '• Gate Windows: Scanning gates open and close dynamically according to established event schedules. Scans attempted outside designated system windows will not be recorded by trace.',
              ),

              _buildSection(
                '3. Disputes and Discrepancies',
                '• If a student believes there has been a technical error in their attendance calculation (e.g., a failed hardware scan despite physical presence), they must file an appeal with system administrators within three (3) school days following the conclusion of the event.\n\n'
                    '• Appeals must be accompanied by valid proof of attendance (e.g., physical marshal verification or designated venue documentation). Corrections requested after this window will not be entertained.',
              ),

              _buildSection(
                '4. Modifications to the System',
                'The technical administrators reserve the right to modify, pause, or upgrade the application, scanning windows, or evaluation rules to improve operations, provided that any major workflow updates are communicated transparently to the student body prior to execution.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: TraceColors.navyBlue,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: TraceColors.navyBlue.withValues(alpha: 0.8),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
