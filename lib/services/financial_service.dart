import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/obligation.dart';
import '../models/student.dart';
import '../models/event.dart';
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

  /// Add a single student obligation/sanction
  static Future<void> createObligation(StudentObligation obligation) async {
    await _db.collection('student_obligations').add(obligation.toMap());
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

  /// Automatically generate sanctions for students missing attendance or lacking event hours
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

    int sanctionCount = 0;
    final batch = _db.batch();
    final now = DateTime.now();

    for (final student in students) {
      final hasAttended = attendedStudentIds.contains(student.id) ||
          attendedStudentIds.contains(student.studentId);

      if (!hasAttended && finePerMissedEvent > 0) {
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

  /// Fetch all organization income & expense transactions with smart deduplication
  static Future<List<OrgTransaction>> getOrgTransactions() async {
    try {
      final allDocs = <String, DocumentSnapshot<Map<String, dynamic>>>{};

      // 1. Fetch from 'funds' collection (Primary Treasury Ledger)
      final snapFunds = await _db.collection('funds').get();
      for (final doc in snapFunds.docs) {
        allDocs[doc.id] = doc;
      }

      // 2. Fetch from legacy 'org_transactions' collection only if not present in funds
      final snapOrg = await _db.collection('org_transactions').get();
      for (final doc in snapOrg.docs) {
        if (!allDocs.containsKey(doc.id)) {
          allDocs[doc.id] = doc;
        }
      }

      final list = <OrgTransaction>[];
      for (final doc in allDocs.values) {
        final data = doc.data();
        if (data != null) {
          try {
            list.add(OrgTransaction.fromMap(data, doc.id));
          } catch (err) {
            debugPrint('[FinancialService] Error parsing doc ${doc.id}: $err');
          }
        }
      }

      // 3. Smart Deduplication: collapse records with identical title, amount, type & minute
      final uniqueList = <OrgTransaction>[];
      final seenKeys = <String>{};

      for (final tx in list) {
        final key = '${tx.title.trim().toLowerCase()}_${tx.amount}_${tx.type}_${tx.date.year}_${tx.date.month}_${tx.date.day}_${tx.date.hour}_${tx.date.minute}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          uniqueList.add(tx);
        }
      }

      uniqueList.sort((a, b) => b.date.compareTo(a.date));
      return uniqueList;
    } catch (e) {
      debugPrint('[FinancialService] Error fetching org transactions: $e');
      return [];
    }
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
}
