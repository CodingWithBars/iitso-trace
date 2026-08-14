class Announcement {
  final String id;
  final String title;
  final String content;
  final String category;
  final DateTime datePosted;
  final DateTime? scheduledDate;
  final String bannerUrl;
  final List<String> likedBy;
  final int commentCount;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.datePosted,
    this.scheduledDate,
    this.bannerUrl = '',
    this.likedBy = const [],
    this.commentCount = 0,
  });

  factory Announcement.fromMap(Map<String, dynamic> data, String documentId) {
    return Announcement(
      id: documentId,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      category: data['category'] ?? '',
      datePosted: data['date_posted'] != null
          ? (data['date_posted'] as dynamic).toDate()
          : DateTime.now(),
      scheduledDate: data['scheduled_date'] != null
          ? (data['scheduled_date'] as dynamic).toDate()
          : null,
      bannerUrl: data['banner_url'] ?? '',
      likedBy: List<String>.from(data['liked_by'] ?? []),
      commentCount: data['comment_count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'category': category,
      'date_posted': datePosted,
      'scheduled_date': scheduledDate,
      'banner_url': bannerUrl,
      'liked_by': likedBy,
      'comment_count': commentCount,
    };
  }
}
