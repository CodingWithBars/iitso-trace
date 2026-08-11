import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/obligation.dart';
import '../../services/financial_service.dart';

class StudentObligationsListScreen extends ConsumerStatefulWidget {
  const StudentObligationsListScreen({super.key});

  @override
  ConsumerState<StudentObligationsListScreen> createState() =>
      _StudentObligationsListScreenState();
}

class _StudentObligationsListScreenState
    extends ConsumerState<StudentObligationsListScreen> {
  List<StudentObligation> _obligations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'unpaid', 'partially_paid', 'paid', 'sanction'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final obs = await FinancialService.getAllObligations();
    if (mounted) {
      setState(() {
        _obligations = obs;
        _isLoading = false;
      });
    }
  }

  List<StudentObligation> get _filteredObligations {
    return _obligations.where((item) {
      final matchesSearch = _searchQuery.isEmpty ||
          item.studentId.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.title.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_statusFilter == 'unpaid') return item.status == 'unpaid';
      if (_statusFilter == 'partially_paid') return item.status == 'partially_paid';
      if (_statusFilter == 'paid') return item.status == 'paid';
      if (_statusFilter == 'sanction') return item.type == 'sanction';

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
          'Student Dues & Obligations',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: TraceColors.navyBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Dues',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TraceColors.navyBlue),
            )
          : Column(
              children: [
                // Search & Filter Header Container
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search student ID, name, or fee title...',
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
                            _filterChip('All Records', 'all'),
                            const SizedBox(width: 8),
                            _filterChip('Unpaid', 'unpaid'),
                            const SizedBox(width: 8),
                            _filterChip('Partially Paid', 'partially_paid'),
                            const SizedBox(width: 8),
                            _filterChip('Fully Paid', 'paid'),
                            const SizedBox(width: 8),
                            _filterChip('Sanctions Only', 'sanction'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _filteredObligations.isEmpty
                      ? Center(
                          child: Text(
                            'No obligation records found matching your filters.',
                            style: GoogleFonts.inter(color: TraceColors.medGrey, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredObligations.length,
                          itemBuilder: (context, index) {
                            final item = _filteredObligations[index];
                            return _buildObligationCard(item, currency);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _statusFilter == value;
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
          setState(() => _statusFilter = value);
        }
      },
    );
  }

  Widget _buildObligationCard(StudentObligation item, NumberFormat currency) {
    Color statusColor;
    if (item.isFullyPaid) {
      statusColor = TraceColors.success;
    } else if (item.status == 'partially_paid') {
      statusColor = TraceColors.gold;
    } else {
      statusColor = TraceColors.error;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: TraceColors.lightGrey.withValues(alpha: 0.6)),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(
                    item.type == 'sanction'
                        ? Icons.gavel_rounded
                        : Icons.assignment_outlined,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.studentName} (${item.studentId})',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: TraceColors.navyBlue,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: TraceColors.medGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.remarks != null && item.remarks!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Remarks: ${item.remarks}',
                          style: GoogleFonts.inter(fontSize: 11, color: TraceColors.medGrey),
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
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
                      child: Text(
                        item.status.replaceAll('_', ' ').toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: TraceColors.error, size: 20),
                  onPressed: () => _confirmDelete(item),
                  tooltip: 'Delete Record',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(StudentObligation item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Obligation Record'),
        content: Text('Are you sure you want to delete "${item.title}" for ${item.studentName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TraceColors.error),
            onPressed: () async {
              await FinancialService.deleteObligation(item.id);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
