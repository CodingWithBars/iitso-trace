import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/comment.dart';

class AnnouncementService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> addComment(String announcementId, Comment comment) async {
    final announcementRef = _db.collection('announcements').doc(announcementId);
    final commentsRef = announcementRef.collection('comments');
    
    // Run in transaction to update comment count
    await _db.runTransaction((transaction) async {
      // First, get the current announcement to increment count
      final docSnapshot = await transaction.get(announcementRef);
      if (!docSnapshot.exists) {
        throw Exception("Announcement does not exist!");
      }
      
      final currentCount = docSnapshot.data()?['comment_count'] ?? 0;
      
      // Set the new comment
      final newCommentRef = commentsRef.doc();
      transaction.set(newCommentRef, {
        ...comment.toMap(),
        'id': newCommentRef.id, // Or just rely on document ID
      });
      
      // Update the comment count on the announcement
      transaction.update(announcementRef, {
        'comment_count': currentCount + 1,
      });
    });
  }

  static Stream<List<Comment>> streamComments(String announcementId) {
    return _db
        .collection('announcements')
        .doc(announcementId)
        .collection('comments')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromMap(doc.data(), doc.id))
            .toList());
  }

  static Future<void> toggleLike(String announcementId, String userId) async {
    final announcementRef = _db.collection('announcements').doc(announcementId);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(announcementRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      List<String> likedBy = List<String>.from(data['liked_by'] ?? []);
      
      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
      } else {
        likedBy.add(userId);
      }

      transaction.update(announcementRef, {'liked_by': likedBy});
    });
  }
}
