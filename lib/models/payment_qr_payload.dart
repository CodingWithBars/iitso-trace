import 'dart:convert';
import 'package:crypto/crypto.dart';

// TODO: Move this secret to Firebase Remote Config or a Cloud Function
// for production. This client-side secret still greatly raises the bar
// vs plain unsigned JSON — a forger would need to reverse-engineer the app.
const _kHmacSecret = 'trace_iitso_qr_2025_secret_key';

/// Represents encoded single-use payment payload string in Payment QR Codes.
/// Uses HMAC-SHA256 to prevent forgery and a 5-minute expiry window.
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
  final int timestamp; // Unix epoch millis

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

  static String _sign(Map<String, dynamic> payload) {
    // Build canonical string from deterministic fields (exclude 'sig' key itself)
    final canonical =
        '${payload['student_id']}|'
        '${payload['obligation_id']}|'
        '${payload['amount_to_pay']}|'
        '${payload['timestamp']}';
    final key = utf8.encode(_kHmacSecret);
    final bytes = utf8.encode(canonical);
    return Hmac(sha256, key).convert(bytes).toString();
  }

  /// Encodes payload into a signed JSON string for QrImageView.
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
    map['sig'] = _sign(map);
    return jsonEncode(map);
  }

  /// Parses a scanned QR string. Returns null if the JSON is malformed,
  /// the signature is invalid, or the QR is older than 5 minutes.
  static PaymentQRPayload? fromQrData(String rawString) {
    try {
      final data = jsonDecode(rawString) as Map<String, dynamic>;
      if (data['type'] != 'TRACE_PAYMENT_QR') return null;

      // --- Signature check ---
      final providedSig = data['sig']?.toString() ?? '';
      final expectedSig = _sign(data);
      if (providedSig != expectedSig) return null; // Tampered!

      // --- Expiry check: reject QRs older than 5 minutes ---
      final ts = (data['timestamp'] as num?)?.toInt() ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > const Duration(minutes: 5).inMilliseconds) return null;

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
        timestamp: ts,
      );
    } catch (_) {
      return null;
    }
  }

  /// Checks if an already-decoded QR is still valid (not expired).
  bool get isExpired {
    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    return age > const Duration(minutes: 5).inMilliseconds;
  }
}
