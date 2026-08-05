import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../shared_widgets.dart';

class AnnouncementsSection extends StatefulWidget {
  final bool isWide;

  const AnnouncementsSection({super.key, required this.isWide});

  @override
  State<AnnouncementsSection> createState() => _AnnouncementsSectionState();
}

class _AnnouncementsSectionState extends State<AnnouncementsSection> {
  int _announcementTab = 0;
  static const _categories = ['Upcoming', 'Ongoing', 'Previous', 'Cancelled'];

  @override
  Widget build(BuildContext context) {
    final double hPadding = widget.isWide ? 80 : 20;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPadding),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: const BoxDecoration(
                    gradient: TraceColors.goldGradient,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Announcements',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: TraceColors.navyBlue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Category tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: hPadding),
            child: Row(
              children: List.generate(
                _categories.length,
                (i) => GestureDetector(
                  onTap: () => setState(() => _announcementTab = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _announcementTab == i
                          ? TraceColors.navyBlue
                          : TraceColors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _announcementTab == i
                            ? TraceColors.gold
                            : TraceColors.lightGrey,
                      ),
                      boxShadow: _announcementTab == i
                          ? [
                              BoxShadow(
                                color: TraceColors.navyBlue.withValues(
                                  alpha: 0.2,
                                ),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      _categories[i],
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
          const SizedBox(height: 20),
          // Live announcements stream
          StreamBuilder<QuerySnapshot>(
            stream: FirestoreService.db
                .collection('announcements')
                .orderBy('date_posted', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                      color: TraceColors.royalBlue,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }
              final allDocs = snap.data!.docs;
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                String cat = data['category'] ?? 'Upcoming';
                if (data['scheduled_date'] != null) {
                  final scheduled = (data['scheduled_date'] as Timestamp)
                      .toDate();
                  if (cat == 'Upcoming' && !scheduled.isAfter(DateTime.now())) {
                    cat = 'Ongoing';
                    // Update in background
                    doc.reference.update({'category': 'Ongoing'});
                  }
                }
                return cat == _categories[_announcementTab];
              }).toList();

              if (filteredDocs.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPadding),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: TraceColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: TraceColors.lightGrey.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            size: 40,
                            color: TraceColors.lightGrey.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No ${_categories[_announcementTab].toLowerCase()} announcements.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: TraceColors.medGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: filteredDocs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final date = data['date_posted'] != null
                          ? _formatDate(
                              (data['date_posted'] as Timestamp).toDate(),
                            )
                          : '';
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: SizedBox(
                          width: 320,
                          child: GestureDetector(
                            onTap: () => _showAnnouncementDetails(data),
                            child: TraceCard(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          TraceColors.royalBlue,
                                          TraceColors.midBlue,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                    child:
                                        (data['banner_url'] != null &&
                                            data['banner_url']
                                                .toString()
                                                .isNotEmpty)
                                        ? _buildBannerImage(data['banner_url'])
                                        : const Icon(
                                            Icons.campaign_rounded,
                                            color: TraceColors.gold,
                                            size: 24,
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['title'] ?? '',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: TraceColors.navyBlue,
                                          ),
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
                                        if (data['scheduled_date'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 2,
                                            ),
                                            child: Text(
                                              'Scheduled: ${_formatDate((data['scheduled_date'] as Timestamp).toDate())}',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                color: TraceColors.medGrey,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        Text(
                                          data['content'] ?? '',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: TraceColors.navyBlue
                                                .withValues(alpha: 0.7),
                                            height: 1.4,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
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
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBannerImage(String url, {BoxFit fit = BoxFit.cover}) {
    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.split(',').last;
        return Image.memory(base64Decode(base64Str), fit: fit);
      } catch (_) {
        return Container(color: TraceColors.lightGrey);
      }
    }
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, _, _) => Container(color: TraceColors.lightGrey),
    );
  }

  void _showAnnouncementDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: TraceColors.navyBlue,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data['banner_url'] != null &&
                  data['banner_url'].toString().isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    width: double.infinity,
                    child: _buildBannerImage(
                      data['banner_url'],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? 'Announcement',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: TraceColors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (data['date_posted'] != null)
                      Text(
                        _formatDate(
                          (data['date_posted'] as Timestamp).toDate(),
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: TraceColors.gold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (data['scheduled_date'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Scheduled: ${_formatDate((data['scheduled_date'] as Timestamp).toDate())}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: TraceColors.white.withValues(alpha: 0.5),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      data['content'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: TraceColors.white.withValues(alpha: 0.9),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TraceColors.gold,
                          foregroundColor: TraceColors.navyBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Close',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
