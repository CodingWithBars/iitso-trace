import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class TermsBottomSheet extends StatefulWidget {
  final VoidCallback onScrolledToBottom;

  const TermsBottomSheet({super.key, required this.onScrolledToBottom});

  @override
  State<TermsBottomSheet> createState() => _TermsBottomSheetState();
}

class _TermsBottomSheetState extends State<TermsBottomSheet> {
  bool _reachedBottom = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Privacy Policy & Terms',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: TraceColors.navyBlue,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                // Determine if user reached the bottom (with a small 20px threshold)
                if (scrollInfo.metrics.pixels >=
                    scrollInfo.metrics.maxScrollExtent - 20) {
                  if (!_reachedBottom) {
                    setState(() => _reachedBottom = true);
                    widget.onScrolledToBottom();
                  }
                }
                return false;
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRIVACY POLICY',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'trace ("the App", "we", "our", or "us") is committed to protecting the privacy of our students. This Privacy Policy explains how we collect, use, and safeguard your information when you interact with our digital attendance tracking system during school events.\n\n'
                      '1. Information We Collect\n'
                      'To provide an efficient and transparent attendance tracking service, the app processes minimal student data necessary for institutional record-keeping:\n'
                      '• Student Identification Data: Full Name, Student ID Number, and Course/Year/Section.\n'
                      '• Attendance Logs: System-generated timestamps of your event entry and exit logs (e.g., Morning In, Morning Out, Afternoon In, Afternoon Out) and the calculated final status (Present, Incomplete, Absent).\n'
                      '• Credential Data: Digital tokens associated with your Student ID barcode or assigned QR code used within the app.\n\n'
                      '2. How We Use Your Information\n'
                      'The collected data is strictly utilized for school-related operational workflows:\n'
                      '• To accurately record, monitor, and verify attendance at mandatory or elective school events.\n'
                      '• To evaluate eligibility for organization clearances, student filings, and campus milestone participation.\n'
                      '• To generate aggregated statistics regarding student engagement for campus reports.\n\n'
                      '3. Data Storage and Security\n'
                      'We implement strict technical and organizational security controls to protect your data from unauthorized access, alteration, or disclosure:\n'
                      '• Restricted Access: Attendance databases are strictly accessible only to authorized administrators and assigned university advisers.\n'
                      '• Data Retention: Attendance records are retained only for the duration of the current academic year or as required by institutional evaluation policies, after which they are securely archived or purged.\n\n'
                      '4. Sharing of Data\n'
                      'Your personal data will never be sold, rented, or shared with third-party commercial entities. Attendance logs may only be shared with:\n'
                      '• Campus Administration and Department Heads for official academic or clearance verification.\n'
                      '• Authorized institutional committees exclusively for evaluating official campus activity compliance.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'TERMS & CONDITIONS',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'By utilizing the trace application or presenting your student credentials at our digital scanning checkpoints, you agree to comply with and be bound by the following Terms and Conditions.\n\n'
                      '1. Account and Credential Accountability\n'
                      '• Students must use their own official credentials (ID cards, barcodes, or assigned system QR codes) within trace for attendance tracking.\n'
                      '• Strict Prohibition of Proxy Scanning: Scanning credentials belonging to another student, or allowing another student to scan your credentials, constitutes a breach of academic integrity and student code of conduct. Violations will result in the immediate forfeiture of attendance points for both parties and will be reported to the campus disciplinary board.\n\n'
                      '2. Scanning and Attendance Evaluation Rules\n'
                      '• Checkpoint Responsibility: It is the sole responsibility of the student to ensure they are successfully scanned at all designated event gates managed by trace (In and Out).\n'
                      '• System Logic Rules: Students acknowledge that missing a required scanning gate (e.g., timing in without timing out) will automatically cause the system to tag their status as Incomplete or Absent based on the event matrix rules.\n'
                      '• Gate Windows: Scanning gates open and close dynamically according to established event schedules. Scans attempted outside designated system windows will not be recorded by trace.\n\n'
                      '3. Disputes and Discrepancies\n'
                      '• If a student believes there has been a technical error in their attendance calculation (e.g., a failed hardware scan despite physical presence), they must file an appeal with system administrators within three (3) school days following the conclusion of the event.\n'
                      '• Appeals must be accompanied by valid proof of attendance (e.g., physical marshal verification or designated venue documentation). Corrections requested after this window will not be entertained.\n\n'
                      '4. Modifications to the System\n'
                      'The technical administrators reserve the right to modify, pause, or upgrade the application, scanning windows, or evaluation rules to improve operations, provided that any major workflow updates are communicated transparently to the student body prior to execution.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Center(
                      child: Text(
                        _reachedBottom
                            ? 'You may now close this and check the box.'
                            : 'Please scroll to the bottom to continue.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _reachedBottom
                              ? Colors.green
                              : TraceColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 48,
                    ), // Padding at bottom so they can scroll past the text easily
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
