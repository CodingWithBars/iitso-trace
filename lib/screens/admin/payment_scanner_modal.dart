import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../models/payment_qr_payload.dart';
import '../../services/financial_service.dart';
import '../../services/auth_service.dart';

class PaymentScannerModal extends ConsumerStatefulWidget {
  final VoidCallback onPaymentProcessed;

  const PaymentScannerModal({super.key, required this.onPaymentProcessed});

  @override
  ConsumerState<PaymentScannerModal> createState() =>
      _PaymentScannerModalState();
}

class _PaymentScannerModalState extends ConsumerState<PaymentScannerModal> {
  final MobileScannerController _cameraController = MobileScannerController();
  PaymentQRPayload? _scannedPayload;
  bool _isProcessing = false;
  bool _torchOn = false;

  final TextEditingController _orRefCtrl = TextEditingController();
  String _paymentMethod = 'cash';

  @override
  void dispose() {
    _cameraController.dispose();
    _orRefCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _scannedPayload != null) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.contains('TRACE_PAYMENT_QR')) {
        final payload = PaymentQRPayload.fromQrData(raw);
        if (payload != null) {
          setState(() {
            _scannedPayload = payload;
          });
          break;
        }
      }
    }
  }

  Future<void> _processPayment() async {
    if (_scannedPayload == null || _isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final user = ref.read(authServiceProvider).currentUser;
      final adminEmail = user?.email ?? 'Treasurer Admin';

      await FinancialService.recordPayment(
        obligationId: _scannedPayload!.obligationId,
        studentId: _scannedPayload!.studentId,
        amountPaid: _scannedPayload!.amountToPay,
        paymentMethod: _paymentMethod,
        referenceNo: _orRefCtrl.text.trim().isNotEmpty
            ? _orRefCtrl.text.trim()
            : null,
        recordedBy: adminEmail,
      );

      if (mounted) {
        widget.onPaymentProcessed();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment of ₱${_scannedPayload!.amountToPay.toStringAsFixed(2)} for ${_scannedPayload!.studentName} accepted successfully!',
            ),
            backgroundColor: TraceColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: TraceColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Scaffold(
            backgroundColor: TraceColors.offWhite,
            appBar: AppBar(
              title: Text(
                'Scan Student Payment QR',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              backgroundColor: TraceColors.navyBlue,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: Icon(
                    _torchOn ? Icons.flash_on : Icons.flash_off,
                    color: TraceColors.gold,
                  ),
                  onPressed: () {
                    _cameraController.toggleTorch();
                    setState(() => _torchOn = !_torchOn);
                  },
                ),
              ],
            ),
            body: _scannedPayload == null
                ? _buildScannerView()
                : _buildConfirmationView(currency),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    return Stack(
      children: [
        MobileScanner(
          controller: _cameraController,
          onDetect: _onDetect,
        ),
        // Reticle Overlay
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TraceColors.gold, width: 3),
              color: Colors.black.withValues(alpha: 0.1),
            ),
          ),
        ),
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Point camera at the student\'s Payment Receipt QR code',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationView(NumberFormat currency) {
    final payload = _scannedPayload!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TraceColors.navyBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TraceColors.gold.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: TraceColors.gold,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payload.studentName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'ID: ${payload.studentId} • ${payload.course}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Obligation Details Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: TraceColors.lightGrey.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        payload.title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: TraceColors.navyBlue,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (payload.isPartial
                                ? TraceColors.gold
                                : TraceColors.success)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        payload.isPartial ? 'PARTIAL PAYMENT' : 'FULL PAYMENT',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: payload.isPartial
                              ? TraceColors.navyBlue
                              : TraceColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Amount to Collect:',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: TraceColors.medGrey,
                      ),
                    ),
                    Text(
                      currency.format(payload.amountToPay),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: TraceColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Payment Input Controls
          Text(
            'Payment Collection Details',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: TraceColors.navyBlue,
            ),
          ),
          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Payment Method',
              prefixIcon: Icon(Icons.payment),
            ),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'gcash', child: Text('GCash')),
              DropdownMenuItem(
                value: 'bank_transfer',
                child: Text('Bank Transfer'),
              ),
            ],
            onChanged: (val) =>
                setState(() => _paymentMethod = val ?? 'cash'),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _orRefCtrl,
            decoration: const InputDecoration(
              labelText: 'OR / Reference Number (Optional)',
              hintText: 'e.g. OR-1082 / GCash Ref 88201',
              prefixIcon: Icon(Icons.receipt_outlined),
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _scannedPayload = null),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Scan Again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processPayment,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_rounded),
                  label: const Text('Accept Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TraceColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
