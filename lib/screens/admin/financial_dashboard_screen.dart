import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/obligation.dart';
import '../../models/event.dart';
import '../../services/financial_service.dart';
import '../../services/student_service.dart';
import '../../services/event_service.dart';
import '../../services/auth_service.dart';
import 'payment_scanner_modal.dart';
import 'student_obligations_list_screen.dart';
import 'org_cashflow_logs_screen.dart';

import 'record_manual_payment_screen.dart';

class FinancialDashboardScreen extends ConsumerStatefulWidget {
  const FinancialDashboardScreen({super.key});

  @override
  ConsumerState<FinancialDashboardScreen> createState() =>
      _FinancialDashboardScreenState();
}

class _FinancialDashboardScreenState
    extends ConsumerState<FinancialDashboardScreen> {
  List<StudentObligation> _obligations = [];
  List<OrgTransaction> _transactions = [];
  List<Event> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final obs = await FinancialService.getAllObligations();
    final txs = await FinancialService.getOrgTransactions();
    final evs = await EventService.getAllEvents();

    if (mounted) {
      setState(() {
        _obligations = obs;
        _transactions = txs;
        _events = evs;
        _isLoading = false;
      });
    }
  }

  double get _totalCollected => _transactions
      .where((t) => t.type == 'income')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _totalExpenses => _transactions
      .where((t) => t.type == 'expense')
      .fold(0.0, (sum, t) => sum + t.amount);

  double get _netTreasury => _totalCollected - _totalExpenses;

  double get _totalOutstanding => _obligations.fold(
    0.0,
    (sum, o) => sum + (o.amount - o.amountPaid).clamp(0.0, double.infinity),
  );

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: AppBar(
        title: Text(
          'Financials & Dues Portal',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: TraceColors.navyBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Records',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TraceColors.navyBlue),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Overview Row
                  _buildSummaryMetrics(currency),
                  const SizedBox(height: 24),

                  Text(
                    'Financial Operations & Records',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TraceColors.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Action Grid
                  _buildActionToolbar(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryMetrics(NumberFormat currency) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final cards = [
          _metricCard(
            'Net Treasury Balance',
            currency.format(_netTreasury),
            Icons.account_balance_wallet_rounded,
            TraceColors.navyBlue,
          ),
          _metricCard(
            'Total Collections',
            currency.format(_totalCollected),
            Icons.arrow_downward_rounded,
            TraceColors.success,
          ),
          _metricCard(
            'Total Expenses',
            currency.format(_totalExpenses),
            Icons.arrow_upward_rounded,
            TraceColors.error,
          ),
          _metricCard(
            'Outstanding Dues',
            currency.format(_totalOutstanding),
            Icons.warning_amber_rounded,
            TraceColors.gold,
          ),
        ];

        if (isWide) {
          return Row(
            children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: c))).toList(),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 8) / 2, child: c)).toList(),
        );
      },
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TraceColors.lightGrey.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: TraceColors.medGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 540;

        final items = [
          _actionCard(
            title: 'Scan Payment QR',
            subtitle: 'Scan student receipt QR',
            icon: Icons.qr_code_scanner_rounded,
            color: TraceColors.success,
            onTap: _showScannerModal,
          ),
          _actionCard(
            title: 'Record Cash / GCash',
            subtitle: 'Manual payment collection',
            icon: Icons.point_of_sale_rounded,
            color: TraceColors.navyBlue,
            onTap: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecordManualPaymentScreen()),
              );
              if (res == true) {
                _loadData();
              }
            },
          ),
          _actionCard(
            title: 'Student Obligations',
            subtitle: 'View all dues & sanctions',
            icon: Icons.assignment_outlined,
            color: TraceColors.royalBlue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudentObligationsListScreen()),
            ),
          ),
          _actionCard(
            title: 'Org Cashflow Logs',
            subtitle: 'View all treasury logs',
            icon: Icons.receipt_long_rounded,
            color: TraceColors.gold,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrgCashflowLogsScreen()),
            ),
          ),
          _actionCard(
            title: 'Issue Fee / Dues',
            subtitle: 'Batch dues to all students',
            icon: Icons.add_card_rounded,
            color: TraceColors.navyBlue,
            onTap: _showCreateDuesDialog,
          ),
          _actionCard(
            title: 'Auto-Sanction Fines',
            subtitle: 'Post fines for missed events',
            icon: Icons.gavel_rounded,
            color: TraceColors.error,
            onTap: _showAutoSanctionDialog,
          ),
          _actionCard(
            title: 'Log Org Expense',
            subtitle: 'Record treasury expenditure',
            icon: Icons.payments_outlined,
            color: TraceColors.royalBlue,
            onTap: _showLogExpenseDialog,
          ),
        ];

        if (isWide) {
          return Row(
            children: items
                .map((card) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: card,
                      ),
                    ))
                .toList(),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map((card) => SizedBox(
                    width: (constraints.maxWidth - 8) / 2,
                    child: card,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _actionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: TraceColors.navyBlue,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 10, color: TraceColors.medGrey),
            ),
          ],
        ),
      ),
    );
  }

  void _showScannerModal() {
    showDialog(
      context: context,
      builder: (ctx) => PaymentScannerModal(
        onPaymentProcessed: _loadData,
      ),
    );
  }



  // ---------------------------------------------------------------------------
  // Dialog Modals
  // ---------------------------------------------------------------------------



  void _showCreateDuesDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    String type = 'membership_fee';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Create Dues / Contribution', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Fee Title',
                    hintText: 'e.g. SAY 2024-2025 Membership Fee',
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'membership_fee', child: Text('Membership Fee')),
                    DropdownMenuItem(value: 'contribution', child: Text('Event Contribution')),
                    DropdownMenuItem(value: 'sanction', child: Text('Sanction / Fine')),
                  ],
                  onChanged: (val) => type = val ?? 'membership_fee',
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Amount Per Student (₱)',
                    hintText: '150.00',
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Remarks / Instructions (Optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: TraceColors.navyBlue),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                if (titleCtrl.text.isEmpty || amt <= 0) return;

                final students = await StudentService.getAllStudents();
                final count = await FinancialService.batchCreateObligation(
                  students: students,
                  title: titleCtrl.text.trim(),
                  type: type,
                  amount: amt,
                  remarks: remarksCtrl.text.trim(),
                );

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Issued fee to $count students successfully!'), backgroundColor: TraceColors.success),
                );
              },
              child: const Text('Issue Dues to All Students', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAutoSanctionDialog() {
    Event? selectedEvent;
    final fineCtrl = TextEditingController(text: '50.00');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Auto-Sanction Absent Students', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Event>(
                  initialValue: selectedEvent,
                  decoration: const InputDecoration(labelText: 'Select Completed Event'),
                  items: _events.map((e) {
                    return DropdownMenuItem(value: e, child: Text(e.eventName, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: (val) => selectedEvent = val,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fineCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fine Per Absent Student (₱)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: TraceColors.error),
              onPressed: () async {
                if (selectedEvent == null) return;
                final fine = double.tryParse(fineCtrl.text) ?? 0.0;
                if (fine <= 0) return;

                final user = ref.read(authServiceProvider).currentUser;
                final count = await FinancialService.autoGenerateSanctionsForEvent(
                  event: selectedEvent!,
                  finePerMissedEvent: fine,
                  finePerLackingHour: 0.0,
                  recordedBy: user?.email ?? 'Admin',
                );

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Issued sanctions to $count absent students!'), backgroundColor: TraceColors.success),
                );
              },
              child: const Text('Post Sanctions', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showLogExpenseDialog() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = 'equipment';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Log Org Expense', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Expense Description', hintText: 'e.g. Sound System Rental'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₱)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'equipment', child: Text('Equipment / Venue')),
                  DropdownMenuItem(value: 'food', child: Text('Food & Refreshments')),
                  DropdownMenuItem(value: 'prizes', child: Text('Prizes & Certificates')),
                  DropdownMenuItem(value: 'other', child: Text('Other Expense')),
                ],
                onChanged: (val) => category = val ?? 'other',
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: TraceColors.royalBlue),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                if (titleCtrl.text.isEmpty || amt <= 0) return;

                final user = ref.read(authServiceProvider).currentUser;
                final tx = OrgTransaction(
                  id: '',
                  title: titleCtrl.text.trim(),
                  type: 'expense',
                  category: category,
                  amount: amt,
                  date: DateTime.now(),
                  recordedBy: user?.email ?? 'Treasurer',
                );

                await FinancialService.addOrgTransaction(tx);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense logged to Treasury!'), backgroundColor: TraceColors.success),
                );
              },
              child: const Text('Save Expense', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
