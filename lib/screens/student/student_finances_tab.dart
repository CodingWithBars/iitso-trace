import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/obligation.dart';
import '../../services/financial_service.dart';

class StudentFinancesTab extends StatefulWidget {
  final String studentId;
  final int initialTabIndex;
  final bool hideInnerTabBar;

  const StudentFinancesTab({
    super.key,
    required this.studentId,
    this.initialTabIndex = 0,
    this.hideInnerTabBar = false,
  });

  @override
  State<StudentFinancesTab> createState() => _StudentFinancesTabState();
}

class _StudentFinancesTabState extends State<StudentFinancesTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<StudentObligation> _obligations = [];
  List<OrgTransaction> _orgTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _loadData();
  }

  @override
  void didUpdateWidget(StudentFinancesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex.clamp(0, 1));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final obs = await FinancialService.getObligationsForStudent(widget.studentId);
    final txs = await FinancialService.getOrgTransactions();
    if (mounted) {
      setState(() {
        _obligations = obs;
        _orgTransactions = txs;
        _isLoading = false;
      });
    }
  }

  double get _totalRequired => _obligations.fold(0.0, (sum, item) => sum + item.amount);
  double get _totalPaid => _obligations.fold(0.0, (sum, item) => sum + item.amountPaid);
  double get _remainingBalance => (_totalRequired - _totalPaid).clamp(0.0, double.infinity);

  double get _totalOrgIncome => _orgTransactions
      .where((t) => t.type == 'income')
      .fold(0.0, (sum, t) => sum + t.amount);
  double get _totalOrgExpense => _orgTransactions
      .where((t) => t.type == 'expense')
      .fold(0.0, (sum, t) => sum + t.amount);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: TraceColors.navyBlue),
        ),
      );
    }

    return Column(
      children: [
        // Tab switcher (only rendered if hideInnerTabBar is false)
        if (!widget.hideInnerTabBar) ...[
          Container(
            decoration: BoxDecoration(
              color: TraceColors.lightGrey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: TraceColors.navyBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: TraceColors.navyBlue,
              labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'My Dues & Fees'),
                Tab(text: 'Org Treasury'),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildStudentObligationsView(),
              _buildOrgLedgerView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentObligationsView() {
    final currency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return SingleChildScrollView(
      child: Column(
        children: [
          // Balance Summary Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [TraceColors.navyBlue, TraceColors.royalBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: TraceColors.navyBlue.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Outstanding Balance',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currency.format(_remainingBalance),
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: _remainingBalance > 0 ? TraceColors.gold : Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          'Total Dues',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currency.format(_totalRequired),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Container(height: 24, width: 1, color: Colors.white24),
                    Column(
                      children: [
                        Text(
                          'Total Paid',
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currency.format(_totalPaid),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: TraceColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Obligations List
          if (_obligations.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline, color: TraceColors.success, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No Obligations or Sanctions',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TraceColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You have no outstanding dues or attendance fines.',
                    style: GoogleFonts.inter(fontSize: 13, color: TraceColors.medGrey),
                  ),
                ],
              ),
            )
          else
            ..._obligations.map((item) => _buildObligationCard(item, currency)),
        ],
      ),
    );
  }

  Widget _buildObligationCard(StudentObligation item, NumberFormat currency) {
    Color statusColor;
    IconData statusIcon;

    if (item.isFullyPaid) {
      statusColor = TraceColors.success;
      statusIcon = Icons.check_circle_rounded;
    } else if (item.status == 'partially_paid') {
      statusColor = TraceColors.gold;
      statusIcon = Icons.timelapse_rounded;
    } else {
      statusColor = TraceColors.error;
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TraceColors.lightGrey.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  item.type == 'sanction'
                      ? Icons.gavel_rounded
                      : (item.type == 'membership_fee'
                          ? Icons.card_membership_rounded
                          : Icons.payments_outlined),
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: TraceColors.navyBlue,
                      ),
                    ),
                    if (item.remarks != null && item.remarks!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.remarks!,
                        style: GoogleFonts.inter(fontSize: 12, color: TraceColors.medGrey),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currency.format(item.amount),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: TraceColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          item.status.replaceAll('_', ' ').toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (item.amountPaid > 0 && !item.isFullyPaid) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (item.amountPaid / item.amount).clamp(0.0, 1.0),
                backgroundColor: TraceColors.lightGrey.withValues(alpha: 0.3),
                color: TraceColors.royalBlue,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paid: ${currency.format(item.amountPaid)}',
                  style: GoogleFonts.inter(fontSize: 11, color: TraceColors.success),
                ),
                Text(
                  'Balance: ${currency.format(item.remainingBalance)}',
                  style: GoogleFonts.inter(fontSize: 11, color: TraceColors.error),
                ),
              ],
            ),
          ],

        ],
      ),
    );
  }

  Widget _buildOrgLedgerView() {
    final currency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final netBalance = _totalOrgIncome - _totalOrgExpense;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transparency Ledger Overview Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TraceColors.lightGrey.withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: TraceColors.navyBlue.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Campus Org Treasury',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: TraceColors.navyBlue,
                      ),
                    ),
                    const Icon(Icons.account_balance_wallet_outlined, color: TraceColors.gold),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  currency.format(netBalance),
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: netBalance >= 0 ? TraceColors.navyBlue : TraceColors.error,
                  ),
                ),
                Text(
                  'Net Organization Balance',
                  style: GoogleFonts.inter(fontSize: 11, color: TraceColors.medGrey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TraceColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Funds In (Collections)',
                              style: GoogleFonts.inter(fontSize: 11, color: TraceColors.medGrey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currency.format(_totalOrgIncome),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: TraceColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TraceColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Funds Out (Expenses)',
                              style: GoogleFonts.inter(fontSize: 11, color: TraceColors.medGrey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currency.format(_totalOrgExpense),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: TraceColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Recent Cashflow Transactions',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: TraceColors.navyBlue,
            ),
          ),
          const SizedBox(height: 12),

          if (_orgTransactions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No treasury transactions logged yet.',
                  style: GoogleFonts.inter(fontSize: 13, color: TraceColors.medGrey),
                ),
              ),
            )
          else
            ..._orgTransactions.map((tx) {
              final isIncome = tx.type == 'income';
              final color = isIncome ? TraceColors.success : TraceColors.error;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TraceColors.lightGrey.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: TraceColors.navyBlue,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMM dd, yyyy').format(tx.date),
                            style: GoogleFonts.inter(fontSize: 11, color: TraceColors.medGrey),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isIncome ? '+' : '-'}${currency.format(tx.amount)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
