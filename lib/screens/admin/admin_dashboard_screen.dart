import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/csv_report_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/event_service.dart';
import '../../services/pdf_report_service.dart';
import '../../services/student_service.dart';
import '../../services/excel_report_service.dart';
import '../../services/activity_log_service.dart';
import '../../models/event.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'tabs/overview_tab.dart';
import 'tabs/events_tab.dart';
import '../event_details_full_screen.dart';
import 'tabs/announcements_tab.dart';
import '../../models/announcement.dart';
import 'attendance_events_screen.dart';
import '../../models/student.dart';
import 'student_financial_profile_screen.dart';
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _selectedIndex = 0;
  String _fundSearchQuery = '';
  String _fundSortOption = 'Newest';
  String _studentsSearchQuery = '';
  bool _isExportingStudents = false;

  List<_NavItem> _getNavItems(String? role) {
    if (role == 'scanner') {
      return [
        _NavItem(Icons.dashboard_rounded, 'Dashboard', 0),
        _NavItem(Icons.event_rounded, 'Events', 1),
        _NavItem(Icons.people_rounded, 'Students', 5),
        _NavItem(Icons.qr_code_scanner_rounded, 'Scanner', 2),
      ];
    }
    
    if (role == 'pio') {
      return [
        _NavItem(Icons.dashboard_rounded, 'Dashboard', 0),
        _NavItem(Icons.event_rounded, 'Events', 1),
        _NavItem(Icons.campaign_rounded, 'Announcements', 3),
        _NavItem(Icons.qr_code_scanner_rounded, 'Scanner', 2),
      ];
    }
    
    if (role == 'treasurer') {
      return [
        _NavItem(Icons.dashboard_rounded, 'Dashboard', 0),
        _NavItem(Icons.account_balance_wallet_rounded, 'Funds', 4),
        _NavItem(Icons.people_rounded, 'Students', 5),
        _NavItem(Icons.qr_code_scanner_rounded, 'Scanner', 2),
      ];
    }
    
    if (role == 'auditor') {
      return [
        _NavItem(Icons.dashboard_rounded, 'Dashboard', 0),
        _NavItem(Icons.account_balance_wallet_rounded, 'Funds', 4),
        _NavItem(Icons.qr_code_scanner_rounded, 'Scanner', 2),
      ];
    }
    
    // admin and superadmin
    return [
      _NavItem(Icons.dashboard_rounded, 'Dashboard', 0),
      _NavItem(Icons.event_rounded, 'Events', 1),
      _NavItem(Icons.campaign_rounded, 'Announcements', 3),
      _NavItem(Icons.account_balance_wallet_rounded, 'Funds', 4),
      _NavItem(Icons.qr_code_scanner_rounded, 'Scanner', 2),
      _NavItem(Icons.people_rounded, 'Students', 5),
      _NavItem(Icons.verified_user_rounded, 'ID Claims', 6),
    ];
  }

  late final Stream<QuerySnapshot> _fundsStream;

  bool _canManageFunds(WidgetRef ref) {
    final role = ref.watch(adminRoleProvider).value;
    return role == 'superadmin' || role == 'auditor';
  }

  @override
  void initState() {
    super.initState();
    _fundsStream = FirestoreService.db
        .collection('funds')
        .orderBy('date', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final authService = ref.watch(authServiceProvider);

    // ── Safety net: if Firebase auth becomes null (e.g. token expired or
    //    signOut called), immediately redirect to login even if the user
    //    presses the Android back button back into this screen.
    ref.listen<AsyncValue<dynamic>>(authStateProvider, (_, next) {
      if (next.valueOrNull == null && context.mounted) {
        context.go('/admin/login');
      }
    });

    final role = ref.watch(adminRoleProvider).value;
    final navItems = _getNavItems(role);
    
    // Ensure selected index is valid for filtered items
    if (navItems.isNotEmpty && _selectedIndex >= navItems.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedIndex = 0);
      });
    }

    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      body: Row(
        children: [
          if (isWide) _buildSidebar(authService, navItems),
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  color: TraceColors.navyBlue,
                  child: Column(
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => context.go('/'),
                                child: Image.asset(
                                  'assets/trace-logo3.png',
                                  height: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  authService.currentUser?.email ?? '',
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: TraceColors.white.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.logout_rounded,
                                  color: TraceColors.lightGrey,
                                  size: 20,
                                ),
                                tooltip: 'Sign Out',
                                onPressed: () async {
                                  await authService.signOut();
                                  if (!context.mounted) return;
                                  context.go('/');
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        height: 2,
                        decoration: const BoxDecoration(
                          gradient: TraceColors.goldGradient,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content area
                Expanded(child: _buildContent(navItems)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isWide ? null : _buildBottomNav(navItems),
    );
  }

  Widget _buildSidebar(AuthService authService, List<_NavItem> navItems) {
    return Container(
      width: 240,
      color: TraceColors.navyBlue,
      child: _buildSidebarContent(authService, navItems),
    );
  }

  Widget _buildSidebarContent(AuthService authService, List<_NavItem> navItems) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: TraceColors.gold.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream: FirestoreService.admins
                    .doc(authService.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  String? b64;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    b64 =
                        (snapshot.data!.data()
                                as Map<String, dynamic>)['profile_image_base64']
                            as String?;
                  }

                  if (b64 != null && b64.isNotEmpty) {
                    return Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: TraceColors.gold, width: 2),
                        image: DecorationImage(
                          image: MemoryImage(base64Decode(b64.split(',').last)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: TraceColors.gold, width: 2),
                      color: TraceColors.gold.withValues(alpha: 0.1),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: TraceColors.gold,
                      size: 28,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Officer Portal',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: TraceColors.white,
                ),
              ),
              Text(
                authService.currentUser?.email ?? '',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: TraceColors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: navItems.asMap().entries.map((e) {
              final i = e.key;
              final item = e.value;
              final isSelected = _selectedIndex == i;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedIndex = i);
                      if (item.id == 2) context.go('/scanner');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? TraceColors.gold.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                                color: TraceColors.gold.withValues(alpha: 0.3),
                              )
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            size: 20,
                            color: isSelected
                                ? TraceColors.gold
                                : TraceColors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item.label,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? TraceColors.gold
                                  : TraceColors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget? _buildBottomNav(List<_NavItem> navItems) {
    final items = navItems.take(5).toList();
    if (items.isEmpty) return null;
    
    return Container(
      color: TraceColors.navyBlue,
      padding: const EdgeInsets.only(top: 8, bottom: 5),
      child: BottomNavigationBar(
        elevation: 0,
        currentIndex: _selectedIndex >= items.length ? 0 : _selectedIndex,
        onTap: (i) {
          setState(() => _selectedIndex = i);
          if (items[i].id == 2) context.go('/scanner');
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: TraceColors.navyBlue,
        selectedItemColor: TraceColors.gold,
        unselectedItemColor: TraceColors.white.withValues(alpha: 0.4),
        selectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w400,
          fontSize: 11,
        ),
        items: items
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildContent(List<_NavItem> navItems) {
    if (navItems.isEmpty) return const SizedBox.shrink();
    final role = ref.watch(adminRoleProvider).value;
    int currentId = 0;
    if (_selectedIndex < navItems.length) {
      currentId = navItems[_selectedIndex].id;
    }
    
    switch (currentId) {
      case 0:
        return OverviewTab(
          onNewEvent: _showEventDialog,
          onAttendance: () => context.push('/admin/attendance'),
          onPostNews: _showAnnouncementDialog,
          onAddFund: _showFundDialog,
          onAddAdmin: () => context.push('/admin/manage_admins'),
        );
      case 1:
        return EventsTab(
          onEventTap: _showEventDetailsDialog,
          onNewEvent: _showEventDialog,
          currentRole: role ?? 'admin',
        );
      case 3:
        return AnnouncementsTab(
          onShowAnnouncementDialog: _showAnnouncementDialog,
        );
      case 4:
        return _buildFundsTab();
      case 5:
        return _buildStudentsTab();
      case 6:
        return _buildIdClaimsTab();
      case 7:
        return const AttendanceEventsScreen();
      default:
        return OverviewTab(
          onNewEvent: _showEventDialog,
          onAttendance: () => context.push('/admin/attendance'),
          onPostNews: _showAnnouncementDialog,
          onAddFund: _showFundDialog,
          onAddAdmin: () => context.push('/admin/manage_admins'),
        );
    }
  }

  Widget _buildIdClaimsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.db
          .collection('id_claims')
          .orderBy('submitted_at', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        final pending = docs
            .where(
              (d) => (d.data() as Map<String, dynamic>)['status'] == 'pending',
            )
            .length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Text(
                    'ID Claim Petitions',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: TraceColors.navyBlue,
                    ),
                  ),
                  const Spacer(),
                  if (pending > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TraceColors.error,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$pending pending',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (docs.isEmpty)
              Expanded(
                child: Center(
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
                        'No claims submitted yet',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: TraceColors.medGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;
                    return _AdminClaimCard(docId: doc.id, data: data);
                  },
                ),
              ),
          ],
        );
      },
    );
  }


  void _showEventDialog({Event? event}) {
    context.push('/admin/event-form', extra: event);
  }




  void _showEventDetailsDialog(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => EventDetailsFullScreen(
          event: event,
          bottomActions: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        foregroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (c) => AlertDialog(
                            title: const Text('Delete Event?'),
                            content: const Text(
                              'Are you sure you want to delete this event?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await EventService.deleteEvent(
                            event.id,
                            event.eventName,
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: TraceColors.gold),
                        foregroundColor: TraceColors.gold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEventDialog(event: event);
                      },
                      child: const Text('Edit'),
                    ),
                  ),
                ],
              ),
              if (event.status != 'completed') ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TraceColors.error.withValues(alpha: 0.1),
                    foregroundColor: TraceColors.error,
                    side: BorderSide(
                      color: TraceColors.error.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.stop_circle_rounded),
                  label: Text(
                    'End Event',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        title: const Text('End Event?'),
                        content: Text(
                          'Are you sure you want to manually end "${event.eventName}"?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text(
                              'End Event',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await EventService.updateEvent(event.id, {
                        'status': 'completed',
                        'event_name': event.eventName,
                      });
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAnnouncementDialog({QueryDocumentSnapshot? doc}) {
    if (doc == null) {
      context.push('/admin/announcement-form');
    } else {
      final data = doc.data() as Map<String, dynamic>;
      final announcement = Announcement.fromMap(data, doc.id);
      context.push('/admin/announcement-form', extra: announcement);
    }
  }

  Widget _buildFundsTab() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          child: StreamBuilder<QuerySnapshot>(
            stream: _fundsStream,
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              double income = 0, expense = 0;
              for (final d in docs) {
                final data = d.data() as Map<String, dynamic>;
                final amt = (data['amount'] ?? 0).toDouble();
                if (data['type'] == 'income' ||
                    data['type'] == 'contribution') {
                  income += amt;
                } else if (data['type'] == 'expense') {
                  expense += amt;
                }
              }

              var filteredDocs = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;

                if (_fundSortOption == 'Expenses' &&
                    data['type'] != 'expense') {
                  return false;
                }
                if (_fundSortOption == 'Contribution' &&
                    data['type'] != 'contribution') {
                  return false;
                }

                if (_fundSearchQuery.isEmpty) return true;
                final q = _fundSearchQuery.toLowerCase();
                final desc = (data['description'] ?? '')
                    .toString()
                    .toLowerCase();
                final type = (data['type'] ?? '').toString().toLowerCase();
                final amt = (data['amount'] ?? 0).toString();
                String dateStr = '';
                if (data['date'] != null) {
                  dateStr = _formatDateShort(
                    data['date'] as Timestamp,
                  ).toLowerCase();
                }
                return desc.contains(q) ||
                    type.contains(q) ||
                    amt.contains(q) ||
                    dateStr.contains(q);
              }).toList();

              filteredDocs.sort((a, b) {
                final da = a.data() as Map<String, dynamic>;
                final db = b.data() as Map<String, dynamic>;

                if (_fundSortOption == 'Oldest') {
                  final dta =
                      (da['date'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final dtb =
                      (db['date'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return dta.compareTo(dtb);
                } else {
                  // Newest
                  final dta =
                      (da['date'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final dtb =
                      (db['date'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return dtb.compareTo(dta);
                }
              });

              return Column(
                children: [
                  _buildSwipeableFinanceStats(income, expense, docs),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => context.push('/admin/finances'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [TraceColors.navyBlue, TraceColors.royalBlue],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: TraceColors.navyBlue.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
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
                                  'Financials & Dues Portal',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Manage obligations, sanctions & cashflow logs',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: TraceColors.gold,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search funds...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _fundSortOption,
                            icon: const Icon(
                              Icons.filter_list_rounded,
                              color: Colors.grey,
                            ),
                            items:
                                ['Newest', 'Oldest', 'Expenses', 'Contribution']
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(
                                          e,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                            onChanged: (v) =>
                                setState(() => _fundSortOption = v ?? 'Newest'),
                          ),
                        ),
                      ),
                    ),
                    onChanged: (v) => setState(() => _fundSearchQuery = v),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: filteredDocs.map((d) {
                        final data = d.data() as Map<String, dynamic>;
                        final isIncome =
                            data['type'] == 'income' ||
                            data['type'] == 'contribution';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => _showTransactionDetails(d),
                            child: TraceCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color:
                                          (isIncome
                                                  ? TraceColors.success
                                                  : TraceColors.error)
                                              .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isIncome
                                          ? Icons.arrow_upward_rounded
                                          : Icons.arrow_downward_rounded,
                                      color: isIncome
                                          ? TraceColors.success
                                          : TraceColors.error,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      data['description'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: TraceColors.navyBlue,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${isIncome ? '+' : '-'}₱${_formatAmount((data['amount'] ?? 0).toDouble())}',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: isIncome
                                          ? TraceColors.success
                                          : TraceColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: GoldButton(
                    label: 'Add Entry',
                    icon: Icons.add_rounded,
                    onPressed: () {
                      if (!_canManageFunds(ref)) {
                        _showAccessDenied(
                          'Only the Super Admin or Auditor can add funds.',
                        );
                      } else {
                        _showFundDialog();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GoldButton(
                    label: 'Report',
                    icon: Icons.picture_as_pdf_rounded,
                    onPressed: _showReportConfigDialog,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showReportConfigDialog() {
    DateTime? fromDate;
    DateTime? toDate;
    String typeFilter = 'All';
    String? selectedEvent;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setMState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                  left: 24,
                  right: 24,
                  top: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Generate Report',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: TraceColors.navyBlue,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Transaction Type',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: typeFilter,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'All',
                          child: Text('All Transactions'),
                        ),
                        DropdownMenuItem(
                          value: 'Contributions',
                          child: Text('All Contributions Only'),
                        ),
                        DropdownMenuItem(
                          value: 'Expenses',
                          child: Text('All Expenses Only'),
                        ),
                      ],
                      onChanged: (v) =>
                          setMState(() => typeFilter = v ?? 'All'),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Date Range (Optional)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setMState(() => fromDate = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                fromDate == null
                                    ? 'From Date'
                                    : DateFormat(
                                        'MM/dd/yyyy',
                                      ).format(fromDate!),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (d != null) setMState(() => toDate = d);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                toDate == null
                                    ? 'To Date'
                                    : DateFormat('MM/dd/yyyy').format(toDate!),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Specific Event (Optional)',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirestoreService.db
                          .collection('events')
                          .orderBy('date', descending: true)
                          .snapshots(),
                      builder: (ctx, snap) {
                        if (!snap.hasData) {
                          return const CircularProgressIndicator();
                        }
                        final events = snap.data!.docs;
                        return DropdownButtonFormField<String?>(
                          initialValue: selectedEvent,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          hint: const Text('All Events'),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All Events'),
                            ),
                            ...events.map((e) {
                              final data = e.data() as Map<String, dynamic>;
                              return DropdownMenuItem(
                                value: e.id,
                                child: Text(data['name'] ?? ''),
                              );
                            }),
                          ],
                          onChanged: (v) => setMState(() => selectedEvent = v),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: GoldButton(
                            label: 'PDF',
                            icon: Icons.picture_as_pdf_rounded,
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final snap = await FirestoreService.db
                                  .collection('funds')
                                  .orderBy('date', descending: true)
                                  .get();
                              var docs = snap.docs.where((d) {
                                final data = d.data();
                                if (typeFilter == 'Expenses' &&
                                    data['type'] != 'expense') {
                                  return false;
                                }
                                if (typeFilter == 'Contributions' &&
                                    data['type'] != 'income' &&
                                    data['type'] != 'contribution') {
                                  return false;
                                }
                                if (data['date'] != null) {
                                  final dt = (data['date'] as Timestamp)
                                      .toDate();
                                  if (fromDate != null &&
                                      dt.isBefore(fromDate!)) {
                                    return false;
                                  }
                                  if (toDate != null &&
                                      dt.isAfter(
                                        toDate!.add(const Duration(days: 1)),
                                      )) {
                                    return false;
                                  }
                                }
                                if (selectedEvent != null &&
                                    data['event_id'] != selectedEvent) {
                                  return false;
                                }
                                return true;
                              }).toList();

                              final pdfBytes =
                                  await PdfReportService.generateFundsReport(
                                    docs,
                                  );
                              await Printing.layoutPdf(
                                onLayout: (_) => pdfBytes,
                                name: 'Funds_Ledger_Report.pdf',
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GoldButton(
                            label: 'CSV',
                            icon: Icons.table_chart_rounded,
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final snap = await FirestoreService.db
                                  .collection('funds')
                                  .orderBy('date', descending: true)
                                  .get();
                              var docs = snap.docs.where((d) {
                                final data = d.data();
                                if (typeFilter == 'Expenses' &&
                                    data['type'] != 'expense') {
                                  return false;
                                }
                                if (typeFilter == 'Contributions' &&
                                    data['type'] != 'income' &&
                                    data['type'] != 'contribution') {
                                  return false;
                                }
                                if (data['date'] != null) {
                                  final dt = (data['date'] as Timestamp)
                                      .toDate();
                                  if (fromDate != null &&
                                      dt.isBefore(fromDate!)) {
                                    return false;
                                  }
                                  if (toDate != null &&
                                      dt.isAfter(
                                        toDate!.add(const Duration(days: 1)),
                                      )) {
                                    return false;
                                  }
                                }
                                if (selectedEvent != null &&
                                    data['event_id'] != selectedEvent) {
                                  return false;
                                }
                                return true;
                              }).toList();

                              await CsvReportService.generateFundsCsv(docs);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSwipeableFinanceStats(
    double income,
    double expense,
    List<QueryDocumentSnapshot> docs,
  ) {
    final netBalance = income - expense;

    String getIncomeSubtitle() {
      final incomeDocs = docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['type'] == 'income' || data['type'] == 'contribution';
      }).toList();
      if (incomeDocs.isEmpty) return 'No funds added yet';
      final latest = incomeDocs.first.data() as Map<String, dynamic>;
      final dtStr = latest['date'] != null
          ? DateFormat(
              'MM/dd/yyyy hh:mm a',
            ).format((latest['date'] as Timestamp).toDate())
          : '';
      final amt = (latest['amount'] ?? 0).toDouble();
      String desc = (latest['description'] ?? '').toString();
      if (desc.length > 20) desc = '${desc.substring(0, 17)}...';
      return 'Latest fund added: ₱${_formatAmount(amt)}\n$desc\n$dtStr';
    }

    String getExpenseSubtitle() {
      final expDocs = docs
          .where((d) => (d.data() as Map<String, dynamic>)['type'] == 'expense')
          .toList();
      if (expDocs.isEmpty) return 'No funds deducted yet';
      final latest = expDocs.first.data() as Map<String, dynamic>;
      final amt = (latest['amount'] ?? 0).toDouble();
      final dtStr = latest['date'] != null
          ? DateFormat(
              'MM/dd/yyyy hh:mm a',
            ).format((latest['date'] as Timestamp).toDate())
          : '';
      String desc = (latest['description'] ?? '').toString();
      if (desc.length > 20) desc = '${desc.substring(0, 17)}...';
      return 'Latest fund deduction: ₱${_formatAmount(amt)}\n$desc\n$dtStr';
    }

    String getNetSubtitle() {
      if (docs.isEmpty) return 'No transactions yet';
      final expDocs = docs
          .where((d) => (d.data() as Map<String, dynamic>)['type'] == 'expense')
          .toList();
      final incomeDocs = docs.where((d) {
        final data = d.data() as Map<String, dynamic>;
        return data['type'] == 'income' || data['type'] == 'contribution';
      }).toList();

      double latestIncomeAmt = 0;
      if (incomeDocs.isNotEmpty) {
        latestIncomeAmt =
            ((incomeDocs.first.data() as Map<String, dynamic>)['amount'] ?? 0)
                .toDouble();
      }

      double latestExpAmt = 0;
      if (expDocs.isNotEmpty) {
        latestExpAmt =
            ((expDocs.first.data() as Map<String, dynamic>)['amount'] ?? 0)
                .toDouble();
      }

      return 'Latest Fund Added: ₱${_formatAmount(latestIncomeAmt)}\n'
          'Sub total: ₱${_formatAmount(income)}\n'
          'Latest Fund Deducted: ₱${_formatAmount(latestExpAmt)}';
    }

    Widget buildPage(String title, String value, Color color, String subtitle) {
      return TraceCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: TraceColors.medGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: TraceColors.medGrey,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 145,
      child: PageView(
        controller: PageController(viewportFraction: 0.95),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: buildPage(
              'Total Contributions',
              '₱${_formatAmount(income)}',
              TraceColors.success,
              getIncomeSubtitle(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: buildPage(
              'Total Expenses',
              '₱${_formatAmount(expense)}',
              TraceColors.error,
              getExpenseSubtitle(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: buildPage(
              'Net Balance',
              '₱${_formatAmount(netBalance)}',
              TraceColors.gold,
              getNetSubtitle(),
            ),
          ),
        ],
      ),
    );
  }

  void _showFundDialog() {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String type = 'income';
    String? selectedEventId;
    List<Uint8List> proofBytesList = [];
    final ImagePicker picker = ImagePicker();

    Future<void> pickImages(StateSetter setDState) async {
      final List<XFile> images = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1000,
        maxHeight: 1000,
      );
      if (images.isNotEmpty) {
        List<Uint8List> bytesList = [];
        for (var img in images) {
          bytesList.add(await img.readAsBytes());
        }
        setDState(() => proofBytesList.addAll(bytesList));
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          title: Text(
            'Add Entry',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: TraceColors.navyBlue,
            ),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('Income')),
                      DropdownMenuItem(
                        value: 'expense',
                        child: Text('Expense'),
                      ),
                      DropdownMenuItem(
                        value: 'contribution',
                        child: Text('Contribution'),
                      ),
                    ],
                    onChanged: (v) => setDState(() => type = v ?? type),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amtCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (₱)'),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirestoreService.db
                        .collection('events')
                        .orderBy('date', descending: true)
                        .snapshots(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const SizedBox();
                      final events = snap.data!.docs;
                      return DropdownButtonFormField<String?>(
                        isExpanded: true,
                        initialValue: selectedEventId,
                        decoration: const InputDecoration(
                          labelText: 'Link to Event (Optional)',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('None'),
                          ),
                          ...events.map((e) {
                            final data = e.data() as Map<String, dynamic>;
                            return DropdownMenuItem(
                              value: e.id,
                              child: Text(
                                data['event_name'] ?? 'Unknown Event',
                              ),
                            );
                          }),
                        ],
                        onChanged: (v) => setDState(() => selectedEventId = v),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  proofBytesList.isNotEmpty
                      ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...List.generate(proofBytesList.length, (idx) {
                              return SizedBox(
                                width: 80,
                                height: 80,
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        proofBytesList[idx],
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                    ),
                                    Positioned(
                                      right: 4,
                                      top: 4,
                                      child: GestureDetector(
                                        onTap: () => setDState(
                                          () => proofBytesList.removeAt(idx),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            GestureDetector(
                              onTap: () => pickImages(setDState),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        )
                      : GestureDetector(
                          onTap: () => pickImages(setDState),
                          child: Container(
                            width: double.infinity,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.add_a_photo_rounded,
                                  color: Colors.grey,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Upload Proof (Optional)',
                                  style: GoogleFonts.inter(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            GoldButton(
              label: 'Save',
              onPressed: () async {
                if (descCtrl.text.isEmpty || amtCtrl.text.isEmpty) return;

                List<String> imageUrls = [];
                for (int i = 0; i < proofBytesList.length; i++) {
                  final bytes = proofBytesList[i];
                  final ref = FirebaseStorage.instance.ref().child(
                    'receipts/${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
                  );
                  await ref.putData(bytes);
                  final url = await ref.getDownloadURL();
                  imageUrls.add(url);
                }

                final docRef = await FirestoreService.db
                    .collection('funds')
                    .add({
                      'type': type,
                      'description': descCtrl.text.trim(),
                      'amount': double.tryParse(amtCtrl.text) ?? 0,
                      'date': FieldValue.serverTimestamp(),
                      'proof_images_urls': imageUrls,
                      'event_id': selectedEventId,
                    });
                await ActivityLogService.log(
                  action: 'fund_${type}_added',
                  message:
                      'Added $type: ₱${amtCtrl.text} for ${descCtrl.text.trim()}',
                  entityType: 'fund',
                  entityId: docRef.id,
                  actorName: 'Admin',
                );

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Transaction Details',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: TraceColors.navyBlue,
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow(
                  'Type',
                  (data['type'] ?? '').toString().toUpperCase(),
                ),
                const SizedBox(height: 8),
                _detailRow('Description', data['description'] ?? ''),
                const SizedBox(height: 8),
                _detailRow(
                  'Amount',
                  '₱${_formatAmount((data['amount'] ?? 0).toDouble())}',
                ),
                const SizedBox(height: 8),
                if (data['date'] != null)
                  _detailRow(
                    'Date',
                    _formatDateShort(data['date'] as Timestamp),
                  ),
                Builder(
                  builder: (ctx) {
                    List<String> proofImages = [];
                    if (data['proof_images_base64'] != null) {
                      proofImages = List<String>.from(
                        data['proof_images_base64'],
                      );
                    } else if (data['proof_image_base64'] != null &&
                        data['proof_image_base64'].toString().isNotEmpty) {
                      proofImages = [data['proof_image_base64']];
                    }
                    if (data['proof_images_urls'] != null) {
                      proofImages.addAll(
                        List<String>.from(data['proof_images_urls']),
                      );
                    }

                    if (proofImages.isEmpty) return const SizedBox();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'Proof Photo',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: TraceColors.medGrey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: proofImages
                              .map(
                                (b64) => GestureDetector(
                                  onTap: () => _showFullImage(b64),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: b64.startsWith('http')
                                        ? Image.network(
                                            b64,
                                            fit: BoxFit.cover,
                                            width: 80,
                                            height: 80,
                                          )
                                        : Image.memory(
                                            base64Decode(b64.split(',').last),
                                            fit: BoxFit.cover,
                                            width: 80,
                                            height: 80,
                                          ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TraceColors.error,
                          side: const BorderSide(color: TraceColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          if (!_canManageFunds(ref)) {
                            _showAccessDenied(
                              'Only the Super Admin or Auditor can delete funds.',
                            );
                            return;
                          }
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete Transaction?'),
                              content: const Text(
                                'Are you sure you want to delete this transaction? This action will automatically recalculate the funds and cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final desc = data['description'] ?? 'Transaction';
                            final type = data['type'] ?? 'fund';
                            final amount = data['amount'] ?? 0;
                            await doc.reference.delete();
                            await ActivityLogService.log(
                              action: 'fund_${type}_deleted',
                              message: 'Deleted $type: ₱$amount for $desc',
                              entityType: 'fund',
                              entityId: doc.id,
                              actorName: 'Admin',
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                          }
                        },
                        child: Text(
                          'Delete',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GoldButton(
                        label: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFullImage(String base64String) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: base64String.startsWith('http')
                    ? Image.network(base64String)
                    : Image.memory(base64Decode(base64String.split(',').last)),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 14, color: TraceColors.medGrey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: TraceColors.navyBlue,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateShort(Timestamp ts) {
    final dt = ts.toDate();
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    int hr = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    if (hr == 0) hr = 12;
    return '${dt.month}/${dt.day}/${dt.year} $hr:${dt.minute.toString().padLeft(2, '0')} $amPm';
  }

  Widget _buildStudentsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Registered Students',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: TraceColors.navyBlue,
                ),
              ),
              _isExportingStudents
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: TraceColors.gold, strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.download_rounded, color: TraceColors.navyBlue),
                      tooltip: 'Export Excel',
                      onPressed: _exportStudentsToExcel,
                    ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (val) {
              setState(() {
                _studentsSearchQuery = val.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search student name or ID...',
              prefixIcon: const Icon(Icons.search, color: TraceColors.medGrey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: TraceColors.royalBlue),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.db
                .collection('students')
                .orderBy('registered_at', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              var docs = snap.data!.docs;
              if (_studentsSearchQuery.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final sId = (data['student_id'] as String? ?? '').toLowerCase();
                  return name.contains(_studentsSearchQuery) || sId.contains(_studentsSearchQuery);
                }).toList();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${docs.length} registered students',
                    style: GoogleFonts.inter(
                      color: TraceColors.medGrey,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...docs.map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final student = Student.fromMap(data, d.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TraceCard(
                        padding: EdgeInsets.zero,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (ctx) => StudentFinancialProfileScreen(
                                student: student,
                                currentUserEmail: ref.read(authServiceProvider).currentUser?.email ?? '',
                              ),
                            ));
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                            Builder(
                              builder: (context) {
                                final avatarUrl = (data['avatar_url'] ?? '').toString();
                                ImageProvider? imageProvider;
                                if (avatarUrl.isNotEmpty) {
                                  if (avatarUrl.startsWith('data:image')) {
                                    imageProvider = MemoryImage(base64Decode(avatarUrl.split(',').last));
                                  } else if (avatarUrl.startsWith('http')) {
                                    imageProvider = NetworkImage(avatarUrl);
                                  }
                                }
                                return CircleAvatar(
                                  radius: 21,
                                  backgroundColor: TraceColors.royalBlue,
                                  backgroundImage: imageProvider,
                                  child: imageProvider == null
                                      ? Text(
                                          (data['name'] as String? ?? '?').isNotEmpty
                                              ? (data['name'] as String? ?? '?')[0].toUpperCase()
                                              : '?',
                                          style: GoogleFonts.inter(
                                            color: TraceColors.gold,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                          ),
                                        )
                                      : null,
                                );
                              }
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['name'] ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: TraceColors.navyBlue,
                                    ),
                                  ),
                                  Text(
                                    '${data['student_id']} • ${data['course']} • ${data['year_level']}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
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
                  }),
                ],
              );
            },
          ),
        ],
      ),
    ));
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,##0.00', 'en_US').format(amount);
  }

  void _showAccessDenied(String message) {
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

  Future<void> _exportStudentsToExcel() async {
    setState(() => _isExportingStudents = true);
    try {
      final snap = await FirestoreService.db.collection('students').get();
      final activeDocs = snap.docs.where((doc) {
        final data = doc.data();
        return data['is_archived'] != true;
      }).toList();
      
      await ExcelReportService.generateStudentsExcelByYear(activeDocs);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel report generated successfully.'),
            backgroundColor: TraceColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: TraceColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingStudents = false);
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int id;
  _NavItem(this.icon, this.label, this.id);
}

// ===========================================================================
// Admin Claim Card (inline in dashboard)
// ===========================================================================
class _AdminClaimCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _AdminClaimCard({required this.docId, required this.data});
  @override
  State<_AdminClaimCard> createState() => _AdminClaimCardState();
}

class _AdminClaimCardState extends State<_AdminClaimCard> {
  bool _isProcessing = false;

  String _formatDate(dynamic ts) {
    if (ts == null) return '--';
    try {
      final dt = (ts as Timestamp).toDate();
      return '${dt.month}/${dt.day}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
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
    final name = widget.data['claimant_name'] as String? ?? '';
    final email = widget.data['claimant_email'] as String? ?? '';
    final confirm = await showDialog<String>(
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
          '• Restore Records: (For legitimate students recovering their account) Keep their old attendance/payments, just update their email to "$email".\n\n'
          '• Discard Records: (For kicking out fraudsters) Archive the old records away from this ID, giving the legitimate student a fresh empty account.',
          style: GoogleFonts.inter(fontSize: 14),
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
    if (confirm == null || confirm == 'cancel') return;
    final keepRecords = confirm == 'restore';
    setState(() => _isProcessing = true);
    try {
      final snap = await FirestoreService.students
          .where('student_id', isEqualTo: claimedId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) throw 'Student ID not found.';
      await StudentService.approveIdClaim(
        claimDocId: widget.docId,
        studentDocId: snap.docs.first.id,
        newName: name,
        newEmail: email,
        keepRecords: keepRecords,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim approved!'),
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
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _reject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Reject Claim?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Mark this petition as rejected.',
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
    if (mounted) setState(() => _isProcessing = false);
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
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'ID: ',
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
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
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
                const SizedBox(height: 6),
                _row(
                  Icons.email_outlined,
                  'Email',
                  widget.data['claimant_email'] ?? '--',
                ),
                const SizedBox(height: 6),
                _row(
                  Icons.access_time,
                  'Submitted',
                  _formatDate(widget.data['submitted_at']),
                ),
                const SizedBox(height: 10),
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
                if (proofUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
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
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.black,
                        child: proofUrl.startsWith('data:image')
                            ? Image.memory(
                                base64Decode(proofUrl.split(',').last),
                              )
                            : Image.network(proofUrl),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 130,
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
                  const SizedBox(height: 14),
                  _isProcessing
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: TraceColors.navyBlue,
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _reject,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: TraceColors.error,
                                  side: const BorderSide(
                                    color: TraceColors.error,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _approve,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TraceColors.success,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Approve',
                                  style: TextStyle(color: Colors.white),
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

  Widget _row(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 15, color: TraceColors.medGrey),
      const SizedBox(width: 6),
      Text(
        '$label: ',
        style: GoogleFonts.inter(fontSize: 12, color: TraceColors.medGrey),
      ),
      Expanded(
        child: Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: TraceColors.navyBlue,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
