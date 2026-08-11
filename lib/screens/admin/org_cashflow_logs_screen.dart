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

      if (_typeFilter == 'income') return tx.type == 'income';
      if (_typeFilter == 'expense') return tx.type == 'expense';

      return true;
    }).toList();
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
                            _filterChip('Income (Inflow)', 'income'),
                            const SizedBox(width: 8),
                            _filterChip('Expenses (Outflow)', 'expense'),
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
        subtitle: Text(
          '${DateFormat('MMM dd, yyyy • hh:mm a').format(tx.date)}\nCategory: ${tx.category} • Recorded by: ${tx.recordedBy}',
          style: GoogleFonts.inter(fontSize: 11, color: TraceColors.medGrey),
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
