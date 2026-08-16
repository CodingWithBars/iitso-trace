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
    
    final isExec = role == 'superadmin' || role == 'admin' || role == 'vice_president' || role == 'assoc_vice_president';
    final isSec = role == 'secretary' || role == 'assoc_secretary';
    final isFin = role == 'treasurer' || role == 'assoc_treasurer';
    final isAud = role == 'auditor' || role == 'assoc_auditor';
    final isCom = role == 'pio' || role == 'assoc_pio' || role == 'pro' || role == 'assoc_pro_1' || role == 'assoc_pro_2';
    
    final canManageAdmins = role == 'superadmin';
    final canViewFunds = isExec || isFin || isAud;
    final canManageFunds = isExec || isFin;
    final canViewEvents = isExec || isSec || isCom || role == 'scanner';
    final canAddEvent = isExec || isCom;
    final canViewStudents = isExec || isSec || isFin || role == 'scanner';
    final canPostNews = isExec || isCom;
    final canViewScans = true; // All roles can scan as per Option B
    final canManageAttendance = true; // All roles can scan as per Option B
    final canViewClaims = isExec || isSec;
    final canGenerateReport = isExec || isFin || isAud;

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
                          
                          final List<Widget> cards = [];
                          
                          if (canViewFunds) {
                            cards.addAll([
                              AdminStatCard(
                                label: 'Collected',
                                value: '₱${NumberFormat('#,##0.00', 'en_US').format(income)}',
                                icon: Icons.account_balance_wallet_rounded,
                                color: Colors.green,
                              ),
                              AdminStatCard(
                                label: 'Expenses',
                                value: '₱${NumberFormat('#,##0.00', 'en_US').format(expense)}',
                                icon: Icons.money_off_rounded,
                                color: TraceColors.error,
                              ),
                            ]);
                          }
                          
                          if (canViewEvents) {
                            cards.add(
                              AdminStatCard(
                                label: 'Events',
                                value: eventCount.toString(),
                                icon: Icons.event_rounded,
                                color: TraceColors.gold,
                              ),
                            );
                          }
                          
                          if (canViewStudents) {
                            cards.add(
                              GestureDetector(
                                onTap: () => context.push('/admin/students'),
                                child: AdminStatCard(
                                  label: 'Students',
                                  value: studentCount.toString(),
                                  icon: Icons.people_rounded,
                                  color: TraceColors.royalBlue,
                                ),
                              ),
                            );
                          }
                          
                          if (canViewScans) {
                            cards.add(
                              AdminStatCard(
                                label: 'Scans Today',
                                value: todayScans.toString(),
                                icon: Icons.qr_code_scanner_rounded,
                                color: Colors.purple,
                              ),
                            );
                          }
                          
                          if (canViewClaims) {
                            cards.add(
                              GestureDetector(
                                onTap: () => context.push('/admin/id-claims'),
                                child: AdminStatCard(
                                  label: 'Pending Claims',
                                  value: pendingClaimsCount.toString(),
                                  icon: Icons.verified_user_rounded,
                                  color: pendingClaimsCount > 0 ? TraceColors.error : TraceColors.medGrey,
                                ),
                              ),
                            );
                          }
                          
                          if (cards.isEmpty) {
                             return Container(
                               width: double.infinity,
                               padding: const EdgeInsets.all(24),
                               decoration: BoxDecoration(
                                 color: Colors.white,
                                 borderRadius: BorderRadius.circular(12),
                                 border: Border.all(color: TraceColors.lightGrey),
                               ),
                               child: Center(
                                 child: Text(
                                   'No metrics available for your role.',
                                   style: GoogleFonts.inter(color: TraceColors.medGrey),
                                 )
                               ),
                             );
                          }

                          final int crossAxisCount = isWide ? 4 : 2;
                          final double cardWidth = (constraints.maxWidth - (12 * (crossAxisCount - 1))) / crossAxisCount;

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: cards.map((c) => SizedBox(
                               width: cardWidth,
                               child: AspectRatio(
                                 aspectRatio: 2.0,
                                 child: c,
                               ),
                            )).toList(),
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
              if (role == 'superadmin' || role == 'admin') 
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
          
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth > 500;
              final crossAxisCount = isWide ? 4 : 2;
              final double btnWidth = (constraints.maxWidth - (8 * (crossAxisCount - 1))) / crossAxisCount;

              final List<Widget> actions = [];
              
              if (canAddEvent) {
                actions.add(AdminQuickAction(label: 'New Event', icon: Icons.add_rounded, onTap: onNewEvent));
              }
              
              if (canManageAttendance) {
                actions.add(AdminQuickAction(label: 'Attendance', icon: Icons.how_to_reg_rounded, onTap: onAttendance));
              }
              
              if (canPostNews) {
                actions.add(AdminQuickAction(label: 'Post News', icon: Icons.campaign_rounded, onTap: onPostNews));
              }
              
              if (canManageFunds) {
                actions.add(AdminQuickAction(label: 'Add Fund', icon: Icons.attach_money_rounded, onTap: onAddFund));
              }
              
              if (canManageAdmins) {
                actions.add(AdminQuickAction(label: 'Manage Admins', icon: Icons.admin_panel_settings_rounded, onTap: onAddAdmin));
              }
              
              actions.add(AdminQuickAction(label: 'My Profile', icon: Icons.person_rounded, onTap: () => context.push('/admin/profile')));
              
              if (canGenerateReport) {
                actions.add(AdminQuickAction(
                  label: 'Semester Report',
                  icon: Icons.assessment_rounded,
                  onTap: () async {
                    await CsvReportService.generateSemesterReport();
                  }
                ));
              }
              

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions.map((a) => SizedBox(width: btnWidth, child: a)).toList(),
              );
            }
          ),
        ],
      ),
    );
  }
}
