import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/student.dart';
import '../../models/obligation.dart';
import '../../theme/app_theme.dart';
import '../../services/financial_service.dart';
import '../../widgets/shared_widgets.dart';

class StudentFinancialProfileScreen extends StatefulWidget {
  final Student student;
  final String currentUserEmail;

  const StudentFinancialProfileScreen({
    super.key,
    required this.student,
    required this.currentUserEmail,
  });

  @override
  State<StudentFinancialProfileScreen> createState() =>
      _StudentFinancialProfileScreenState();
}

class _StudentFinancialProfileScreenState extends State<StudentFinancialProfileScreen> {
  bool _isLoading = false;

  Future<void> _showPaymentModal(StudentObligation ob) async {
    final controller = TextEditingController(text: ob.remainingBalance.toStringAsFixed(2));
    String selectedMethod = 'cash';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Receive Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Obligation: ${ob.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Balance: ₱${ob.remainingBalance.toStringAsFixed(2)}', style: TextStyle(color: TraceColors.error)),
                  const SizedBox(height: 16),
                  const Text('Amount Received (₱)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixText: '₱ ',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Payment Method'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'gcash', child: Text('GCash')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedMethod = val);
                      }
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: TraceColors.navyBlue),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      final amount = double.tryParse(controller.text) ?? 0.0;
      if (amount <= 0) return;
      if (amount > ob.remainingBalance) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Amount cannot exceed remaining balance')),
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        await FinancialService.recordPayment(
          obligationId: ob.id,
          studentId: widget.student.studentId,
          amountPaid: amount,
          paymentMethod: selectedMethod,
          recordedBy: widget.currentUserEmail,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment recorded successfully', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: TraceColors.error),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: AppBar(
        title: Text(
          'Student Profile',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: TraceColors.white,
          ),
        ),
        backgroundColor: TraceColors.navyBlue,
        iconTheme: const IconThemeData(color: TraceColors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildFinancialSummary(),
                        const SizedBox(height: 32),
                        Text(
                          'Obligations',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: TraceColors.navyBlue,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
                _buildObligationsList(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                    child: Text(
                      'Transaction History',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: TraceColors.navyBlue,
                      ),
                    ),
                  ),
                ),
                _buildTransactionHistory(),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return TraceCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [TraceColors.royalBlue, TraceColors.midBlue],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.student.name.isNotEmpty ? widget.student.name[0] : '?',
                style: GoogleFonts.inter(
                  color: TraceColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.student.name,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: TraceColors.navyBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.student.studentId} • ${widget.student.course} • ${widget.student.yearLevel}',
                  style: GoogleFonts.inter(color: TraceColors.medGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('student_obligations')
          .where('student_id', isEqualTo: widget.student.studentId)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        
        double totalOwed = 0;
        double totalPaid = 0;
        
        for (var doc in snap.data!.docs) {
          final ob = StudentObligation.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          totalOwed += ob.amount;
          totalPaid += ob.amountPaid;
        }
        
        final balance = totalOwed - totalPaid;

        return Row(
          children: [
            Expanded(child: _buildSummaryBox('Total Owed', totalOwed, TraceColors.navyBlue)),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryBox('Total Paid', totalPaid, Colors.green)),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryBox('Balance', balance, balance > 0 ? TraceColors.error : TraceColors.medGrey)),
          ],
        );
      },
    );
  }

  Widget _buildSummaryBox(String label, double amount, Color color) {
    return TraceCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: TraceColors.medGrey)),
          const SizedBox(height: 4),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObligationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('student_obligations')
          .where('student_id', isEqualTo: widget.student.studentId)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('No obligations found.', style: GoogleFonts.inter(color: TraceColors.medGrey)),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final ob = StudentObligation.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TraceCard(
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      onTap: ob.isFullyPaid ? null : () => _showPaymentModal(ob),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: ob.isFullyPaid ? Colors.green.withValues(alpha: 0.1) : TraceColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                ob.isFullyPaid ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                                color: ob.isFullyPaid ? Colors.green : TraceColors.error,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ob.title,
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Total: ₱${ob.amount.toStringAsFixed(2)} | Paid: ₱${ob.amountPaid.toStringAsFixed(2)}',
                                    style: GoogleFonts.inter(color: TraceColors.medGrey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            if (!ob.isFullyPaid)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TraceColors.navyBlue,
                                  minimumSize: const Size(60, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                onPressed: () => _showPaymentModal(ob),
                                child: const Text('Pay', style: TextStyle(color: TraceColors.white)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payment_records')
          .where('student_id', isEqualTo: widget.student.studentId)
          .orderBy('paid_at', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('No payment history found.', style: GoogleFonts.inter(color: TraceColors.medGrey)),
            ),
          );
        }

        final dateFormat = DateFormat('MMM d, yyyy • hh:mm a');

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final amount = (data['amount_paid'] as num?)?.toDouble() ?? 0.0;
                final date = (data['paid_at'] as Timestamp).toDate();
                final method = (data['payment_method'] as String?)?.toUpperCase() ?? 'UNKNOWN';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long, color: Colors.green, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paid ₱${amount.toStringAsFixed(2)} via $method',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              dateFormat.format(date),
                              style: GoogleFonts.inter(color: TraceColors.medGrey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }
}
