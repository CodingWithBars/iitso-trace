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
      debugPrint('Storage upload failed: $e');
      return null;
    }
  }

  /// Login with Student ID + email + PIN.
  /// For legacy accounts (no pin_hash stored), allows login without PIN
  /// and prompts them to set one after first login.
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
      if (snap.docs.isEmpty) return StudentLoginResult.notFound();

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
      );
    } catch (e) {
      return StudentLoginResult.notFound();
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

  /// Updates name and avatarUrl for the given Firestore doc.
  /// Student ID is intentionally NOT updatable here — changes must go
  /// through an admin-approved ID Claim to prevent identity spoofing.
  static Future<void> updateStudentProfile({
    required String docId,
    required String name,
    String? avatarUrl,
  }) async {
    final data = <String, dynamic>{'name': name};
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
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

  /// Admin: approves a claim — archives the wrong owner and creates a new account for the claimant.
  static Future<void> approveIdClaim({
    required String claimDocId,
    required String studentDocId,
    required String newName,
    required String newEmail,
  }) async {
    final batch = FirestoreService.db.batch();

    // 1. Get the existing (wrong) student document to archive it
    final oldDocSnap = await FirestoreService.students.doc(studentDocId).get();
    if (!oldDocSnap.exists) throw Exception('Student document not found');
    final oldData = oldDocSnap.data() as Map<String, dynamic>;
    final oldEmail = oldData['email'] as String;
    final claimedStudentId = oldData['student_id'] as String;

    // 2. Update the old document to use the archived ID
    final archivedId = 'archived_$oldEmail';
    batch.update(oldDocSnap.reference, {
      'student_id': archivedId,
    });

    // 3. Query all attendance records for this student_id and update them to the archived ID
    final attendanceSnap = await FirestoreService.attendance
        .where('student_id', isEqualTo: claimedStudentId)
        .get();
    
    for (var doc in attendanceSnap.docs) {
      batch.update(doc.reference, {'student_id': archivedId});
    }

    // 4. Create a brand new document for the legitimate claimant
    final newStudentRef = FirestoreService.students.doc();
    batch.set(newStudentRef, {
      'student_id': claimedStudentId,
      'name': newName,
      'course': oldData['course'] ?? '',
      'year_level': oldData['year_level'] ?? '',
      'email': newEmail,
      'avatar_url': '',
      'qr_hash': const Uuid().v4(),
      'pin_hash': '', // Empty so they are forced to set a PIN upon first login
      'registered_at': FieldValue.serverTimestamp(),
    });

    // 5. Update the claim status
    batch.update(FirestoreService.db.collection('id_claims').doc(claimDocId), {
      'status': 'approved',
      'resolved_at': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    await ActivityLogService.log(
      action: 'id_claim_approved',
      message:
          'ID claim APPROVED: Created new account for $newName and archived old data for $oldEmail.',
      entityType: 'claim',
      entityId: claimDocId,
      actorName: 'Admin',
    );
    await NotificationService.createInAppNotification(
      title: 'ID Claim Approved',
      body:
          'Your claim for Student ID has been approved. You can now log in using your ID and email.',
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
}

// ---------------------------------------------------------------------------
// Result object for studentLogin() — avoids nullable anti-patterns
// ---------------------------------------------------------------------------
enum LoginStatus { success, notFound, wrongPin, needsPinSetup }

class StudentLoginResult {
  final LoginStatus status;
  final Student? student;

  const StudentLoginResult._({required this.status, this.student});

  factory StudentLoginResult.success(Student s) =>
      StudentLoginResult._(status: LoginStatus.success, student: s);

  factory StudentLoginResult.needsPinSetup(Student s) =>
      StudentLoginResult._(status: LoginStatus.needsPinSetup, student: s);

  factory StudentLoginResult.notFound() =>
      const StudentLoginResult._(status: LoginStatus.notFound);

  factory StudentLoginResult.wrongPin() =>
      const StudentLoginResult._(status: LoginStatus.wrongPin);

  bool get isSuccess =>
      status == LoginStatus.success || status == LoginStatus.needsPinSetup;
}

