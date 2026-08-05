import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class TransparencySection extends StatefulWidget {
  final bool isWide;

  const TransparencySection({super.key, required this.isWide});

  @override
  State<TransparencySection> createState() => _TransparencySectionState();
}

class _TransparencySectionState extends State<TransparencySection> {
  int _ledgerTab = 0;
  static const _ledgerTabs = ['All Transactions', 'Contributions', 'Expenses'];

  @override
  Widget build(BuildContext context) {
    final double hPad = widget.isWide ? 80 : 20;
    return Container(
      color: TraceColors.navyBlue,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService.db
            .collection('funds')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          final docs = snap.hasData
              ? snap.data!.docs
              : <QueryDocumentSnapshot>[];
          double income = 0, expense = 0;
          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            if (data['type'] == 'income' || data['type'] == 'contribution') {
              income += (data['amount'] ?? 0).toDouble();
            } else if (data['type'] == 'expense') {
              expense += (data['amount'] ?? 0).toDouble();
            }
          }

          // Filter by selected tab
          final filteredDocs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            if (_ledgerTab == 0) return true;
            if (_ledgerTab == 1) {
              return data['type'] == 'income' || data['type'] == 'contribution';
            }
            return data['type'] == 'expense';
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 28,
                      decoration: const BoxDecoration(
                        gradient: TraceColors.goldGradient,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Transparency Ledger',
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: TraceColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Text(
                  'Real-time public record of all IITSO finances.',
                  style: GoogleFonts.inter(
                    color: TraceColors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      child: Row(
                        children: [
                          SizedBox(
                            width: constraints.maxWidth > 500
                                ? (constraints.maxWidth - (hPad * 2) - 24) / 3
                                : 160,
                            child: _financeSummaryCard(
                              'Total Collected',
                              '₱${_formatAmount(income)}',
                              Icons.trending_up_rounded,
                              TraceColors.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: constraints.maxWidth > 500
                                ? (constraints.maxWidth - (hPad * 2) - 24) / 3
                                : 160,
                            child: _financeSummaryCard(
                              'Total Expenses',
                              '₱${_formatAmount(expense)}',
                              Icons.trending_down_rounded,
                              TraceColors.error,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: constraints.maxWidth > 500
                                ? (constraints.maxWidth - (hPad * 2) - 24) / 3
                                : 160,
                            child: _financeSummaryCard(
                              'Net Balance',
                              '₱${_formatAmount(income - expense)}',
                              Icons.account_balance_wallet_rounded,
                              TraceColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              // Filter tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Row(
                    children: List.generate(
                      _ledgerTabs.length,
                      (i) => GestureDetector(
                        onTap: () => setState(() => _ledgerTab = i),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _ledgerTab == i
                                ? TraceColors.gold
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _ledgerTab == i
                                  ? TraceColors.gold
                                  : TraceColors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            _ledgerTabs[i],
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: _ledgerTab == i
                                  ? TraceColors.navyBlue
                                  : TraceColors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Live ledger table
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: snap.connectionState == ConnectionState.waiting
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            color: TraceColors.gold,
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : filteredDocs.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: TraceColors.gold.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'No transactions recorded yet.',
                            style: GoogleFonts.inter(
                              color: TraceColors.white.withValues(alpha: 0.4),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: TraceColors.gold.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'DATE',
                                      style: GoogleFonts.inter(
                                        color: TraceColors.gold,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      'DESCRIPTION',
                                      style: GoogleFonts.inter(
                                        color: TraceColors.gold,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'AMOUNT',
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.inter(
                                        color: TraceColors.gold,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(color: Color(0x22FFD700), height: 1),
                            ...filteredDocs.asMap().entries.map((e) {
                              final data =
                                  e.value.data() as Map<String, dynamic>;
                              final isIncome =
                                  data['type'] == 'income' ||
                                  data['type'] == 'contribution';
                              final date = data['date'] != null
                                  ? _formatDateShort(
                                      (data['date'] as Timestamp).toDate(),
                                    )
                                  : '-';
                              return Column(
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () =>
                                          _showTransactionDetails(data),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                date,
                                                style: GoogleFonts.inter(
                                                  color: TraceColors.white
                                                      .withValues(alpha: 0.6),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 4,
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isIncome
                                                        ? Icons
                                                              .arrow_circle_up_rounded
                                                        : Icons
                                                              .arrow_circle_down_rounded,
                                                    size: 14,
                                                    color: isIncome
                                                        ? TraceColors.success
                                                        : TraceColors.error,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      data['description'] ?? '',
                                                      style: GoogleFonts.inter(
                                                        color:
                                                            TraceColors.white,
                                                        fontSize: 13,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                '${isIncome ? '+' : '-'}₱${_formatAmount((data['amount'] ?? 0).toDouble())}',
                                                textAlign: TextAlign.right,
                                                style: GoogleFonts.inter(
                                                  color: isIncome
                                                      ? const Color(0xFF66BB6A)
                                                      : const Color(0xFFEF5350),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (e.key < filteredDocs.length - 1)
                                    const Divider(
                                      color: Color(0x11FFD700),
                                      height: 1,
                                    ),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _financeSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: TraceColors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: TraceColors.navyBlue,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Transaction Details',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: TraceColors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _detailRow(
                  'Type',
                  (data['type'] ?? '').toString().toUpperCase(),
                ),
                const SizedBox(height: 8),
                _detailRow('Description', data['description'] ?? ''),
                const SizedBox(height: 8),
                _detailRow(
                  'Amount',
                  '₱${_formatAmount((data['amount'] ?? 0).toDouble())}',
                ),
                const SizedBox(height: 8),
                if (data['date'] != null)
                  _detailRow(
                    'Date',
                    _formatDateShort((data['date'] as Timestamp).toDate()),
                  ),
                Builder(
                  builder: (ctx) {
                    List<String> proofImages = [];
                    if (data['proof_images_base64'] != null) {
                      proofImages = List<String>.from(
                        data['proof_images_base64'],
                      );
                    } else if (data['proof_image_base64'] != null &&
                        data['proof_image_base64'].toString().isNotEmpty) {
                      proofImages = [data['proof_image_base64']];
                    }

                    if (proofImages.isEmpty) return const SizedBox();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'Proof Photo',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: TraceColors.white.withValues(alpha: 0.54),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: proofImages
                              .map(
                                (b64) => GestureDetector(
                                  onTap: () => _showFullImage(b64),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      base64Decode(
                                        b64.contains(',')
                                            ? b64.split(',').last
                                            : b64,
                                      ),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: TraceColors.white.withValues(alpha: 0.54),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: TraceColors.white,
            ),
          ),
        ),
      ],
    );
  }

  void _showFullImage(String base64Str) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(
                    base64Str.contains(',')
                        ? base64Str.split(',').last
                        : base64Str,
                  ),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateShort(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,##0.00', 'en_US').format(amount);
  }
}
