import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../models/announcement.dart';
import '../models/comment.dart';
import '../services/announcement_service.dart';
import '../services/auth_service.dart';
import '../services/student_session_service.dart';

class AnnouncementDetailsScreen extends ConsumerStatefulWidget {
  final Announcement announcement;

  const AnnouncementDetailsScreen({super.key, required this.announcement});

  @override
  ConsumerState<AnnouncementDetailsScreen> createState() =>
      _AnnouncementDetailsScreenState();
}

class _AnnouncementDetailsScreenState extends ConsumerState<AnnouncementDetailsScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text(
            'You must be logged in to like or comment on announcements.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TraceColors.royalBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/student-login');
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  String? _getCurrentUserId() {
    final isAdmin = ref.read(authServiceProvider).isLoggedIn;
    if (isAdmin) return 'admin';
    
    final studentSession = ref.read(studentSessionProvider).valueOrNull;
    if (studentSession != null && studentSession.isNotEmpty) {
      return studentSession;
    }
    
    return null;
  }

  Future<void> _toggleLike() async {
    final userId = _getCurrentUserId();
    if (userId == null) {
      _showLoginPrompt();
      return;
    }

    try {
      await AnnouncementService.toggleLike(widget.announcement.id, userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update like: $e')),
        );
      }
    }
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final userId = _getCurrentUserId();
    if (userId == null) {
      _showLoginPrompt();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final comment = Comment(
        id: '', // Handled by service
        announcementId: widget.announcement.id,
        userId: userId,
        userName: userId == 'admin' ? 'Admin' : 'Student $userId', // Ideally fetch actual name, fallback for now
        content: text,
        createdAt: DateTime.now(),
      );

      await AnnouncementService.addComment(widget.announcement.id, comment);
      _commentCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final hasBanner = widget.announcement.bannerUrl.isNotEmpty;
    final userId = _getCurrentUserId();
    // Optimistic UI for likes
    final isLiked = userId != null && widget.announcement.likedBy.contains(userId);
    final likeCount = widget.announcement.likedBy.length;

    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: hasBanner ? 300 : 120,
            pinned: true,
            backgroundColor: TraceColors.navyBlue,
            flexibleSpace: FlexibleSpaceBar(
              title: hasBanner ? null : Text(
                widget.announcement.title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              background: hasBanner
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildBannerImage(widget.announcement.bannerUrl),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                TraceColors.navyBlue.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasBanner)
                    Text(
                      widget.announcement.title,
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: TraceColors.navyBlue,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: TraceColors.royalBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.announcement.category,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: TraceColors.royalBlue,
                          ),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : TraceColors.medGrey,
                              size: 24,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$likeCount',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: TraceColors.medGrey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.announcement.content,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      height: 1.6,
                      color: TraceColors.navyBlue.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Comments',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: TraceColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentCtrl,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Add a comment or ask a question...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: TraceColors.royalBlue, width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _isSubmitting
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(),
                            )
                          : IconButton(
                              icon: const Icon(Icons.send_rounded, color: TraceColors.royalBlue),
                              onPressed: _postComment,
                              iconSize: 32,
                            ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  StreamBuilder<List<Comment>>(
                    stream: AnnouncementService.streamComments(widget.announcement.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'No comments yet. Be the first to ask a question!',
                              style: GoogleFonts.inter(color: TraceColors.medGrey),
                            ),
                          ),
                        );
                      }

                      final comments = snapshot.data!;
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final c = comments[index];
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: c.userId == 'admin' 
                                          ? TraceColors.gold 
                                          : TraceColors.royalBlue,
                                      child: Text(
                                        c.userName.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      c.userName,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: TraceColors.navyBlue,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatTimeAgo(c.createdAt),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: TraceColors.medGrey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  c.content,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: TraceColors.navyBlue.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 7) return DateFormat('MMM d, yyyy').format(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
