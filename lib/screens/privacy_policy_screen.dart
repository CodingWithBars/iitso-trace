import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: AppBar(
        backgroundColor: TraceColors.navyBlue,
        title: Text(
          'Privacy Policy',
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
                'PRIVACY POLICY',
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
                'trace ("the App", "we", "our", or "us") is committed to protecting the privacy of our students. This Privacy Policy explains how we collect, use, and safeguard your information when you interact with our digital attendance tracking system during school events.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: TraceColors.navyBlue.withValues(alpha: 0.8),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),

              _buildSection(
                '1. Information We Collect',
                'To provide an efficient and transparent attendance tracking service, the app processes minimal student data necessary for institutional record-keeping:\n\n'
                    '• Student Identification Data: Full Name, Student ID Number, and Course/Year/Section.\n\n'
                    '• Attendance Logs: System-generated timestamps of your event entry and exit logs (e.g., Morning In, Morning Out, Afternoon In, Afternoon Out) and the calculated final status (Present, Incomplete, Absent).\n\n'
                    '• Credential Data: Digital tokens associated with your Student ID barcode or assigned QR code used within the app.',
              ),

              _buildSection(
                '2. How We Use Your Information',
                'The collected data is strictly utilized for school-related operational workflows:\n\n'
                    '• To accurately record, monitor, and verify attendance at mandatory or elective school events.\n\n'
                    '• To evaluate eligibility for organization clearances, student filings, and campus milestone participation.\n\n'
                    '• To generate aggregated statistics regarding student engagement for campus reports.',
              ),

              _buildSection(
                '3. Data Storage and Security',
                'We implement strict technical and organizational security controls to protect your data from unauthorized access, alteration, or disclosure:\n\n'
                    '• Restricted Access: Attendance databases are strictly accessible only to authorized administrators and assigned university advisers.\n\n'
                    '• Data Retention: Attendance records are retained only for the duration of the current academic year or as required by institutional evaluation policies, after which they are securely archived or purged.',
              ),

              _buildSection(
                '4. Sharing of Data',
                'Your personal data will never be sold, rented, or shared with third-party commercial entities. Attendance logs may only be shared with:\n\n'
                    '• Campus Administration and Department Heads for official academic or clearance verification.\n\n'
                    '• Authorized institutional committees exclusively for evaluating official campus activity compliance.',
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
