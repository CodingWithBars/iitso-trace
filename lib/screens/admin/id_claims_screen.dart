import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';

class IdClaimsScreen extends StatelessWidget {
  const IdClaimsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: TraceAppBar(title: 'ID Claim Petitions', showBackButton: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.db
            .collection('id_claims')
            .orderBy('submitted_at', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: TraceColors.navyBlue),
            );
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 64,
                    color: TraceColors.lightGrey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending claims',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      color: TraceColors.medGrey,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return _ClaimCard(docId: doc.id, data: data);
            },
          );
        },
      ),
    );
  }
}

class _ClaimCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _ClaimCard({required this.docId, required this.data});

  @override
  State<_ClaimCard> createState() => _ClaimCardState();
}

class _ClaimCardState extends State<_ClaimCard> {
  bool _isProcessing = false;

  String _formatDate(dynamic ts) {
    if (ts == null) return '--';
    try {
      return DateFormat(
        'MMM dd, yyyy • h:mm a',
      ).format((ts as Timestamp).toDate());
    } catch (_) {
      return '--';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return TraceColors.success;
      case 'rejected':
        return TraceColors.error;
      default:
        return TraceColors.warning;
    }
  }

  Future<void> _approve() async {
    final claimedId = widget.data['claimed_student_id'] as String? ?? '';
    final claimantName = widget.data['claimant_name'] as String? ?? '';
    final claimantEmail = widget.data['claimant_email'] as String? ?? '';

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Approve Claim?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: TraceColors.navyBlue,
          ),
        ),
        content: Text(
          'How do you want to handle the records for Student ID "$claimedId"?\n\n'
          '• Restore Records: (For legitimate students recovering their account) Keep their old attendance/payments, just update their email to "$claimantEmail".\n\n'
          '• Discard Records: (For kicking out fraudsters) Archive the old records away from this ID, giving the legitimate student a fresh empty account.',
          style: GoogleFonts.inter(fontSize: 14, color: TraceColors.navyBlue),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            style: TextButton.styleFrom(foregroundColor: TraceColors.error),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TraceColors.success,
            ),
            onPressed: () => Navigator.pop(context, 'restore'),
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == null || result == 'cancel') return;
    final keepRecords = result == 'restore';

    setState(() => _isProcessing = true);
    try {
      final snap = await FirestoreService.students
          .where('student_id', isEqualTo: claimedId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) throw 'Student ID not found in database.';
      await StudentService.approveIdClaim(
        claimDocId: widget.docId,
        studentDocId: snap.docs.first.id,
        newName: claimantName,
        newEmail: claimantEmail,
        keepRecords: keepRecords,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim approved & student record updated.'),
            backgroundColor: TraceColors.success,
          ),
        );
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
    }
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Reject Claim?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: TraceColors.navyBlue,
          ),
        ),
        content: Text(
          'This will mark the petition as rejected.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TraceColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isProcessing = true);
    await StudentService.rejectIdClaim(widget.docId);
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.data['status'] as String? ?? 'pending';
    final proofUrl = widget.data['proof_image_url'] as String? ?? '';
    final isPending = status == 'pending';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _statusColor(status).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Claim for ID: ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: TraceColors.medGrey,
                  ),
                ),
                Text(
                  widget.data['claimed_student_id'] ?? '--',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: TraceColors.navyBlue,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _statusColor(status),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row(
                  Icons.person_outline,
                  'Name',
                  widget.data['claimant_name'] ?? '--',
                ),
                const SizedBox(height: 8),
                _row(
                  Icons.email_outlined,
                  'Email',
                  widget.data['claimant_email'] ?? '--',
                ),
                const SizedBox(height: 8),
                _row(
                  Icons.access_time,
                  'Submitted',
                  _formatDate(widget.data['submitted_at']),
                ),
                const SizedBox(height: 12),
                Text(
                  'Reason:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: TraceColors.medGrey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.data['reason'] ?? '--',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: TraceColors.navyBlue,
                    height: 1.5,
                  ),
                ),

                // Proof image
                if (proofUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Proof:',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: TraceColors.medGrey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showFullImage(context, proofUrl),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: proofUrl.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(proofUrl.split(',').last),
                                fit: BoxFit.cover,
                              )
                            : Image.network(proofUrl, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ],

                if (isPending) ...[
                  const SizedBox(height: 16),
                  _isProcessing
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: TraceColors.navyBlue,
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _reject,
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Reject'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: TraceColors.error,
                                  side: const BorderSide(
                                    color: TraceColors.error,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _approve,
                                icon: const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'Approve',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TraceColors.success,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: TraceColors.medGrey),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.inter(fontSize: 13, color: TraceColors.medGrey),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: TraceColors.navyBlue,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showFullImage(BuildContext ctx, String url) {
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: url.startsWith('data:image')
            ? Image.memory(base64Decode(url.split(',').last))
            : Image.network(url),
      ),
    );
  }
}
