import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/student_service.dart';

class ClaimIdScreen extends StatefulWidget {
  const ClaimIdScreen({super.key});

  @override
  State<ClaimIdScreen> createState() => _ClaimIdScreenState();
}

class _ClaimIdScreenState extends State<ClaimIdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  Uint8List? _proofBytes;
  String? _proofBase64;
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _idExistsError;
  bool _checkingId = false;

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkIdExists(String id) async {
    if (id.trim().isEmpty) {
      setState(() => _idExistsError = null);
      return;
    }
    setState(() {
      _checkingId = true;
      _idExistsError = null;
    });
    final student = await StudentService.getStudentByStudentId(id.trim());
    if (mounted) {
      setState(() {
        _checkingId = false;
        _idExistsError = student == null
            ? 'Student ID not found in the system. Make sure the ID is correct.'
            : null;
      });
    }
  }

  Future<void> _pickProof() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _proofBytes = bytes;
      _proofBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_idExistsError != null) return;
    setState(() => _isSubmitting = true);
    try {
      await StudentService.submitIdClaim(
        claimedStudentId: _studentIdCtrl.text.trim(),
        claimantName: _nameCtrl.text.trim(),
        claimantEmail: _emailCtrl.text.trim(),
        reason: _reasonCtrl.text.trim(),
        proofImageUrl: _proofBase64,
      );
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submitted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: TraceColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: TraceAppBar(
        title: 'Claim My Student ID',
        showBackButton: true,
        actions: [
          IconButton(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.home_outlined, color: TraceColors.gold),
          ),
        ],
      ),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TraceColors.success.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 60,
                color: TraceColors.success,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Claim Submitted!',
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: TraceColors.navyBlue,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your petition has been submitted to the administrator for review. You will be notified once a decision has been made.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: TraceColors.medGrey,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            GoldButton(
              label: 'Go to Home',
              icon: Icons.home_outlined,
              onPressed: () => context.go('/'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: TraceCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TraceColors.royalBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: TraceColors.royalBlue.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: TraceColors.royalBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Use this form if your Student ID was already registered by someone else, or the registered name is incorrect. The administrator will verify your claim.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: TraceColors.navyBlue,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _sectionLabel('Student ID to Claim'),
            _textField(
              controller: _studentIdCtrl,
              hint: 'e.g. 2024-00001',
              onChanged: _checkIdExists,
              errorText: _idExistsError,
              suffix: _checkingId
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),

            _sectionLabel('Your Full Name'),
            _textField(
              controller: _nameCtrl,
              hint: 'As it appears on your school ID',
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),

            _sectionLabel('Your Email Address'),
            _textField(
              controller: _emailCtrl,
              hint: 'your@email.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 20),

            _sectionLabel('Reason / Proof of Ownership'),
            TextFormField(
              controller: _reasonCtrl,
              maxLines: 5,
              decoration: _inputDecoration(
                'Explain why you are the rightful owner of this Student ID...',
              ),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: TraceColors.navyBlue,
              ),
              validator: (v) => (v == null || v.trim().length < 20)
                  ? 'Please provide at least 20 characters.'
                  : null,
            ),
            const SizedBox(height: 20),

            _sectionLabel('Proof Image (Optional)'),
            Text(
              'Upload a photo of your school ID or any document proving your identity.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: TraceColors.medGrey,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickProof,
              child: Container(
                width: double.infinity,
                height: _proofBytes != null ? 180 : 100,
                decoration: BoxDecoration(
                  color: TraceColors.lightGrey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TraceColors.lightGrey, width: 1.5),
                ),
                child: _proofBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(_proofBytes!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.upload_file_rounded,
                            size: 36,
                            color: TraceColors.medGrey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to upload',
                            style: GoogleFonts.inter(
                              color: TraceColors.medGrey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 36),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TraceColors.navyBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Submit Claim Petition',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  ),
),
);
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: TraceColors.navyBlue,
      ),
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(color: TraceColors.medGrey, fontSize: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: TraceColors.navyBlue, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? errorText,
    Widget? suffix,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          validator: validator,
          decoration: _inputDecoration(hint).copyWith(
            errorText: errorText,
            suffixIcon: suffix != null
                ? Padding(padding: const EdgeInsets.all(12), child: suffix)
                : null,
          ),
          style: GoogleFonts.inter(fontSize: 15, color: TraceColors.navyBlue),
        ),
      ],
    );
  }
}
