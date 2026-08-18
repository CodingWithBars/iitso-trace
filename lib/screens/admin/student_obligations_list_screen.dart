import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'unpaid', 'partially_paid', 'paid', 'sanction'

  int _currentLimit = 50;
  late Stream<QuerySnapshot> _obligationsStream;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _obligationsStream = FinancialService.streamObligations(limit: _currentLimit);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      setState(() {
        _currentLimit += 50;
        _obligationsStream = FinancialService.streamObligations(limit: _currentLimit);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
            icon: const Icon(Icons.badge_rounded),
            onPressed: _showMembershipFeeDialog,
            tooltip: 'Assign Membership Fee',
          ),
        ],
      ),
      body: Column(
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
            child: StreamBuilder<QuerySnapshot>(
              stream: _obligationsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && _currentLimit == 50) {
                  return const Center(child: CircularProgressIndicator(color: TraceColors.navyBlue));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No obligation records found.',
                      style: GoogleFonts.inter(color: TraceColors.medGrey, fontSize: 14),
                    ),
                  );
                }

                final allDocs = snapshot.data!.docs;
                final obligations = allDocs.map((doc) => StudentObligation.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

                final filteredObligations = obligations.where((item) {
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

                if (filteredObligations.isEmpty) {
                  return Center(
                    child: Text(
                      'No records match your search.',
                      style: GoogleFonts.inter(color: TraceColors.medGrey, fontSize: 14),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  itemCount: filteredObligations.length + (filteredObligations.length >= _currentLimit ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == filteredObligations.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator(color: TraceColors.navyBlue)),
                      );
                    }

                    final item = filteredObligations[index];
                    return _buildCompactCard(item, currency);
                  },
                );
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

  Widget _buildCompactCard(StudentObligation item, NumberFormat currency) {
    Color statusColor;
    if (item.isFullyPaid) {
      statusColor = TraceColors.success;
    } else if (item.status == 'partially_paid') {
      statusColor = TraceColors.gold;
    } else {
      statusColor = TraceColors.error;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: TraceColors.lightGrey.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => _showStudentDetailsBottomSheet(item.studentId, item.studentName, currency),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(
            item.type == 'sanction' ? Icons.gavel_rounded : Icons.assignment_outlined,
            color: statusColor,
            size: 18,
          ),
        ),
        title: Text(
          item.studentName,
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: TraceColors.navyBlue),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.title,
          style: GoogleFonts.inter(fontSize: 12, color: TraceColors.medGrey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              currency.format(item.amount),
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: TraceColors.navyBlue),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.status.replaceAll('_', ' ').toUpperCase(),
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentDetailsBottomSheet(String studentId, String studentName, NumberFormat currency) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StudentObligationsSheet(
        studentId: studentId,
        studentName: studentName,
        currency: currency,
      ),
    );
  }

  void _showMembershipFeeDialog() {
    final amountCtrl = TextEditingController();
    final semesterCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Assign Org Membership Fee',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: TraceColors.navyBlue),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This will create a membership fee obligation for all registered students who do not yet have this fee.',
              style: GoogleFonts.inter(fontSize: 12, color: TraceColors.medGrey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: semesterCtrl,
              decoration: const InputDecoration(
                labelText: 'Semester / Period',
                hintText: 'e.g. 1st Semester AY 2024-2025',
                prefixIcon: Icon(Icons.calendar_today_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₱)',
                hintText: 'e.g. 150.00',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TraceColors.navyBlue),
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim());
              final semester = semesterCtrl.text.trim();
              if (amount == null || amount <= 0 || semester.isEmpty) return;
              final scaffoldMsg = ScaffoldMessenger.of(context);
              final count = await FinancialService.assignMembershipFee(
                amount: amount,
                semester: semester,
                recordedBy: 'Treasurer',
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              scaffoldMsg.showSnackBar(
                SnackBar(
                  content: Text('$count membership fee record(s) assigned.'),
                  backgroundColor: TraceColors.navyBlue,
                ),
              );
            },
            child: const Text('Assign', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StudentObligationsSheet extends StatefulWidget {
  final String studentId;
  final String studentName;
  final NumberFormat currency;

  const _StudentObligationsSheet({
    required this.studentId,
    required this.studentName,
    required this.currency,
  });

  @override
  State<_StudentObligationsSheet> createState() => _StudentObligationsSheetState();
}

class _StudentObligationsSheetState extends State<_StudentObligationsSheet> {
  List<StudentObligation> _obligations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    setState(() => _isLoading = true);
    final obs = await FinancialService.getStudentObligations(widget.studentId);
    if (mounted) {
      setState(() {
        _obligations = obs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalBalance = _obligations.fold<double>(0, (acc, item) => acc + item.remainingBalance);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.studentName,
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: TraceColors.navyBlue),
                      ),
                      Text(
                        widget.studentId,
                        style: GoogleFonts.inter(fontSize: 14, color: TraceColors.medGrey),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Balance',
                      style: GoogleFonts.inter(fontSize: 12, color: TraceColors.medGrey),
                    ),
                    Text(
                      widget.currency.format(totalBalance),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: totalBalance > 0 ? TraceColors.error : TraceColors.success),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: TraceColors.navyBlue))
                : _obligations.isEmpty
                    ? Center(
                        child: Text(
                          'No obligations found.',
                          style: GoogleFonts.inter(color: TraceColors.medGrey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _obligations.length,
                        itemBuilder: (context, index) {
                          final item = _obligations[index];
                          return _buildDetailedCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedCard(StudentObligation item) {
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
        borderRadius: BorderRadius.circular(12),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: TraceColors.navyBlue,
                        ),
                      ),
                      if (item.remarks != null && item.remarks!.isNotEmpty) ...[
                        const SizedBox(height: 4),
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
                      widget.currency.format(item.amount),
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
                    'Paid: ${widget.currency.format(item.amountPaid)}',
                    style: GoogleFonts.inter(fontSize: 11, color: TraceColors.success),
                  ),
                  Text(
                    'Balance: ${widget.currency.format(item.remainingBalance)}',
                    style: GoogleFonts.inter(fontSize: 11, color: TraceColors.error),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!item.isFullyPaid && item.status != 'non-monetary')
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: TraceColors.success),
                    onPressed: () async {
                      await FinancialService.markObligationSettled(item.id);
                      _loadStudentData(); // Reload bottom sheet data
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Mark Settled', style: TextStyle(fontSize: 12)),
                  ),
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
        content: Text('Are you sure you want to delete "${item.title}"?'),
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
              _loadStudentData();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
