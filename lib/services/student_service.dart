import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import 'auth_service.dart';
import 'activity_log_service.dart';
import 'notification_service.dart';
import 'offline_cache_service.dart';
import 'network_service.dart';
import 'dart:convert';

class StudentService {
  /// Hashes a plain-text PIN with SHA-256 for safe storage in Firestore.
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  static Future<String?> registerStudent({
    required String studentId,
    required String name,
    required String course,
    required String yearLevel,
    required String section,
    required String email,
    String? avatarUrl,
    required String pin, // 4–6 digit PIN, stored as SHA-256 hash
  }) async {
    try {
      // Check if student ID already exists
      final existing = await FirestoreService.students
          .where('student_id', isEqualTo: studentId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return null; // Student ID taken
      }

      final qrHash = const Uuid().v4();
      final docRef = await FirestoreService.students.add({
        'student_id': studentId,
        'name': name,
        'course': course,
        'year_level': yearLevel,
        'section': section,
        'email': email,
        'avatar_url': avatarUrl ?? '',
        'qr_hash': qrHash,
        'pin_hash': hashPin(pin),
        'registered_at': FieldValue.serverTimestamp(),
      });
      await ActivityLogService.log(
        action: 'student_registered',
        message: 'New student registered: $name (ID: $studentId)',
        entityType: 'student',
        entityId: docRef.id,
        actorName: name,
      );

      // RESTORE ARCHIVED RECORDS (if any exist for this email)
      final archivedId = 'archived_$email';
      final archivedAttendance = await FirestoreService.attendance
          .where('student_id', isEqualTo: archivedId)
          .get();
      
      if (archivedAttendance.docs.isNotEmpty) {
        final batch = FirestoreService.db.batch();
        for (var doc in archivedAttendance.docs) {
          batch.update(doc.reference, {'student_id': studentId});
        }
        await batch.commit();
        
        await ActivityLogService.log(
          action: 'records_restored',
          message: 'Restored ${archivedAttendance.docs.length} archived attendance records for $email to new ID $studentId',
          entityType: 'student',
          entityId: docRef.id,
          actorName: 'System',
        );
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to register student: $e');
    }
  }

  /// Sets or resets the PIN for an existing student document.
  static Future<void> setStudentPin(String docId, String newPin) async {
    await FirestoreService.students
        .doc(docId)
        .update({'pin_hash': hashPin(newPin)});
  }

  /// Uploads avatar bytes to Firebase Storage and returns the download URL.
  /// Falls back to base64 if Firebase Storage is unavailable (e.g., offline).
  static Future<String?> uploadAvatar(
    Uint8List imageBytes,
    String studentId,
  ) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('student_avatars')
          .child('$studentId.jpg');
      final uploadTask = await ref.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Storage upload failed, falling back to base64: $e');
      final base64String = base64Encode(imageBytes);
      return 'data:image/jpeg;base64,$base64String';
    }
  }

  /// Login with Student ID + email + PIN.
  /// For legacy accounts (no pin_hash stored), allows login without PIN
  /// and prompts them to set one after first login.
  ///
  /// If the device is truly offline and Firestore cannot serve the query,
  /// falls back to the locally-cached profile in [OfflineCacheService].
  static Future<StudentLoginResult> studentLogin(
    String studentId,
    String email,
    String pin,
  ) async {
    try {
      final snap = await FirestoreService.students
          .where('student_id', isEqualTo: studentId)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        // If we're genuinely offline, the empty result could be a cache miss —
        // try the local profile cache before saying "not found".
        // If we're online, empty means wrong credentials (truly not found).
        if (NetworkService().isOffline) {
          return _offlineLoginFallback(studentId, email, pin);
        }
        return StudentLoginResult.notFound();
      }

      final data = snap.docs.first.data() as Map<String, dynamic>;
      final storedHash = data['pin_hash'] as String?;

      // Legacy account: no PIN set yet — let them in but flag to set PIN
      if (storedHash == null || storedHash.isEmpty) {
        final student = Student.fromMap(data, snap.docs.first.id);
        return StudentLoginResult.needsPinSetup(student);
      }

      // Verify PIN
      if (hashPin(pin) != storedHash) {
        return StudentLoginResult.wrongPin();
      }

      return StudentLoginResult.success(
        Student.fromMap(data, snap.docs.first.id),
        pinHash: storedHash,
      );
    } catch (e) {
      // Network / permission error — attempt offline fallback
      debugPrint('StudentService.studentLogin online attempt failed: $e');
      return _offlineLoginFallback(studentId, email, pin);
    }
  }

  /// Verifies credentials against the locally-cached student profile.
  /// Called when Firestore is unreachable.
  static Future<StudentLoginResult> _offlineLoginFallback(
    String studentId,
    String email,
    String pin,
  ) async {
    final cached = await OfflineCacheService.getStudentProfile(studentId);
    if (cached == null) return StudentLoginResult.notFound();

    // Verify email matches
    final cachedEmail = (cached['email'] as String? ?? '').toLowerCase().trim();
    if (cachedEmail != email.toLowerCase().trim()) {
      return StudentLoginResult.notFound();
    }

    final storedHash = cached['pin_hash'] as String?;

    // Legacy account cached with no PIN
    if (storedHash == null || storedHash.isEmpty) {
      final student = Student.fromMap(cached, cached['id'] as String? ?? '');
      return StudentLoginResult.needsPinSetup(student);
    }

    if (hashPin(pin) != storedHash) {
      return StudentLoginResult.wrongPin();
    }

    final student = Student.fromMap(cached, cached['id'] as String? ?? '');
    return StudentLoginResult.success(student, pinHash: storedHash, isOffline: true);
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

  /// Updates name and avatarUrl for the given Firestore doc.
  /// Student ID is intentionally NOT updatable here — changes must go
  /// through an admin-approved ID Claim to prevent identity spoofing.
  static Future<void> updateStudentProfile({
    required String docId,
    required String name,
    String? avatarUrl,
    String? section,
  }) async {
    final data = <String, dynamic>{'name': name};
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    if (section != null) data['section'] = section;
    await FirestoreService.students.doc(docId).update(data);
    await ActivityLogService.log(
      action: 'profile_updated',
      message: 'Student profile updated: $name',
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

  /// Admin: approves a claim.
  /// If [keepRecords] is true, restores the account (updates email and un-archives it).
  /// If [keepRecords] is false, archives the old user's records to their old email and creates a fresh account for the claimant.
  static Future<void> approveIdClaim({
    required String claimDocId,
    required String studentDocId,
    required String newName,
    required String newEmail,
    required bool keepRecords,
  }) async {
    final batch = FirestoreService.db.batch();

    // 1. Get the existing student document
    final oldDocSnap = await FirestoreService.students.doc(studentDocId).get();
    if (!oldDocSnap.exists) throw Exception('Student document not found');
    final oldData = oldDocSnap.data() as Map<String, dynamic>;
    final oldEmail = oldData['email'] as String;
    final claimedStudentId = oldData['student_id'] as String;

    if (keepRecords) {
      // Restore Mode: Just update the existing document's email/name and un-archive
      batch.update(oldDocSnap.reference, {
        'email': newEmail,
        'name': newName,
        'pin_hash': '', // Force new PIN on login
        'is_archived': false,
        'avatar_url': '', // Reset avatar so they can upload a new one
      });

      await ActivityLogService.log(
        action: 'id_claim_approved',
        message: 'ID claim APPROVED (Restore Mode): Restored account for $claimedStudentId with new email $newEmail.',
        entityType: 'claim',
        entityId: claimDocId,
        actorName: 'Admin',
      );
    } else {
      // Discard Mode: Archive old records and create fresh account
      final archivedId = 'archived_$oldEmail';
      batch.update(oldDocSnap.reference, {
        'student_id': archivedId,
      });

      // Update attendance
      final attendanceSnap = await FirestoreService.attendance
          .where('student_id', isEqualTo: claimedStudentId)
          .get();
      for (var doc in attendanceSnap.docs) {
        batch.update(doc.reference, {'student_id': archivedId});
      }

      // Update obligations
      final obligationsSnap = await FirestoreService.db
          .collection('student_obligations')
          .where('student_id', isEqualTo: claimedStudentId)
          .get();
      for (var doc in obligationsSnap.docs) {
        batch.update(doc.reference, {'student_id': archivedId});
      }

      // Update payments
      final paymentsSnap = await FirestoreService.db
          .collection('payment_records')
          .where('student_id', isEqualTo: claimedStudentId)
          .get();
      for (var doc in paymentsSnap.docs) {
        batch.update(doc.reference, {'student_id': archivedId});
      }

      // Create new fresh account
      final newStudentRef = FirestoreService.students.doc();
      batch.set(newStudentRef, {
        'student_id': claimedStudentId,
        'name': newName,
        'course': oldData['course'] ?? '',
        'year_level': oldData['year_level'] ?? '',
        'email': newEmail,
        'avatar_url': '',
        'qr_hash': const Uuid().v4(),
        'pin_hash': '', 
        'registered_at': FieldValue.serverTimestamp(),
      });

      await ActivityLogService.log(
        action: 'id_claim_approved',
        message: 'ID claim APPROVED (Discard Mode): Created new account for $newName and archived old data for $oldEmail.',
        entityType: 'claim',
        entityId: claimDocId,
        actorName: 'Admin',
      );
    }

    // Update the claim status
    batch.update(FirestoreService.db.collection('id_claims').doc(claimDocId), {
      'status': 'approved',
      'resolved_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    await NotificationService.createInAppNotification(
      title: 'ID Claim Approved',
      body: 'Your claim for Student ID has been approved. You can now log in using your ID and email.',
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

  /// Returns a list of all registered students
  static Future<List<Student>> getAllStudents() async {
    try {
      final snap = await FirestoreService.students.get();
      return snap.docs
          .map((d) => Student.fromMap(d.data() as Map<String, dynamic>, d.id))
          .where((s) => s.isArchived != true)
          .toList();
    } catch (e) {
      debugPrint('Error getting all students: $e');
      return [];
    }
  }

  /// Admin: Manually restores archived records if the student used the WRONG email 
  /// during their original mistake and therefore couldn't be automatically restored.
  static Future<int> restoreArchivedRecords({
    required String wrongEmail,
    required String correctStudentId,
    required String adminName,
  }) async {
    final archivedId = 'archived_$wrongEmail';
    final snap = await FirestoreService.attendance
        .where('student_id', isEqualTo: archivedId)
        .get();

    if (snap.docs.isEmpty) return 0;

    final batch = FirestoreService.db.batch();
    for (var doc in snap.docs) {
      batch.update(doc.reference, {'student_id': correctStudentId});
    }
    await batch.commit();

    await ActivityLogService.log(
      action: 'admin_restored_records',
      message: 'Admin manually restored ${snap.docs.length} records from wrong email $wrongEmail to ID $correctStudentId',
      entityType: 'student',
      entityId: correctStudentId,
      actorName: adminName,
    );

    return snap.docs.length;
  }

  /// Admin: Migrates all base64 avatars in Firestore to Firebase Storage
  static Future<int> migrateBase64AvatarsToStorage() async {
    final snap = await FirestoreService.students.get();
    int migratedCount = 0;

    for (var doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final avatarUrl = data['avatar_url'] as String?;
      final studentId = data['student_id'] as String?;
      
      if (avatarUrl != null && avatarUrl.startsWith('data:image') && studentId != null) {
        try {
          final base64Str = avatarUrl.split(',').last;
          final bytes = base64Decode(base64Str);
          
          final newUrl = await uploadAvatar(bytes, studentId);
          if (newUrl != null) {
            await doc.reference.update({'avatar_url': newUrl});
            migratedCount++;
          }
        } catch (e) {
          debugPrint('Failed to migrate avatar for $studentId: $e');
        }
      }
    }
    return migratedCount;
  }
  /// Admin: Deletes a student if they have no records, otherwise archives them.
  static Future<void> deleteOrArchiveStudent(String docId, String studentId) async {
    // 1. Check for records
    final attendanceSnap = await FirestoreService.attendance
        .where('student_id', isEqualTo: studentId)
        .limit(1)
        .get();
        
    final obligationsSnap = await FirestoreService.db
        .collection('student_obligations')
        .where('student_id', isEqualTo: studentId)
        .limit(1)
        .get();
        
    final paymentsSnap = await FirestoreService.db
        .collection('payment_records')
        .where('student_id', isEqualTo: studentId)
        .limit(1)
        .get();

    final hasRecords = attendanceSnap.docs.isNotEmpty ||
        obligationsSnap.docs.isNotEmpty ||
        paymentsSnap.docs.isNotEmpty;

    if (hasRecords) {
      // Archive: Mark as archived
      await FirestoreService.students.doc(docId).update({
        'is_archived': true,
        'archived_at': FieldValue.serverTimestamp(),
      });
      await ActivityLogService.log(
        action: 'student_archived',
        message: 'Archived student $studentId because they have existing records',
        entityType: 'student',
        entityId: docId,
        actorName: 'Admin',
      );
    } else {
      // Hard Delete
      await FirestoreService.students.doc(docId).delete();
      await ActivityLogService.log(
        action: 'student_deleted',
        message: 'Hard deleted student $studentId (no records found)',
        entityType: 'student',
        entityId: docId,
        actorName: 'Admin',
      );
    }
  }

}

// ---------------------------------------------------------------------------
// Result object for studentLogin() — avoids nullable anti-patterns
// ---------------------------------------------------------------------------
enum LoginStatus { success, notFound, wrongPin, needsPinSetup }

class StudentLoginResult {
  final LoginStatus status;
  final Student? student;
  /// The raw SHA-256 pin_hash string, forwarded to [OfflineCacheService] on
  /// success so we can cache it without re-hashing.
  final String? pinHash;
  /// True when the result came from local cache (no Firestore connection).
  final bool isOffline;

  const StudentLoginResult._(
    {required this.status, this.student, this.pinHash, this.isOffline = false});

  factory StudentLoginResult.success(Student s, {String? pinHash, bool isOffline = false}) =>
      StudentLoginResult._(status: LoginStatus.success, student: s, pinHash: pinHash, isOffline: isOffline);

  factory StudentLoginResult.needsPinSetup(Student s) =>
      StudentLoginResult._(status: LoginStatus.needsPinSetup, student: s);

  factory StudentLoginResult.notFound() =>
      const StudentLoginResult._(status: LoginStatus.notFound);

  factory StudentLoginResult.wrongPin() =>
      const StudentLoginResult._(status: LoginStatus.wrongPin);

  bool get isSuccess =>
      status == LoginStatus.success || status == LoginStatus.needsPinSetup;
}

