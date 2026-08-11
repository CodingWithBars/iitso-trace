import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a student financial obligation (membership fee, event contribution, or sanction fine)
class StudentObligation {
  final String id;
  final String studentId;
  final String studentName;
  final String title;
  final String type; // 'contribution' | 'membership_fee' | 'sanction' | 'other'
  final String? eventId;
  final double amount;
  final double amountPaid;
  final String status; // 'unpaid' | 'partially_paid' | 'paid'
  final DateTime? dueDate;
  final String? remarks;
  final DateTime createdAt;

  StudentObligation({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.title,
    required this.type,
    this.eventId,
    required this.amount,
    required this.amountPaid,
    required this.status,
    this.dueDate,
    this.remarks,
    required this.createdAt,
  });

  double get remainingBalance => (amount - amountPaid).clamp(0.0, double.infinity);
  bool get isFullyPaid => remainingBalance <= 0 || status == 'paid';

  factory StudentObligation.fromMap(Map<String, dynamic> data, String docId) {
    final amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final amtPaid = (data['amount_paid'] as num?)?.toDouble() ?? 0.0;
    final statusStr = data['status'] ?? (amtPaid >= amt ? 'paid' : (amtPaid > 0 ? 'partially_paid' : 'unpaid'));

    return StudentObligation(
      id: docId,
      studentId: data['student_id'] ?? '',
      studentName: data['student_name'] ?? '',
      title: data['title'] ?? '',
      type: data['type'] ?? 'other',
      eventId: data['event_id'],
      amount: amt,
      amountPaid: amtPaid,
      status: statusStr,
      dueDate: data['due_date'] != null ? (data['due_date'] as Timestamp).toDate() : null,
      remarks: data['remarks'],
      createdAt: data['created_at'] != null ? (data['created_at'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'student_name': studentName,
      'title': title,
      'type': type,
      'event_id': eventId,
      'amount': amount,
      'amount_paid': amountPaid,
      'status': status,
      'due_date': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'remarks': remarks,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}

/// Represents a cash/GCash payment transaction recorded for a student obligation
class PaymentRecord {
  final String id;
  final String obligationId;
  final String studentId;
  final double amountPaid;
  final String paymentMethod; // 'cash' | 'gcash' | 'bank_transfer'
  final String? referenceNo;
  final String recordedBy;
  final DateTime paidAt;

  PaymentRecord({
    required this.id,
    required this.obligationId,
    required this.studentId,
    required this.amountPaid,
    required this.paymentMethod,
    this.referenceNo,
    required this.recordedBy,
    required this.paidAt,
  });

  factory PaymentRecord.fromMap(Map<String, dynamic> data, String docId) {
    return PaymentRecord(
      id: docId,
      obligationId: data['obligation_id'] ?? '',
      studentId: data['student_id'] ?? '',
      amountPaid: (data['amount_paid'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['payment_method'] ?? 'cash',
      referenceNo: data['reference_no'],
      recordedBy: data['recorded_by'] ?? 'Admin',
      paidAt: data['paid_at'] != null ? (data['paid_at'] as Timestamp).toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'obligation_id': obligationId,
      'student_id': studentId,
      'amount_paid': amountPaid,
      'payment_method': paymentMethod,
      'reference_no': referenceNo,
      'recorded_by': recordedBy,
      'paid_at': Timestamp.fromDate(paidAt),
    };
  }
}

/// Financial Transparency Ledger transaction (Organization Cash In vs Cash Out)
class OrgTransaction {
  final String id;
  final String title;
  final String type; // 'income' | 'expense'
  final String category; // 'contributions' | 'dues' | 'equipment' | 'food' | 'prizes' | 'other'
  final double amount;
  final DateTime date;
  final String? receiptUrl;
  final String recordedBy;

  OrgTransaction({
    required this.id,
    required this.title,
    required this.type,
    required this.category,
    required this.amount,
    required this.date,
    this.receiptUrl,
    required this.recordedBy,
  });

  factory OrgTransaction.fromMap(Map<String, dynamic> data, String docId) {
    return OrgTransaction(
      id: docId,
      title: data['title'] ?? '',
      type: data['type'] ?? 'expense',
      category: data['category'] ?? 'other',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: data['date'] != null ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      receiptUrl: data['receipt_url'],
      recordedBy: data['recorded_by'] ?? 'Treasurer',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'category': category,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'receipt_url': receiptUrl,
      'recorded_by': recordedBy,
    };
  }
}
