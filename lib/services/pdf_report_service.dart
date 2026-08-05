import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfReportService {
  static Future<Uint8List> generateFundsReport(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final pdf = pw.Document();

    // Calculate totals
    double totalIncome = 0;
    double totalExpense = 0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final amt = (data['amount'] ?? 0).toDouble();
      if (data['type'] == 'income' || data['type'] == 'contribution') {
        totalIncome += amt;
      } else if (data['type'] == 'expense') {
        totalExpense += amt;
      }
    }

    final netBalance = totalIncome - totalExpense;
    final now = DateTime.now();
    final dateFormat = DateFormat('MM/dd/yyyy hh:mm a');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Funds Ledger Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    dateFormat.format(now),
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    'Total Contributions',
                    totalIncome,
                    PdfColors.green700,
                  ),
                  _buildSummaryItem(
                    'Total Expenses',
                    totalExpense,
                    PdfColors.red700,
                  ),
                  _buildSummaryItem(
                    'Net Balance',
                    netBalance,
                    PdfColors.amber700,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 32),

            // Transactions
            pw.Text(
              'Transactions',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.SizedBox(height: 12),

            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final isIncome =
                  data['type'] == 'income' || data['type'] == 'contribution';
              final amt = (data['amount'] ?? 0).toDouble();
              final dateStr = data['date'] != null
                  ? dateFormat.format((data['date'] as Timestamp).toDate())
                  : '';
              final typeStr = (data['type'] ?? '').toString().toUpperCase();
              final desc = data['description'] ?? '';

              List<String> proofImages = [];
              if (data['proof_images_base64'] != null) {
                proofImages = List<String>.from(data['proof_images_base64']);
              } else if (data['proof_image_base64'] != null &&
                  data['proof_image_base64'].toString().isNotEmpty) {
                proofImages = [data['proof_image_base64']];
              }

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 24),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(8),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          dateStr,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          '${isIncome ? '+' : '-'}PHP ${amt.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: isIncome
                                ? PdfColors.green700
                                : PdfColors.red700,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      typeStr,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(desc, style: const pw.TextStyle(fontSize: 14)),

                    if (proofImages.isNotEmpty) ...[
                      pw.SizedBox(height: 12),
                      pw.Text(
                        'Proof Photos:',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: proofImages.map((b64) {
                          try {
                            final bytes = base64Decode(b64.split(',').last);
                            final image = pw.MemoryImage(bytes);
                            return pw.Container(
                              width: 150,
                              height: 150,
                              child: pw.ClipRect(
                                child: pw.Image(image, fit: pw.BoxFit.cover),
                              ),
                            );
                          } catch (e) {
                            return pw.SizedBox();
                          }
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryItem(
    String label,
    double amount,
    PdfColor color,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'PHP ${amount.toStringAsFixed(2)}',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
