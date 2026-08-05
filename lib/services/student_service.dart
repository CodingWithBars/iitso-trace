import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import 'auth_service.dart';
import 'activity_log_service.dart';
import 'notification_service.dart';
import 'dart:convert';

class StudentService {
  static Future<String?> registerStudent({
    required String studentId,
    required String name,
    required String course,
    required String yearLevel,
    required String email,
    String? avatarUrl,
  }) async {
    try {
      // Check if student ID already exists
      final existing = await FirestoreService.students
          .where('student_id', isEqualTo: studentId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return null; // Return existing doc ID
      }

      final qrHash = const Uuid().v4();
      final docRef = await FirestoreService.students.add({
        'student_id': studentId,
        'name': name,
        'course': course,
        'year_level': yearLevel,
        'email': email,
        'avatar_url': avatarUrl ?? '',
        'qr_hash': qrHash,
        'registered_at': FieldValue.serverTimestamp(),
      });
      await ActivityLogService.log(
        action: 'student_registered',
        message: 'New student registered: $name (ID: $studentId)',
        entityType: 'student',
        entityId: docRef.id,
        actorName: name,
      );
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to register student: $e');
    }
  }

  static Future<String?> uploadAvatar(
    Uint8List imageBytes,
    String studentId,
  ) async {
    try {
      final base64String = base64Encode(imageBytes);
      return 'data:image/jpeg;base64,$base64String';
    } catch (e) {
      debugPrint('Failed to convert avatar: $e');
      return null;
    }
  }

  static Future<Student?> studentLogin(String studentId, String email) async {
    try {
      final snap = await FirestoreService.students
          .where('student_id', isEqualTo: studentId)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return Student.fromMap(
        snap.docs.first.data() as Map<String, dynamic>,
        snap.docs.first.id,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<Student?> getStudentByStudentId(String studentId) async {
    try {
      final snap = await FirestoreService.students
          .where('student_id', isEqualTo: studentId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return Student.fromMap(
        snap.docs.first.data() as Map<String, dynamic>,
        snap.docs.first.id,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<Student?> getStudentByQrHash(String qrHash) async {
    try {
      final snap = await FirestoreService.students
          .where('qr_hash', isEqualTo: qrHash)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return Student.fromMap(
        snap.docs.first.data() as Map<String, dynamic>,
        snap.docs.first.id,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<List<Attendance>> getAttendanceForStudent(
    String studentId,
  ) async {
    try {
      final snap = await FirestoreService.attendance
          .where('student_id', isEqualTo: studentId)
          .get();

      final list = snap.docs
          .map(
            (d) => Attendance.fromMap(d.data() as Map<String, dynamic>, d.id),
          )
          .toList();

      list.sort((a, b) {
        final dateA =
            a.timeInAm ??
            a.timeInPm ??
            a.timeOutAm ??
            a.timeOutPm ??
            DateTime.now();
        final dateB =
            b.timeInAm ??
            b.timeInPm ??
            b.timeOutAm ??
            b.timeOutPm ??
            DateTime.now();
        return dateB.compareTo(dateA); // descending
      });

      return list;
    } catch (e) {
      debugPrint('Error getting attendance: $e');
      return [];
    }
  }

  /// Returns true if the given studentId is already used by another document.
  /// [excludeDocId] is the current student's Firestore doc ID so they can keep their own ID.
  static Future<bool> isStudentIdTaken(
    String studentId, {
    String? excludeDocId,
  }) async {
    try {
      final snap = await FirestoreService.students
          .where('student_id', isEqualTo: studentId)
          .limit(2)
          .get();
      if (snap.docs.isEmpty) return false;
      if (excludeDocId == null) return snap.docs.isNotEmpty;
      return snap.docs.any((d) => d.id != excludeDocId);
    } catch (_) {
      return false;
    }
  }

  /// Updates name, studentId, and avatarUrl for the given Firestore doc.
  static Future<void> updateStudentProfile({
    required String docId,
    required String name,
    required String studentId,
    String? avatarUrl,
  }) async {
    final data = <String, dynamic>{'name': name, 'student_id': studentId};
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    await FirestoreService.students.doc(docId).update(data);
    await ActivityLogService.log(
      action: 'profile_updated',
      message: 'Student profile updated: $name (ID: $studentId)',
      entityType: 'student',
      entityId: docId,
      actorName: name,
    );
  }

  /// Submits an ID claim petition to the `id_claims` collection.
  static Future<void> submitIdClaim({
    required String claimedStudentId,
    required String claimantName,
    required String claimantEmail,
    required String reason,
    String? proofImageUrl,
  }) async {
    await FirestoreService.db.collection('id_claims').add({
      'claimed_student_id': claimedStudentId,
      'claimant_name': claimantName,
      'claimant_email': claimantEmail,
      'reason': reason,
      'proof_image_url': proofImageUrl ?? '',
      'status': 'pending',
      'submitted_at': FieldValue.serverTimestamp(),
    });
    await ActivityLogService.log(
      action: 'id_claim_submitted',
      message:
          'ID claim submitted by $claimantName for Student ID: $claimedStudentId',
      entityType: 'claim',
      actorName: claimantName,
    );
  }

  /// Admin: approves a claim — updates name+email on the student record and marks claim approved.
  static Future<void> approveIdClaim({
    required String claimDocId,
    required String studentDocId,
    required String newName,
    required String newEmail,
  }) async {
    final batch = FirestoreService.db.batch();
    batch.update(FirestoreService.students.doc(studentDocId), {
      'name': newName,
      'email': newEmail,
    });
    batch.update(FirestoreService.db.collection('id_claims').doc(claimDocId), {
      'status': 'approved',
      'resolved_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    await ActivityLogService.log(
      action: 'id_claim_approved',
      message:
          'ID claim APPROVED: Student record updated for $newName ($newEmail)',
      entityType: 'claim',
      entityId: claimDocId,
      actorName: 'Admin',
    );
    await NotificationService.createInAppNotification(
      title: 'ID Claim Approved',
      body:
          'Your claim for Student ID has been approved. Name updated to: $newName',
      targetRole: 'student',
      entityType: 'claim',
      entityId: claimDocId,
    );
  }

  /// Admin: rejects a claim.
  static Future<void> rejectIdClaim(String claimDocId) async {
    await FirestoreService.db.collection('id_claims').doc(claimDocId).update({
      'status': 'rejected',
      'resolved_at': FieldValue.serverTimestamp(),
    });
    await ActivityLogService.log(
      action: 'id_claim_rejected',
      message: 'ID claim REJECTED (claim: $claimDocId)',
      entityType: 'claim',
      entityId: claimDocId,
      actorName: 'Admin',
    );
  }
}
