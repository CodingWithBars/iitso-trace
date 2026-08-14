import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../models/announcement.dart';
import 'web_landing_helpers.dart';

class AnnouncementsSection extends StatefulWidget {
  const AnnouncementsSection({super.key});

  @override
  State<AnnouncementsSection> createState() => _AnnouncementsSectionState();
}

class _AnnouncementsSectionState extends State<AnnouncementsSection> {
  int _announcementTab = 0;

  static const _announcementCategories = [
    'Upcoming',
    'Ongoing',
    'Previous',
    'Cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TraceColors.white,
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final isWide = constraints.maxWidth > 700;
          final hPad = isWide ? 80.0 : 24.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: buildSectionHeader(
                  'Announcements',
                  TraceColors.navyBlue,
                ),
              ),
              const SizedBox(height: 20),
              // Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Row(
                  children: List.generate(
                    _announcementCategories.length,
                    (i) => GestureDetector(
                      onTap: () => setState(() => _announcementTab = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _announcementTab == i
                              ? TraceColors.navyBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: _announcementTab == i
                                ? TraceColors.gold
                                : TraceColors.lightGrey,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _announcementCategories[i],
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _announcementTab == i
                                ? TraceColors.gold
                                : TraceColors.medGrey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('announcements')
                    .orderBy('date_posted', descending: true)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          color: TraceColors.royalBlue,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  final allDocs = snap.data?.docs ?? [];
                  final filtered = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final cat = data['category'] ?? 'Upcoming';
                    return cat == _announcementCategories[_announcementTab];
                  }).toList();

                  if (filtered.isEmpty) {
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: buildEmptyState(
                        'No ${_announcementCategories[_announcementTab].toLowerCase()} announcements.',
                        Icons.campaign_outlined,
                      ),
                    );
                  }

                  // On mobile: vertical stack. On wide: multi-column wrap.
                  if (isWide) {
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: filtered.map((doc) {
                          return SizedBox(
                            width: constraints.maxWidth > 1200
                                ? (constraints.maxWidth - hPad * 2 - 40) / 3
                                : (constraints.maxWidth - hPad * 2 - 20) / 2,
                            child: _announcementCard(doc),
                          );
                        }).toList(),
                      ),
                    );
                  }

                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Column(
                      children: filtered.map((doc) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _announcementCard(doc),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _announcementCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = data['date_posted'] != null
        ? formatDate((data['date_posted'] as Timestamp).toDate())
        : '';
    final bannerUrl = data['banner_url']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        final announcement = Announcement.fromMap(data, doc.id);
        context.push('/announcement-details', extra: announcement);
      },
      child: Container(
        decoration: BoxDecoration(
        color: TraceColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TraceColors.lightGrey.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bannerUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 7,
              child: buildBannerImage(bannerUrl),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bannerUrl.isEmpty)
                  Container(
                    width: 44,
                    height: 44,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [TraceColors.royalBlue, TraceColors.midBlue],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.campaign_rounded,
                      color: TraceColors.gold,
                      size: 22,
                    ),
                  ),
                Text(
                  data['title'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: TraceColors.navyBlue,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: TraceColors.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (data['scheduled_date'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Scheduled: ${formatDate((data['scheduled_date'] as Timestamp).toDate())}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: TraceColors.medGrey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  data['content'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: TraceColors.navyBlue.withValues(alpha: 0.65),
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
