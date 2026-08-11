import 'dart:convert';

/// Represents encoded single-use payment payload string in Payment QR Codes
class PaymentQRPayload {
  final String studentId;
  final String studentName;
  final String course;
  final String yearLevel;
  final String obligationId;
  final String title;
  final double amountToPay;
  final double originalAmount;
  final bool isPartial;
  final int timestamp;

  PaymentQRPayload({
    required this.studentId,
    required this.studentName,
    required this.course,
    required this.yearLevel,
    required this.obligationId,
    required this.title,
    required this.amountToPay,
    required this.originalAmount,
    required this.isPartial,
    required this.timestamp,
  });

  /// Encodes payload object into JSON string format for QrImageView
  String toQrData() {
    final map = {
      'type': 'TRACE_PAYMENT_QR',
      'student_id': studentId,
      'student_name': studentName,
      'course': course,
      'year_level': yearLevel,
      'obligation_id': obligationId,
      'title': title,
      'amount_to_pay': amountToPay,
      'original_amount': originalAmount,
      'is_partial': isPartial,
      'timestamp': timestamp,
    };
    return jsonEncode(map);
  }

  /// Parses scanned QR string back into PaymentQRPayload object, or returns null if invalid
  static PaymentQRPayload? fromQrData(String rawString) {
    try {
      final data = jsonDecode(rawString) as Map<String, dynamic>;
      if (data['type'] != 'TRACE_PAYMENT_QR') return null;

      return PaymentQRPayload(
        studentId: data['student_id'] ?? '',
        studentName: data['student_name'] ?? '',
        course: data['course'] ?? '',
        yearLevel: data['year_level'] ?? '',
        obligationId: data['obligation_id'] ?? '',
        title: data['title'] ?? '',
        amountToPay: (data['amount_to_pay'] as num?)?.toDouble() ?? 0.0,
        originalAmount: (data['original_amount'] as num?)?.toDouble() ?? 0.0,
        isPartial: data['is_partial'] ?? false,
        timestamp: data['timestamp'] ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
