import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../../services/student_service.dart';
import '../../services/student_session_service.dart';
import '../../widgets/terms_bottom_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WebRegistrationScreen extends ConsumerStatefulWidget {
  const WebRegistrationScreen({super.key});

  @override
  ConsumerState<WebRegistrationScreen> createState() =>
      _WebRegistrationScreenState();
}

class _WebRegistrationScreenState extends ConsumerState<WebRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  Uint8List? _avatarBytes;
  final ImagePicker _picker = ImagePicker();

  final List<String> _programs = ['BSIT'];
  String? _selectedProgram = 'BSIT';

  final List<String> _yearLevels = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
  ];
  String? _selectedYear;

  bool _isSplashVisible = true;
  bool _isSplashRendered = true;

  bool _hasReadTerms = false;
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _isSplashVisible = false);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isSplashRendered = false);
      });
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _showImagePickerModal() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Upload Photo',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: TraceColors.navyBlue,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: TraceColors.gold,
              ),
              title: Text(
                'Take a photo',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: TraceColors.gold,
              ),
              title: Text(
                'Upload from album',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 50,
      maxWidth: 256,
      maxHeight: 256,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _avatarBytes = bytes;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_avatarBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please upload a student profile picture/avatar to register.',
          ),
        ),
      );
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must read and accept the Privacy Policy and Terms & Conditions to register.',
          ),
        ),
      );
      return;
    }

    if (_avatarBytes != null && _avatarBytes!.length > 700000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The selected image is too large. Please select a smaller photo (under 700KB).',
          ),
          backgroundColor: TraceColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? avatarUrl;
      if (_avatarBytes != null) {
        // Bypass Firebase Storage completely by using a Base64 string!
        // The image is heavily compressed (max 256x256, quality 50) so it easily fits within Firestore's 1MB document limit.
        final base64String = base64Encode(_avatarBytes!);
        avatarUrl = 'data:image/jpeg;base64,$base64String';
      }

      final docId = await StudentService.registerStudent(
        studentId: _idController.text.trim(),
        name: _nameController.text.trim(),
        course: _selectedProgram ?? '',
        yearLevel: _selectedYear ?? '',
        email: _emailController.text.trim(),
        avatarUrl: avatarUrl,
      );

      if (docId == null) {
        throw Exception('Student ID is already registered.');
      }

      if (mounted) {
        await ref
            .read(studentSessionProvider.notifier)
            .login(_idController.text.trim());
        if (!mounted) return;
        context.push('/student/id/${_idController.text.trim()}');
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.startsWith('Exception: ')) {
          errorMsg = errorMsg.substring(11);
        } else if (errorMsg.contains('FirebaseException')) {
          errorMsg = 'A network or server error occurred. Please try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: TraceColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSplashScreen() {
    return Container(
      color: TraceColors.navyBlue,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TraceColors.gold.withValues(alpha: 0.15),
                border: Border.all(color: TraceColors.gold, width: 2),
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                color: TraceColors.gold,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Registration',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: TraceColors.white,
              ),
            ),
            const SizedBox(height: 12),
            const CircularProgressIndicator(color: TraceColors.gold),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: TraceColors.offWhite,
            appBar: TraceAppBar(
              title: 'Registration',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),

              // Removing actions since we only need the back button
            ),
            body: _buildForm(isWide),
          ),
          if (_isSplashRendered)
            AnimatedOpacity(
              opacity: _isSplashVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: _buildSplashScreen(),
            ),
        ],
      ),
    );
  }

  Widget _buildForm(bool isWide) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              // Form card
              TraceCard(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _showImagePickerModal,
                          child: Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: TraceColors.lightGrey.withValues(
                                    alpha: 0.3,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: TraceColors.gold,
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: _avatarBytes != null
                                      ? Image.memory(
                                          _avatarBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(
                                          Icons.person_add_alt_1_rounded,
                                          size: 50,
                                          color: TraceColors.navyBlue,
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: TraceColors.navyBlue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Upload Student Photo (Required)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: TraceColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _sectionLabel('Student Information'),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _idController,
                        decoration: const InputDecoration(
                          labelText: 'Student ID',
                          prefixIcon: Icon(Icons.badge_outlined),
                          hintText: 'e.g. 2023-6024',
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Student ID is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                          hintText: 'Last Name, First Name M.I.',
                        ),
                        validator: (v) => v == null || v.isEmpty
                            ? 'Full name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                          hintText: 'student@university.edu.ph',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedProgram,
                        decoration: const InputDecoration(
                          labelText: 'Program / Course',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        items: _programs
                            .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedProgram = v),
                        validator: (v) =>
                            v == null ? 'Program is required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Year Level',
                          prefixIcon: Icon(Icons.grade_outlined),
                        ),
                        items: _yearLevels
                            .map(
                              (y) => DropdownMenuItem(value: y, child: Text(y)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedYear = v),
                        validator: (v) =>
                            v == null ? 'Year level is required' : null,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: _acceptedTerms,
                            activeColor: TraceColors.gold,
                            onChanged: _hasReadTerms
                                ? (val) {
                                    setState(
                                      () => _acceptedTerms = val ?? false,
                                    );
                                  }
                                : null,
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.white,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(24),
                                    ),
                                  ),
                                  builder: (ctx) => TermsBottomSheet(
                                    onScrolledToBottom: () {
                                      if (mounted && !_hasReadTerms) {
                                        setState(() => _hasReadTerms = true);
                                      }
                                    },
                                  ),
                                );
                              },
                              child: Text.rich(
                                TextSpan(
                                  text: 'I agree to the ',
                                  children: [
                                    TextSpan(
                                      text:
                                          'Privacy Policy and Terms & Conditions',
                                      style: GoogleFonts.inter(
                                        color: TraceColors.navyBlue,
                                        decoration: TextDecoration.underline,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                style: GoogleFonts.inter(
                                  color: _hasReadTerms
                                      ? TraceColors.navyBlue
                                      : TraceColors.medGrey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GoldButton(
                        label: 'Generate QR Code',
                        icon: Icons.qr_code_rounded,
                        isLoading: _isLoading,
                        fullWidth: true,
                        onPressed: _register,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/student-login'),
                          child: Text(
                            "Already have an account? Login here",
                            style: GoogleFonts.inter(
                              color: TraceColors.navyBlue,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: TraceColors.gold),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: TraceColors.medGrey,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
