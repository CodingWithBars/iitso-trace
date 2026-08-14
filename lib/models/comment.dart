class Comment {
  final String id;
  final String announcementId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.announcementId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromMap(Map<String, dynamic> data, String documentId) {
    return Comment(
      id: documentId,
      announcementId: data['announcement_id'] ?? '',
      userId: data['user_id'] ?? '',
      userName: data['user_name'] ?? 'Unknown',
      content: data['content'] ?? '',
      createdAt: data['created_at'] != null
          ? (data['created_at'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'announcement_id': announcementId,
      'user_id': userId,
      'user_name': userName,
      'content': content,
      'created_at': createdAt,
    };
  }
}
