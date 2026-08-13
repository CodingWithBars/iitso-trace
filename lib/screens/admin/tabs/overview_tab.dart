import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/admin_widgets.dart';
import '../../../services/auth_service.dart';
import '../../../services/csv_report_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class OverviewTab extends ConsumerWidget {
  final VoidCallback onNewEvent;
  final VoidCallback onAttendance;
  final VoidCallback onPostNews;
  final VoidCallback onAddFund;
  final VoidCallback onAddAdmin;

  const OverviewTab({
    super.key,
    required this.onNewEvent,
    required this.onAttendance,
    required this.onPostNews,
    required this.onAddFund,
    required this.onAddAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(adminRoleProvider).value;
    final canManageAdmins = role == 'superadmin';
    final canManageFunds = role == 'superadmin' || role == 'auditor';

    void showAccessDenied(String message) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: TraceColors.error),
              SizedBox(width: 8),
              Text('Access Denied', style: TextStyle(color: TraceColors.error)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: TraceColors.navyBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Here's a summary of all recent activity.",
            style: GoogleFonts.inter(fontSize: 14, color: TraceColors.medGrey),
          ),
          const SizedBox(height: 24),
          // Live stats grid from Firestore
          StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.db.collection('students').snapshots(),
            builder: (ctx, studentSnap) => StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.db.collection('events').snapshots(),
              builder: (ctx, eventSnap) => StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.db.collection('funds').snapshots(),
                builder: (ctx, fundsSnap) => StreamBuilder<QuerySnapshot>(
                  stream: FirestoreService.db
                      .collection('attendance')
                      .where(
                        'created_at',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(
                          DateTime(
                            DateTime.now().year,
                            DateTime.now().month,
                            DateTime.now().day,
                          ),
                        ),
                      )
                      .snapshots(),
                  builder: (ctx, attendSnap) => StreamBuilder<QuerySnapshot>(
                    stream: FirestoreService.db
                        .collection('id_claims')
                        .where('status', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (ctx, claimsSnap) {
                      final studentCount = studentSnap.hasData
                          ? studentSnap.data!.docs.length
                          : 0;
                      final eventCount = eventSnap.hasData
                          ? eventSnap.data!.docs.length
                          : 0;
                      final pendingClaimsCount = claimsSnap.hasData
                          ? claimsSnap.data!.docs.length
                          : 0;
                      double income = 0;
                      double expense = 0;
                      if (fundsSnap.hasData) {
                        for (final d in fundsSnap.data!.docs) {
                          final data = d.data() as Map<String, dynamic>;
                          if (data['type'] == 'income' ||
                              data['type'] == 'contribution') {
                            income += (data['amount'] ?? 0).toDouble();
                          } else if (data['type'] == 'expense') {
                            expense += (data['amount'] ?? 0).toDouble();
                          }
                        }
                      }
                      final todayScans = attendSnap.hasData
                          ? attendSnap.data!.docs.length
                          : 0;

                      return LayoutBuilder(
                        builder: (ctx, constraints) {
                          final isWide = constraints.maxWidth > 600;

                          Widget buildCard(
                            Widget child, {
                            bool fullWidth = false,
                          }) {
                            return AspectRatio(
                              aspectRatio: isWide
                                  ? 2.0
                                  : (fullWidth ? 4.0 : 2.0),
                              child: child,
                            );
                          }

                          if (isWide) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: buildCard(
                                        AdminStatCard(
                                          label: 'Collected',
                                          value:
                                              '₱${NumberFormat('#,##0.00', 'en_US').format(income)}',
                                          icon: Icons
                                              .account_balance_wallet_rounded,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: buildCard(
                                        AdminStatCard(
                                          label: 'Expenses',
                                          value:
                                              '₱${NumberFormat('#,##0.00', 'en_US').format(expense)}',
                                          icon: Icons.money_off_rounded,
                                          color: TraceColors.error,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: buildCard(
                                        AdminStatCard(
                                          label: 'Events',
                                          value: eventCount.toString(),
                                          icon: Icons.event_rounded,
                                          color: TraceColors.gold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: buildCard(
                                        GestureDetector(
                                          onTap: () =>
                                              context.push('/admin/students'),
                                          child: AdminStatCard(
                                            label: 'Students',
                                            value: studentCount.toString(),
                                            icon: Icons.people_rounded,
                                            color: TraceColors.royalBlue,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: buildCard(
                                        AdminStatCard(
                                          label: 'Scans Today',
                                          value: todayScans.toString(),
                                          icon: Icons.qr_code_scanner_rounded,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: buildCard(
                                        GestureDetector(
                                          onTap: () =>
                                              context.push('/admin/id-claims'),
                                          child: AdminStatCard(
                                            label: 'Pending Claims',
                                            value: pendingClaimsCount
                                                .toString(),
                                            icon: Icons.verified_user_rounded,
                                            color: pendingClaimsCount > 0
                                                ? TraceColors.error
                                                : TraceColors.medGrey,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(child: SizedBox()),
                                    const SizedBox(width: 12),
                                    const Expanded(child: SizedBox()),
                                  ],
                                ),
                              ],
                            );
                          }

                          // Mobile Layout
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: buildCard(
                                      fullWidth: true,
                                      AdminStatCard(
                                        label: 'Collected',
                                        value:
                                            '₱${NumberFormat('#,##0.00', 'en_US').format(income)}',
                                        icon: Icons
                                            .account_balance_wallet_rounded,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: buildCard(
                                      fullWidth: true,
                                      AdminStatCard(
                                        label: 'Expenses',
                                        value:
                                            '₱${NumberFormat('#,##0.00', 'en_US').format(expense)}',
                                        icon: Icons.money_off_rounded,
                                        color: TraceColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: buildCard(
                                      AdminStatCard(
                                        label: 'Events',
                                        value: eventCount.toString(),
                                        icon: Icons.event_rounded,
                                        color: TraceColors.gold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: buildCard(
                                      GestureDetector(
                                        onTap: () =>
                                            context.push('/admin/students'),
                                        child: AdminStatCard(
                                          label: 'Students',
                                          value: studentCount.toString(),
                                          icon: Icons.people_rounded,
                                          color: TraceColors.royalBlue,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: buildCard(
                                      AdminStatCard(
                                        label: 'Scans Today',
                                        value: todayScans.toString(),
                                        icon: Icons.qr_code_scanner_rounded,
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: buildCard(
                                      GestureDetector(
                                        onTap: () =>
                                            context.push('/admin/id-claims'),
                                        child: AdminStatCard(
                                          label: 'Pending Claims',
                                          value: pendingClaimsCount.toString(),
                                          icon: Icons.verified_user_rounded,
                                          color: pendingClaimsCount > 0
                                              ? TraceColors.error
                                              : TraceColors.medGrey,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Quick actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Actions',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: TraceColors.navyBlue,
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/admin/logs'),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: Text(
                  'Logs',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: TraceColors.royalBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AdminQuickAction(
                      label: 'New Event',
                      icon: Icons.add_rounded,
                      onTap: onNewEvent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminQuickAction(
                      label: 'Attendance',
                      icon: Icons.how_to_reg_rounded,
                      onTap: onAttendance,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AdminQuickAction(
                      label: 'Post News',
                      icon: Icons.campaign_rounded,
                      onTap: onPostNews,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminQuickAction(
                      label: 'Add Fund',
                      icon: Icons.attach_money_rounded,
                      onTap: canManageFunds
                          ? onAddFund
                          : () => showAccessDenied(
                              'Only the Super Admin or Auditor can add funds.',
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AdminQuickAction(
                      label: 'Manage Admins',
                      icon: Icons.admin_panel_settings_rounded,
                      onTap: canManageAdmins
                          ? onAddAdmin
                          : () => showAccessDenied(
                              'Only the Super Admin can manage admin accounts.',
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminQuickAction(
                      label: 'My Profile',
                      icon: Icons.person_rounded,
                      onTap: () => context.push('/admin/profile'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AdminQuickAction(
                      label: 'Semester Report',
                      icon: Icons.assessment_rounded,
                      onTap: () async {
                        await CsvReportService.generateSemesterReport();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdminQuickAction(
                      label: 'Sync Center',
                      icon: Icons.cloud_sync_rounded,
                      onTap: () => context.push('/admin/sync-center'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
