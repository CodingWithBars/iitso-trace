import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/student.dart';
import '../../models/obligation.dart';
import '../../services/student_service.dart';
import '../../services/financial_service.dart';
import '../../services/auth_service.dart';

class RecordManualPaymentScreen extends ConsumerStatefulWidget {
  const RecordManualPaymentScreen({super.key});

  @override
  ConsumerState<RecordManualPaymentScreen> createState() =>
      _RecordManualPaymentScreenState();
}

class _RecordManualPaymentScreenState
    extends ConsumerState<RecordManualPaymentScreen> {
  List<Student> _allStudents = [];
  List<Student> _filteredStudents = [];
  Student? _selectedStudent;

  List<StudentObligation> _studentObligations = [];
  StudentObligation? _selectedObligation;

  bool _isLoadingStudents = true;
  bool _isLoadingObligations = false;
  bool _isSaving = false;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _refNoController = TextEditingController();

  String _paymentMethod = 'cash'; // 'cash' | 'gcash' | 'bank_transfer'
  String _selectedAmountPreset = 'full'; // 'full' | 'half' | 'custom'

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _refNoController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    final list = await StudentService.getAllStudents();
    if (mounted) {
      setState(() {
        _allStudents = list;
        _filteredStudents = list;
        _isLoadingStudents = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredStudents = _allStudents;
      } else {
        _filteredStudents = _allStudents.where((s) {
          final idMatch = s.studentId.toLowerCase().contains(q);
          final nameMatch = s.name.toLowerCase().contains(q);
          final courseMatch = s.course.toLowerCase().contains(q);
          return idMatch || nameMatch || courseMatch;
        }).toList();
      }
    });
  }

  Future<void> _selectStudent(Student student) async {
    setState(() {
      _selectedStudent = student;
      _selectedObligation = null;
      _studentObligations = [];
      _isLoadingObligations = true;
      _amountController.clear();
      _selectedAmountPreset = 'full';
    });

    final obs = await FinancialService.getObligationsForStudent(student.studentId);
    final unpaidObs = obs.where((o) => !o.isFullyPaid).toList();

    if (mounted) {
      setState(() {
        _studentObligations = unpaidObs;
        _isLoadingObligations = false;
        if (unpaidObs.isNotEmpty) {
          _selectObligation(unpaidObs.first);
        }
      });
    }
  }

  void _selectObligation(StudentObligation ob) {
    setState(() {
      _selectedObligation = ob;
      _selectedAmountPreset = 'full';
      _amountController.text = ob.remainingBalance.toStringAsFixed(2);
    });
  }

  void _applyAmountPreset(String preset) {
    if (_selectedObligation == null) return;
    setState(() {
      _selectedAmountPreset = preset;
      if (preset == 'full') {
        _amountController.text = _selectedObligation!.remainingBalance.toStringAsFixed(2);
      } else if (preset == 'half') {
        final half = (_selectedObligation!.remainingBalance / 2);
        _amountController.text = half.toStringAsFixed(2);
      }
    });
  }

  Future<void> _savePayment() async {
    if (_selectedStudent == null) {
      _showSnackBar('Please select a student.', isError: true);
      return;
    }
    if (_selectedObligation == null) {
      _showSnackBar('Please select an obligation to pay.', isError: true);
      return;
    }

    final amt = double.tryParse(_amountController.text) ?? 0.0;
    if (amt <= 0) {
      _showSnackBar('Please enter a valid payment amount.', isError: true);
      return;
    }
    if (amt > _selectedObligation!.remainingBalance + 0.01) {
      _showSnackBar(
        'Payment amount cannot exceed remaining balance (₱${_selectedObligation!.remainingBalance.toStringAsFixed(2)}).',
        isError: true,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentUser = ref.read(authServiceProvider).currentUser;
      final adminName = currentUser?.email ?? 'Treasurer Admin';

      await FinancialService.recordPayment(
        obligationId: _selectedObligation!.id,
        studentId: _selectedStudent!.studentId,
        amountPaid: amt,
        paymentMethod: _paymentMethod,
        referenceNo: _refNoController.text.trim().isEmpty ? null : _refNoController.text.trim(),
        recordedBy: adminName,
      );

      if (!mounted) return;
      _showSnackBar('Payment of ₱${amt.toStringAsFixed(2)} recorded successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to record payment: $e', isError: true);
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? TraceColors.error : TraceColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: AppBar(
        backgroundColor: TraceColors.navyBlue,
        foregroundColor: Colors.white,
        title: Text(
          'Record Payment',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------------------------------------------------------
              // SECTION 1: STUDENT SEARCH & SELECTION
              // ---------------------------------------------------------------
              _sectionHeader(
                stepNum: '1',
                title: 'Select Student',
                subtitle: 'Search by Student ID, Name, or Program',
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Type Student ID, Name, or Program...',
                  prefixIcon: const Icon(Icons.search, color: TraceColors.navyBlue),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: TraceColors.lightGrey.withValues(alpha: 0.6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: TraceColors.navyBlue, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              if (_isLoadingStudents)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: TraceColors.navyBlue),
                  ),
                )
              else if (_filteredStudents.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'No students found matching "${_searchController.text.trim()}".',
                    style: GoogleFonts.inter(color: TraceColors.medGrey, fontSize: 13),
                  ),
                )
              else
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filteredStudents.length,
                    itemBuilder: (ctx, i) {
                      final student = _filteredStudents[i];
                      final isSelected = _selectedStudent?.id == student.id;

                      return GestureDetector(
                        onTap: () => _selectStudent(student),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 220,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected ? TraceColors.navyBlue : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? TraceColors.gold
                                  : TraceColors.lightGrey.withValues(alpha: 0.8),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: TraceColors.navyBlue.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  _buildStudentAvatar(student, isSelected),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      student.studentId,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? TraceColors.gold : TraceColors.navyBlue,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                student.name,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : TraceColors.navyBlue,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${student.course.isNotEmpty ? student.course : 'Student'} • Year ${student.yearLevel.isNotEmpty ? student.yearLevel : 'N/A'}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: isSelected ? Colors.white70 : TraceColors.medGrey,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 24),

              // ---------------------------------------------------------------
              // SECTION 2: OBLIGATION SELECTION
              // ---------------------------------------------------------------
              if (_selectedStudent != null) ...[
                _sectionHeader(
                  stepNum: '2',
                  title: 'Select Payment Obligation',
                  subtitle: 'Unpaid dues or sanctions for ${_selectedStudent!.name}',
                ),
                const SizedBox(height: 12),

                if (_isLoadingObligations)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: TraceColors.navyBlue),
                    ),
                  )
                else if (_studentObligations.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: TraceColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: TraceColors.success, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This student has no outstanding unpaid dues or sanctions!',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: TraceColors.navyBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: _studentObligations.map((ob) {
                      final isSelected = _selectedObligation?.id == ob.id;

                      return GestureDetector(
                        onTap: () => _selectObligation(ob),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? TraceColors.navyBlue
                                  : TraceColors.lightGrey.withValues(alpha: 0.7),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected ? TraceColors.navyBlue : TraceColors.medGrey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ob.title,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: TraceColors.navyBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Required: ${currency.format(ob.amount)} | Paid: ${currency.format(ob.amountPaid)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: TraceColors.medGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currency.format(ob.remainingBalance),
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: TraceColors.error,
                                    ),
                                  ),
                                  Text(
                                    'UNPAID',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: TraceColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 24),
              ],

              // ---------------------------------------------------------------
              // SECTION 3: PAYMENT DETAILS & METHOD
              // ---------------------------------------------------------------
              if (_selectedObligation != null) ...[
                _sectionHeader(
                  stepNum: '3',
                  title: 'Payment Amount & Method',
                  subtitle: 'Select payment breakdown and confirmation',
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: TraceColors.lightGrey.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount to Pay',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: TraceColors.navyBlue,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Quick Amount Chips
                      Row(
                        children: [
                          Expanded(
                            child: _amountPresetChip(
                              label: 'Full Balance',
                              subLabel: currency.format(_selectedObligation!.remainingBalance),
                              presetKey: 'full',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _amountPresetChip(
                              label: '50% Partial',
                              subLabel: currency.format(_selectedObligation!.remainingBalance / 2),
                              presetKey: 'half',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _amountPresetChip(
                              label: 'Custom',
                              subLabel: 'Custom Amount',
                              presetKey: 'custom',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) {
                          if (_selectedAmountPreset != 'custom') {
                            setState(() => _selectedAmountPreset = 'custom');
                          }
                        },
                        decoration: InputDecoration(
                          prefixText: '₱ ',
                          prefixStyle: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: TraceColors.navyBlue,
                          ),
                          labelText: 'Payment Amount',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: TraceColors.navyBlue,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Payment Method',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: TraceColors.navyBlue,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: _paymentMethodChip(
                              label: 'Cash',
                              icon: Icons.money_rounded,
                              methodKey: 'cash',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _paymentMethodChip(
                              label: 'GCash',
                              icon: Icons.phone_android_rounded,
                              methodKey: 'gcash',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _paymentMethodChip(
                              label: 'Bank',
                              icon: Icons.account_balance_rounded,
                              methodKey: 'bank_transfer',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _refNoController,
                        decoration: InputDecoration(
                          labelText: 'Receipt / Reference # (Optional)',
                          hintText: 'e.g. OR-9921 / GCash Ref 100293',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ---------------------------------------------------------------
                // SAVE ACTION BUTTON
                // ---------------------------------------------------------------
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _savePayment,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 22),
                    label: Text(
                      _isSaving ? 'Recording Payment...' : 'Record Payment Now',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TraceColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    ),
  ),
);
}

  Widget _sectionHeader({
    required String stepNum,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: TraceColors.navyBlue,
          child: Text(
            stepNum,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: TraceColors.navyBlue,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 12, color: TraceColors.medGrey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _amountPresetChip({
    required String label,
    required String subLabel,
    required String presetKey,
  }) {
    final isSelected = _selectedAmountPreset == presetKey;

    return GestureDetector(
      onTap: () => _applyAmountPreset(presetKey),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? TraceColors.navyBlue : TraceColors.offWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? TraceColors.navyBlue : TraceColors.lightGrey,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : TraceColors.navyBlue,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subLabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: isSelected ? TraceColors.gold : TraceColors.medGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentMethodChip({
    required String label,
    required IconData icon,
    required String methodKey,
  }) {
    final isSelected = _paymentMethod == methodKey;

    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = methodKey),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? TraceColors.navyBlue : TraceColors.offWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? TraceColors.navyBlue : TraceColors.lightGrey,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? TraceColors.gold : TraceColors.navyBlue,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : TraceColors.navyBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentAvatar(Student student, bool isSelected) {
    ImageProvider? imageProvider;
    final avatarUrl = student.avatarUrl.trim();

    if (avatarUrl.isNotEmpty) {
      if (avatarUrl.startsWith('data:image')) {
        try {
          final base64Str = avatarUrl.split(',').last;
          imageProvider = MemoryImage(base64Decode(base64Str));
        } catch (_) {}
      } else if (avatarUrl.startsWith('http')) {
        imageProvider = NetworkImage(avatarUrl);
      }
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: isSelected
          ? TraceColors.gold
          : TraceColors.navyBlue.withValues(alpha: 0.1),
      backgroundImage: imageProvider,
      child: imageProvider == null
          ? Icon(
              Icons.person,
              size: 20,
              color: isSelected ? TraceColors.navyBlue : TraceColors.navyBlue,
            )
          : null,
    );
  }
}
