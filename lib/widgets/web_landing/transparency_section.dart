import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import 'web_landing_helpers.dart';

class TransparencySection extends StatefulWidget {
  const TransparencySection({super.key});

  @override
  State<TransparencySection> createState() => _TransparencySectionState();
}

class _TransparencySectionState extends State<TransparencySection> {
  int _ledgerTab = 0;

  static const _ledgerTabs = ['All Transactions', 'Contributions', 'Expenses'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TraceColors.navyBlue,
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final isWide = constraints.maxWidth > 700;
          final hPad = isWide ? 80.0 : 24.0;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('funds')
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              final docs = snap.data?.docs ?? [];
              double income = 0, expense = 0;
              for (final d in docs) {
                final data = d.data() as Map<String, dynamic>;
                if (data['type'] == 'income' ||
                    data['type'] == 'contribution') {
                  income += (data['amount'] ?? 0).toDouble();
                } else if (data['type'] == 'expense') {
                  expense += (data['amount'] ?? 0).toDouble();
                }
              }

              final filteredDocs = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                if (_ledgerTab == 0) return true;
                if (_ledgerTab == 1) {
                  return data['type'] == 'income' ||
                      data['type'] == 'contribution';
                }
                return data['type'] == 'expense';
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: buildSectionHeader(
                      'Transparency Ledger',
                      Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Text(
                      'Real-time public record of all IITSO finances.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Summary cards — always a horizontal row, wrap on very small screens
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: LayoutBuilder(
                      builder: (ctx2, c2) {
                        // On very narrow screens wrap to 1-col, otherwise always 3-col row
                        final cardWidth = (c2.maxWidth - 32) / 3;
                        final useRow = cardWidth > 90;
                        if (useRow) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _financeSummaryCard(
                                  'Total Collected',
                                  '₱${formatAmount(income)}',
                                  Icons.trending_up_rounded,
                                  const Color(0xFF66BB6A),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _financeSummaryCard(
                                  'Total Expenses',
                                  '₱${formatAmount(expense)}',
                                  Icons.trending_down_rounded,
                                  const Color(0xFFEF5350),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _financeSummaryCard(
                                  'Net Balance',
                                  '₱${formatAmount(income - expense)}',
                                  Icons.account_balance_wallet_rounded,
                                  TraceColors.gold,
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _financeSummaryCard(
                              'Total Collected',
                              '₱${formatAmount(income)}',
                              Icons.trending_up_rounded,
                              const Color(0xFF66BB6A),
                            ),
                            const SizedBox(height: 10),
                            _financeSummaryCard(
                              'Total Expenses',
                              '₱${formatAmount(expense)}',
                              Icons.trending_down_rounded,
                              const Color(0xFFEF5350),
                            ),
                            const SizedBox(height: 10),
                            _financeSummaryCard(
                              'Net Balance',
                              '₱${formatAmount(income - expense)}',
                              Icons.account_balance_wallet_rounded,
                              TraceColors.gold,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Ledger filter tabs
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Row(
                      children: List.generate(
                        _ledgerTabs.length,
                        (i) => GestureDetector(
                          onTap: () => setState(() => _ledgerTab = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _ledgerTab == i
                                  ? TraceColors.gold
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: _ledgerTab == i
                                    ? TraceColors.gold
                                    : Colors.white.withValues(alpha: 0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              _ledgerTabs[i],
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: _ledgerTab == i
                                    ? TraceColors.navyBlue
                                    : Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: snap.connectionState == ConnectionState.waiting
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
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
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: TraceColors.gold.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'No transactions recorded yet.',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: TraceColors.gold.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Table header — hide date column on very small screens
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      if (isWide)
                                        Expanded(
                                          flex: 2,
                                          child: _tableHeader('DATE'),
                                        ),
                                      Expanded(
                                        flex: 4,
                                        child: _tableHeader('DESCRIPTION'),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: _tableHeader(
                                          'AMOUNT',
                                          align: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(
                                  color: Color(0x22FFD700),
                                  height: 1,
                                ),
                                ...filteredDocs.asMap().entries.map((entry) {
                                  final data =
                                      entry.value.data()
                                          as Map<String, dynamic>;
                                  final isIncome =
                                      data['type'] == 'income' ||
                                      data['type'] == 'contribution';
                                  final date = data['date'] != null
                                      ? formatDateShort(
                                          (data['date'] as Timestamp).toDate(),
                                        )
                                      : '-';
                                  return Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            if (isWide)
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  date,
                                                  style: GoogleFonts.inter(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.5),
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
                                                        ? const Color(
                                                            0xFF66BB6A,
                                                          )
                                                        : const Color(
                                                            0xFFEF5350,
                                                          ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          data['description'] ??
                                                              '',
                                                          style:
                                                              GoogleFonts.inter(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13,
                                                              ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        // Show date below description on mobile
                                                        if (!isWide)
                                                          Text(
                                                            date,
                                                            style:
                                                                GoogleFonts.inter(
                                                                  color: Colors
                                                                      .white
                                                                      .withValues(
                                                                        alpha:
                                                                            0.4,
                                                                      ),
                                                                  fontSize: 11,
                                                                ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                '${isIncome ? '+' : '-'}₱${formatAmount((data['amount'] ?? 0).toDouble())}',
                                                textAlign: TextAlign.right,
                                                style: GoogleFonts.inter(
                                                  color: isIncome
                                                      ? const Color(0xFF66BB6A)
                                                      : const Color(0xFFEF5350),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: isWide ? 13 : 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (entry.key < filteredDocs.length - 1)
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
    return LayoutBuilder(
      builder: (ctx, c) {
        final compact = c.maxWidth < 140;
        return Container(
          padding: EdgeInsets.all(compact ? 12 : 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: compact ? 16 : 22),
              SizedBox(height: compact ? 6 : 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: compact ? 16 : 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: compact ? 10 : 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tableHeader(String label, {TextAlign align = TextAlign.left}) {
    return Text(
      label,
      textAlign: align,
      style: GoogleFonts.inter(
        color: TraceColors.gold,
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 1.2,
      ),
    );
  }
}
