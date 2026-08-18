import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/obligation.dart';
import '../models/student.dart';
import '../models/event.dart';
import '../models/attendance.dart';
import 'auth_service.dart';
import 'student_service.dart';

class FinancialService {
  static FirebaseFirestore get _db => FirestoreService.db;

  // ---------------------------------------------------------------------------
  // Student Obligations & Dues
  // ---------------------------------------------------------------------------

  /// Fetch all obligations for a specific student (matches both studentId string and doc ID)
  static Future<List<StudentObligation>> getObligationsForStudent(String inputId) async {
    try {
      final idSet = <String>{inputId};
      final student = await StudentService.getStudentByStudentId(inputId);
      if (student != null) {
        if (student.studentId.isNotEmpty) idSet.add(student.studentId);
        if (student.id.isNotEmpty) idSet.add(student.id);
      }

      final allDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final id in idSet) {
        if (id.trim().isEmpty) continue;
        final snap = await _db
            .collection('student_obligations')
            .where('student_id', isEqualTo: id)
            .get();
        for (final doc in snap.docs) {
          allDocs[doc.id] = doc;
        }
      }

      final list = allDocs.values
          .map((doc) => StudentObligation.fromMap(doc.data()!, doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('[FinancialService] Error fetching student obligations: $e');
      return [];
    }
  }

  /// Fetch all student obligations across the organization
  static Future<List<StudentObligation>> getAllObligations() async {
    try {
      final snap = await _db.collection('student_obligations').get();
      final list = snap.docs.map((doc) => StudentObligation.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('[FinancialService] Error fetching all obligations: $e');
      return [];
    }
  }

  /// Stream paginated student obligations
  static Stream<QuerySnapshot> streamObligations({int limit = 50}) {
    return _db
        .collection('student_obligations')
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Fetch all obligations for a specific student
  static Future<List<StudentObligation>> getStudentObligations(String studentId) async {
    try {
      final snap = await _db
          .collection('student_obligations')
          .where('student_id', isEqualTo: studentId)
          .get();
      final list = snap.docs.map((doc) => StudentObligation.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('[FinancialService] Error fetching student obligations: $e');
      return [];
    }
  }

  /// Add a single student obligation/sanction
  static Future<void> createObligation(StudentObligation obligation) async {
    await _db.collection('student_obligations').add(obligation.toMap());
  }

  /// Clears all generated sanctions for a specific event
  static Future<int> clearEventSanctions(String eventId) async {
    final snap = await _db
        .collection('student_obligations')
        .where('event_id', isEqualTo: eventId)
        .where('type', isEqualTo: 'sanction')
        .get();
    
    if (snap.docs.isEmpty) return 0;

    final batch = _db.batch();
    for (var doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    
    return snap.docs.length;
  }

  /// Batch assign obligation (e.g., Membership fee or Event contribution) to multiple students
  static Future<int> batchCreateObligation({
    required List<Student> students,
    required String title,
    required String type, // 'contribution' | 'membership_fee' | 'sanction'
    required double amount,
    String? eventId,
    DateTime? dueDate,
    String? remarks,
  }) async {
    int createdCount = 0;
    final batch = _db.batch();
    final now = DateTime.now();

    for (final student in students) {
      final docRef = _db.collection('student_obligations').doc();
      final obligation = StudentObligation(
        id: docRef.id,
        studentId: student.studentId,
        studentName: student.name,
        title: title,
        type: type,
        eventId: eventId,
        amount: amount,
        amountPaid: 0.0,
        status: 'unpaid',
        dueDate: dueDate,
        remarks: remarks,
        createdAt: now,
      );

      batch.set(docRef, obligation.toMap());
      createdCount++;
    }

    await batch.commit();
    return createdCount;
  }

  // ---------------------------------------------------------------------------
  // Payment Processing (Manual Cash / GCash Record)
  // ---------------------------------------------------------------------------

  /// Record cash/GCash payment for a student obligation
  static Future<void> recordPayment({
    required String obligationId,
    required String studentId,
    required double amountPaid,
    required String paymentMethod,
    String? referenceNo,
    required String recordedBy,
  }) async {
    final obRef = _db.collection('student_obligations').doc(obligationId);
    final obSnap = await obRef.get();

    if (!obSnap.exists) {
      throw Exception('Obligation record not found.');
    }

    final currentOb = StudentObligation.fromMap(obSnap.data()!, obSnap.id);
    final newAmountPaid = currentOb.amountPaid + amountPaid;
    final newStatus = newAmountPaid >= currentOb.amount ? 'paid' : 'partially_paid';

    // 1. Update obligation record
    await obRef.update({
      'amount_paid': newAmountPaid,
      'status': newStatus,
    });

    // 2. Add payment transaction log
    final paymentLog = PaymentRecord(
      id: '',
      obligationId: obligationId,
      studentId: studentId,
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
      referenceNo: referenceNo,
      recordedBy: recordedBy,
      paidAt: DateTime.now(),
    );
    await _db.collection('payment_records').add(paymentLog.toMap());

    // 3. Log into Org Financial Ledger as income contribution
    final orgTx = OrgTransaction(
      id: '',
      title: '${currentOb.title} payment from $studentId',
      type: 'income',
      category: currentOb.type == 'membership_fee' ? 'dues' : 'contributions',
      amount: amountPaid,
      date: DateTime.now(),
      recordedBy: recordedBy,
    );
    await addOrgTransaction(orgTx);
  }

  // ---------------------------------------------------------------------------
  // Sanctions Auto-Generator
  // ---------------------------------------------------------------------------

  /// Automatically generate sanctions for students missing attendance or lacking event hours.
  /// Safe to call multiple times — will not create duplicate sanctions.
  static Future<int> autoGenerateSanctionsForEvent({
    required Event event,
    required double finePerMissedEvent,
    required double finePerLackingHour,
    required String recordedBy,
  }) async {
    final students = await StudentService.getAllStudents();
    final attendanceSnap = await _db
        .collection('attendance')
        .where('event_id', isEqualTo: event.id)
        .get();

    final attendedStudentIds = <String>{};
    for (final doc in attendanceSnap.docs) {
      final sId = doc.data()['student_id'] as String?;
      if (sId != null && sId.isNotEmpty) {
        attendedStudentIds.add(sId);
      }
    }

    // FIX: Check for already-created sanctions to prevent duplicates on re-run
    final existingSanctionsSnap = await _db
        .collection('student_obligations')
        .where('event_id', isEqualTo: event.id)
        .where('type', isEqualTo: 'sanction')
        .get();
    final alreadySanctioned = <String>{};
    for (final doc in existingSanctionsSnap.docs) {
      final sId = doc.data()['student_id'] as String?;
      if (sId != null) alreadySanctioned.add(sId);
    }

    int sanctionCount = 0;
    final batch = _db.batch();
    final now = DateTime.now();

    for (final student in students) {
      final hasAttended = attendedStudentIds.contains(student.id) ||
          attendedStudentIds.contains(student.studentId);
      final alreadyHas = alreadySanctioned.contains(student.id) ||
          alreadySanctioned.contains(student.studentId);

      if (!hasAttended && !alreadyHas && finePerMissedEvent > 0) {
        final docRef = _db.collection('student_obligations').doc();
        final sanction = StudentObligation(
          id: docRef.id,
          studentId: student.studentId,
          studentName: student.name,
          title: 'Sanction: Absent in ${event.eventName}',
          type: 'sanction',
          eventId: event.id,
          amount: finePerMissedEvent,
          amountPaid: 0.0,
          status: 'unpaid',
          remarks: 'Unexcused absence for event held on ${event.date.toString().split(' ').first}',
          createdAt: now,
        );
        batch.set(docRef, sanction.toMap());
        sanctionCount++;
      }
    }

    if (sanctionCount > 0) {
      await batch.commit();
    }
    return sanctionCount;
  }


  // ---------------------------------------------------------------------------
  // Organization Financial Transparency Ledger
  // ---------------------------------------------------------------------------

  /// Fetch all organization income & expense transactions
  static Future<List<OrgTransaction>> getOrgTransactions() async {
    try {
      final snapFunds = await _db.collection('funds').get();
      
      final list = <OrgTransaction>[];
      for (final doc in snapFunds.docs) {
        final data = doc.data();
        try {
          // Keep backward compatibility: parse title from description if title is missing
          if (!data.containsKey('title') && data.containsKey('description')) {
            data['title'] = data['description'];
          }
          list.add(OrgTransaction.fromMap(data, doc.id));
        } catch (err) {
          debugPrint('[FinancialService] Error parsing doc ${doc.id}: $err');
        }
      }

      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (e) {
      debugPrint('[FinancialService] Error fetching org transactions: $e');
      return [];
    }
  }

  /// One-time script to migrate legacy 'org_transactions' into 'funds'
  static Future<int> migrateLegacyOrgTransactionsToFunds() async {
    final legacySnap = await _db.collection('org_transactions').get();
    if (legacySnap.docs.isEmpty) return 0;
    
    final batch = _db.batch();
    int count = 0;
    
    for (final doc in legacySnap.docs) {
      final data = doc.data();
      final newRef = _db.collection('funds').doc();
      
      // Ensure description exists for funds collection mapping
      if (data.containsKey('title') && !data.containsKey('description')) {
        data['description'] = data['title'];
      }
      
      batch.set(newRef, data);
      count++;
    }
    
    if (count > 0) {
      await batch.commit();
      
      // Delete legacy collection records after migrating? 
      // Usually, we'd do a secondary batch to delete, but for safety we might just leave them 
      // or the user can manually delete them from Firebase Console.
    }
    return count;
  }

  /// Add a financial transaction (income or expense) to the org ledger funds collection
  static Future<void> addOrgTransaction(OrgTransaction transaction) async {
    final map = transaction.toMap();
    map['description'] = transaction.title;
    await _db.collection('funds').add(map);
  }

  /// Delete obligation (Admin override)
  static Future<void> deleteObligation(String obligationId) async {
    await _db.collection('student_obligations').doc(obligationId).delete();
  }

  /// Apply the event's built-in sanctions to all students not recorded in attendance.
  /// Returns the number of sanction records created.
  static Future<int> applyEventSanctions(Event event, String recordedBy) async {
    // Only proceed if event has a sanction configured
    final hasMonetary = (event.sanctionAmount ?? 0) > 0;
    final hasNonMonetary = event.sanctionDescription != null && event.sanctionDescription!.isNotEmpty;
    if (!hasMonetary && !hasNonMonetary) return 0;

    final students = await StudentService.getAllStudents();
    final attendanceSnap = await _db
        .collection('attendance')
        .where('event_id', isEqualTo: event.id)
        .get();

    final attendanceRecords = <String, Map<String, dynamic>>{};
    for (final doc in attendanceSnap.docs) {
      final data = doc.data();
      final sId = data['student_id'] as String?;
      if (sId != null && sId.isNotEmpty) {
        attendanceRecords[sId] = data;
      }
    }

    // Also check if this student already has a sanction for this event to avoid duplicates
    final existingSanctionsSnap = await _db
        .collection('student_obligations')
        .where('event_id', isEqualTo: event.id)
        .where('type', isEqualTo: 'sanction')
        .get();
    final alreadySanctioned = <String>{};
    for (final doc in existingSanctionsSnap.docs) {
      final sId = doc.data()['student_id'] as String?;
      if (sId != null) alreadySanctioned.add(sId);
    }

    int count = 0;
    final batch = _db.batch();
    final now = DateTime.now();

    for (final student in students) {
      final id1 = student.id;
      final id2 = student.studentId;
      final attData = attendanceRecords[id1] ?? attendanceRecords[id2];
      final alreadyHas = alreadySanctioned.contains(id1) || alreadySanctioned.contains(id2);

      if (alreadyHas) continue;

      double amount = 0.0;
      String title = '';
      String remarks = '';
      bool createObligation = false;

      if (attData == null) {
        // Absent
        createObligation = true;
        amount = hasMonetary ? event.sanctionAmount! : 0.0;
        title = 'Absent: ${event.eventName}';
        remarks = hasNonMonetary
            ? event.sanctionDescription!
            : 'Absent on ${event.date.toString().split(' ').first}';
      } else {
        final att = Attendance.fromMap(attData, '');
        final det = DetailedAttendance.calculate(att, event);
        final status = det.overallStatus;

        if (status == 'ABSENT') {
          createObligation = true;
          amount = hasMonetary ? event.sanctionAmount! : 0.0;
          title = 'Absent: ${event.eventName}';
          remarks = hasNonMonetary
              ? event.sanctionDescription!
              : 'Absent on ${event.date.toString().split(' ').first}';
        } else if (status == 'EXCUSED') {
          // Do nothing for excused
        } else if (status == 'VOID') {
           createObligation = true;
           amount = hasMonetary ? event.sanctionAmount! : 0.0;
           title = 'Absent: ${event.eventName}';
           remarks = 'Invalid/Voided scans for ${event.eventName}';
        } else if (status == 'LATE' || status == 'INCOMPLETE') {
          createObligation = true;
          amount = hasMonetary ? (event.sanctionAmount! / 2.0) : 0.0;
          final isLate = status == 'LATE';
          title = isLate ? 'Late: ${event.eventName}' : 'Incomplete: ${event.eventName}';
          remarks = hasNonMonetary 
              ? '${isLate ? 'Late' : 'Incomplete'} penalty: ${event.sanctionDescription}'
              : 'Penalty for ${isLate ? 'late' : 'incomplete'} attendance';
        }
      }

      if (createObligation) {
        final docRef = _db.collection('student_obligations').doc();
        final sanction = StudentObligation(
          id: docRef.id,
          studentId: student.studentId,
          studentName: student.name,
          title: title,
          type: 'sanction',
          eventId: event.id,
          amount: amount,
          amountPaid: 0.0,
          status: amount > 0 ? 'unpaid' : 'non-monetary',
          remarks: remarks,
          createdAt: now,
        );
        batch.set(docRef, sanction.toMap());
        count++;
      }
    }

    if (count > 0) await batch.commit();
    return count;
  }

  /// Bulk-assign event contribution obligation to all registered students.
  static Future<int> applyEventContribution(Event event, String recordedBy) async {
    final contribution = event.eventContribution ?? 0;
    if (contribution <= 0) return 0;

    final students = await StudentService.getAllStudents();

    // Avoid duplicating contribution for same event
    final existingSnap = await _db
        .collection('student_obligations')
        .where('event_id', isEqualTo: event.id)
        .where('type', isEqualTo: 'contribution')
        .get();
    final alreadyAssigned = <String>{};
    for (final doc in existingSnap.docs) {
      final sId = doc.data()['student_id'] as String?;
      if (sId != null) alreadyAssigned.add(sId);
    }

    int count = 0;
    final batch = _db.batch();
    final now = DateTime.now();

    for (final student in students) {
      if (!alreadyAssigned.contains(student.studentId) &&
          !alreadyAssigned.contains(student.id)) {
        final docRef = _db.collection('student_obligations').doc();
        final obligation = StudentObligation(
          id: docRef.id,
          studentId: student.studentId,
          studentName: student.name,
          title: 'Contribution: ${event.eventName}',
          type: 'contribution',
          eventId: event.id,
          amount: contribution,
          amountPaid: 0.0,
          status: 'unpaid',
          remarks: 'Event contribution for ${event.eventName}',
          createdAt: now,
        );
        batch.set(docRef, obligation.toMap());
        count++;
      }
    }

    if (count > 0) await batch.commit();
    return count;
  }

  /// Mark an obligation as fully settled (paid/fulfilled).
  static Future<void> markObligationSettled(String obligationId) async {
    await _db.collection('student_obligations').doc(obligationId).update({
      'status': 'paid',
      'amount_paid': await _db
          .collection('student_obligations')
          .doc(obligationId)
          .get()
          .then((d) => d.data()?['amount'] ?? 0),
    });
  }

  /// Assign membership fee to all students (or a subset). Skips students who already have it.
  static Future<int> assignMembershipFee({
    required double amount,
    required String semester, // e.g. '2nd Semester AY 2024-2025'
    required String recordedBy,
    List<Student>? targetStudents, // null = all students
  }) async {
    final students = targetStudents ?? await StudentService.getAllStudents();
    final title = 'Org Membership Fee – $semester';

    // Check existing to avoid duplicates
    final existingSnap = await _db
        .collection('student_obligations')
        .where('title', isEqualTo: title)
        .where('type', isEqualTo: 'membership_fee')
        .get();
    final alreadyAssigned = <String>{};
    for (final doc in existingSnap.docs) {
      final sId = doc.data()['student_id'] as String?;
      if (sId != null) alreadyAssigned.add(sId);
    }

    int count = 0;
    final batch = _db.batch();
    final now = DateTime.now();

    for (final student in students) {
      if (!alreadyAssigned.contains(student.studentId) &&
          !alreadyAssigned.contains(student.id)) {
        final docRef = _db.collection('student_obligations').doc();
        final obligation = StudentObligation(
          id: docRef.id,
          studentId: student.studentId,
          studentName: student.name,
          title: title,
          type: 'membership_fee',
          eventId: null,
          amount: amount,
          amountPaid: 0.0,
          status: 'unpaid',
          remarks: 'Org membership dues for $semester',
          createdAt: now,
        );
        batch.set(docRef, obligation.toMap());
        count++;
      }
    }

    if (count > 0) await batch.commit();
    return count;
  }
}

