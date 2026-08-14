import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/activity_log_service.dart';
import '../../../models/announcement.dart';

class AnnouncementsTab extends StatefulWidget {
  final void Function({QueryDocumentSnapshot? doc}) onShowAnnouncementDialog;

  const AnnouncementsTab({super.key, required this.onShowAnnouncementDialog});

  @override
  State<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<AnnouncementsTab> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Ongoing', 'Upcoming', 'General'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => widget.onShowAnnouncementDialog(),
        backgroundColor: TraceColors.gold,
        icon: const Icon(Icons.add_rounded, color: TraceColors.navyBlue),
        label: Text(
          'News',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: TraceColors.navyBlue,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Announcements',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: TraceColors.navyBlue,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage school news, updates, and upcoming schedules.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: TraceColors.medGrey,
                  ),
                ),
              ],
            ),
          ),

          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: _filters
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f),
                        selected: _selectedFilter == f,
                        onSelected: (val) {
                          if (val) setState(() => _selectedFilter = f);
                        },
                        backgroundColor: Colors.white,
                        selectedColor: TraceColors.navyBlue,
                        checkmarkColor: Colors.white,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: _selectedFilter == f
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: _selectedFilter == f
                              ? Colors.white
                              : TraceColors.navyBlue,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: _selectedFilter == f
                                ? TraceColors.navyBlue
                                : TraceColors.lightGrey,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),

          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.db
                  .collection('announcements')
                  .orderBy('date_posted', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: TraceColors.navyBlue,
                    ),
                  );
                }

                var docs = snap.data!.docs;

                // Auto-transition Upcoming -> Ongoing
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  String cat = data['category'] ?? 'Upcoming';
                  if (data['scheduled_date'] != null) {
                    final scheduled = (data['scheduled_date'] as Timestamp)
                        .toDate();
                    if (cat == 'Upcoming' &&
                        !scheduled.isAfter(DateTime.now())) {
                      doc.reference.update({'category': 'Ongoing'});
                    }
                  }
                }

                if (_selectedFilter != 'All') {
                  docs = docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    String cat = d['category'] ?? 'General';
                    if (d['scheduled_date'] != null && cat == 'Upcoming') {
                      final scheduled = (d['scheduled_date'] as Timestamp)
                          .toDate();
                      if (!scheduled.isAfter(DateTime.now())) cat = 'Ongoing';
                    }
                    return cat == _selectedFilter;
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          size: 64,
                          color: TraceColors.lightGrey.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No announcements found.',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: TraceColors.medGrey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (ctx, i) {
                    final doc = docs[i];
                    final data = doc.data() as Map<String, dynamic>;

                    String displayCategory = data['category'] ?? 'General';
                    if (data['scheduled_date'] != null &&
                        displayCategory == 'Upcoming') {
                      final scheduled = (data['scheduled_date'] as Timestamp)
                          .toDate();
                      if (!scheduled.isAfter(DateTime.now())) {
                        displayCategory = 'Ongoing';
                      }
                    }

                    Color catColor;
                    switch (displayCategory) {
                      case 'Ongoing':
                        catColor = TraceColors.success;
                        break;
                      case 'Upcoming':
                        catColor = TraceColors.warning;
                        break;
                      default:
                        catColor = TraceColors.royalBlue;
                    }

                    final postedDt = (data['date_posted'] as Timestamp?)
                        ?.toDate();
                    final schedDt = (data['scheduled_date'] as Timestamp?)
                        ?.toDate();

                    return GestureDetector(
                      onTap: () {
                        final announcement = Announcement.fromMap(data, doc.id);
                        context.push('/announcement-details', extra: announcement);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: catColor.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header strip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.08),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(14),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  displayCategory == 'Ongoing'
                                      ? Icons.play_circle_fill_rounded
                                      : displayCategory == 'Upcoming'
                                      ? Icons.schedule_rounded
                                      : Icons.info_rounded,
                                  size: 16,
                                  color: catColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  displayCategory.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: catColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                if (postedDt != null)
                                  Text(
                                    DateFormat('MMM d, yyyy').format(postedDt),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: TraceColors.medGrey,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Body
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        data['title'] ?? 'Untitled',
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: TraceColors.navyBlue,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _buildPopupMenu(context, doc),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  data['content'] ?? '',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: TraceColors.navyBlue.withValues(
                                      alpha: 0.8,
                                    ),
                                    height: 1.6,
                                  ),
                                ),
                                if (schedDt != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: TraceColors.gold.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: TraceColors.gold.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_month_rounded,
                                          size: 14,
                                          color: TraceColors.gold,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Scheduled for ${DateFormat('MMMM d, yyyy').format(schedDt)}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: TraceColors.gold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupMenu(BuildContext context, QueryDocumentSnapshot doc) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, color: TraceColors.medGrey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      onSelected: (val) async {
        if (val == 'edit') {
          widget.onShowAnnouncementDialog(doc: doc);
        } else if (val == 'delete') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Delete Announcement?',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: TraceColors.navyBlue,
                ),
              ),
              content: Text(
                'This action cannot be undone.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: TraceColors.medGrey,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TraceColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
          if (confirm == true) {
            final title =
                (doc.data() as Map<String, dynamic>)['title'] ?? 'Announcement';
            await doc.reference.delete();
            await ActivityLogService.log(
              action: 'announcement_deleted',
              message: 'Deleted announcement: "$title"',
              entityType: 'announcement',
              entityId: doc.id,
              actorName: 'Admin',
            );
          }
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(
                Icons.edit_rounded,
                size: 18,
                color: TraceColors.navyBlue,
              ),
              const SizedBox(width: 12),
              Text(
                'Edit',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: TraceColors.navyBlue,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(
                Icons.delete_rounded,
                size: 18,
                color: TraceColors.error,
              ),
              const SizedBox(width: 12),
              Text(
                'Delete',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: TraceColors.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
