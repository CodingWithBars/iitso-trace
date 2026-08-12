import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/obligation.dart';
import '../../services/financial_service.dart';

class OrgCashflowLogsScreen extends ConsumerStatefulWidget {
  const OrgCashflowLogsScreen({super.key});

  @override
  ConsumerState<OrgCashflowLogsScreen> createState() =>
      _OrgCashflowLogsScreenState();
}

class _OrgCashflowLogsScreenState extends ConsumerState<OrgCashflowLogsScreen> {
  List<OrgTransaction> _transactions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _typeFilter = 'all'; // 'all', 'income', 'expense'
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final txs = await FinancialService.getOrgTransactions();
    if (mounted) {
      setState(() {
        _transactions = txs;
        _isLoading = false;
      });
    }
  }

  double get _totalIncome => _transactions
      .where((t) => t.type == 'income')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _totalExpenses => _transactions
      .where((t) => t.type == 'expense')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _netTreasury => _totalIncome - _totalExpenses;

  List<OrgTransaction> get _filteredTransactions {
    return _transactions.where((tx) {
      final matchesSearch = _searchQuery.isEmpty ||
          tx.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tx.category.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_typeFilter == 'income' && tx.type != 'income') return false;
      if (_typeFilter == 'expense' && tx.type != 'expense') return false;

      if (_startDate != null && tx.date.isBefore(_startDate!)) return false;
      // Add 1 day to endDate to include the entire day
      if (_endDate != null && tx.date.isAfter(_endDate!.add(const Duration(days: 1)))) return false;

      return true;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: TraceColors.navyBlue,
              onPrimary: Colors.white,
              onSurface: TraceColors.navyBlue,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: AppBar(
        title: Text(
          'Org Treasury Cashflow Logs',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: TraceColors.navyBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Logs',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TraceColors.navyBlue),
            )
          : Column(
              children: [
                // Top Summary Header Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: TraceColors.navyBlue,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _headerStat('Net Treasury', currency.format(_netTreasury), Colors.white),
                      Container(width: 1, height: 30, color: Colors.white24),
                      _headerStat('Collections (In)', currency.format(_totalIncome), TraceColors.success),
                      Container(width: 1, height: 30, color: Colors.white24),
                      _headerStat('Expenses (Out)', currency.format(_totalExpenses), TraceColors.gold),
                    ],
                  ),
                ),

                // Search & Filter Header
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search transaction description or category...',
                          prefixIcon: const Icon(Icons.search, color: TraceColors.medGrey),
                          filled: true,
                          fillColor: TraceColors.offWhite,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      ),
                      const SizedBox(height: 12),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _filterChip('All Logs', 'all'),
                            const SizedBox(width: 8),
                            _filterChip('Income', 'income'),
                            const SizedBox(width: 8),
                            _filterChip('Expenses', 'expense'),
                            const SizedBox(width: 8),
                            Container(width: 1, height: 24, color: TraceColors.lightGrey),
                            const SizedBox(width: 8),
                            ActionChip(
                              label: Text(
                                _startDate != null && _endDate != null
                                    ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}'
                                    : 'Date Range',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: TraceColors.navyBlue,
                                ),
                              ),
                              avatar: const Icon(Icons.date_range_rounded, size: 16, color: TraceColors.navyBlue),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: TraceColors.lightGrey.withValues(alpha: 0.5)),
                              onPressed: _pickDateRange,
                            ),
                            if (_startDate != null) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: TraceColors.error),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _clearDateRange,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _filteredTransactions.isEmpty
                      ? Center(
                          child: Text(
                            'No cashflow log records found matching your filters.',
                            style: GoogleFonts.inter(color: TraceColors.medGrey, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final tx = _filteredTransactions[index];
                            return _buildTransactionCard(tx, currency);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _headerStat(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _typeFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : TraceColors.navyBlue,
        ),
      ),
      selected: isSelected,
      selectedColor: TraceColors.navyBlue,
      backgroundColor: TraceColors.lightGrey.withValues(alpha: 0.25),
      onSelected: (selected) {
        if (selected) {
          setState(() => _typeFilter = value);
        }
      },
    );
  }

  Widget _buildTransactionCard(OrgTransaction tx, NumberFormat currency) {
    final isIncome = tx.type == 'income';
    final color = isIncome ? TraceColors.success : TraceColors.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: TraceColors.lightGrey.withValues(alpha: 0.5)),
      ),
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          tx.title,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: TraceColors.navyBlue,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('MMM dd, yyyy • hh:mm a').format(tx.date)}\nCategory: ${tx.category} • Recorded by: ${tx.recordedBy}',
              style: GoogleFonts.inter(fontSize: 11, color: TraceColors.medGrey),
            ),
            if (tx.receiptUrl != null && tx.receiptUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => Dialog(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Receipt/Proof', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                                ],
                              ),
                            ),
                            InteractiveViewer(
                              child: Image.network(tx.receiptUrl!, fit: BoxFit.contain, height: 400),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.attachment_rounded, size: 14, color: TraceColors.royalBlue),
                      const SizedBox(width: 4),
                      Text('View Receipt', style: GoogleFonts.inter(fontSize: 12, color: TraceColors.royalBlue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}${currency.format(tx.amount)}',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
      ),
    );
  }
}
