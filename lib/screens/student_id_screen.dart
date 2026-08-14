import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/student_service.dart';
import '../services/student_session_service.dart';
import '../models/student.dart';

class StudentIdScreen extends ConsumerStatefulWidget {
  final String studentId;
  const StudentIdScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentIdScreen> createState() => _StudentIdScreenState();
}

class _StudentIdScreenState extends ConsumerState<StudentIdScreen> {
  Student? _student;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    final student = await StudentService.getStudentByStudentId(
      widget.studentId,
    );
    if (mounted) {
      setState(() {
        _student = student;
        _isLoading = false;
      });
    }
  }

  void _openEditProfile() {
    if (_student == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        student: _student!,
        onSaved: (updated) => setState(() => _student = updated),
      ),
    );
  }

  void _logout() {
    ref.read(studentSessionProvider.notifier).logout();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: TraceColors.offWhite,
        body: Center(
          child: CircularProgressIndicator(color: TraceColors.navyBlue),
        ),
      );
    }
    if (_student == null) {
      return Scaffold(
        backgroundColor: TraceColors.offWhite,
        appBar: TraceAppBar(
          title: 'My ID',
          actions: [
            IconButton(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.home_outlined, color: TraceColors.gold),
            ),
          ],
        ),
        body: Center(
          child: Text(
            'Student not found.',
            style: GoogleFonts.inter(fontSize: 18, color: TraceColors.error),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/');
      },
      child: Scaffold(
        backgroundColor: TraceColors.offWhite,
        appBar: TraceAppBar(
          title: 'My ID',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          actions: [
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded, color: TraceColors.gold),
              tooltip: 'Logout',
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildIdCard()),
                          _buildNoteWidget(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdCard() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: TraceColors.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: TraceColors.navyBlue.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: TraceColors.gold, width: 3),
                      color: TraceColors.offWhite,
                    ),
                    child: ClipOval(
                      child: _buildAvatarWidget(_student!.avatarUrl),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _student!.name.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: TraceColors.navyBlue,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${_student!.course} - ${_student!.yearLevel}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: TraceColors.medGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: TraceColors.lightGrey),
              const Spacer(flex: 1),
              Expanded(
                flex: 4,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(
                      maxWidth: 288,
                      maxHeight: 288,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: TraceColors.lightGrey.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: QrImageView(
                        data: _student!.qrHash,
                        version: QrVersions.auto,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: TraceColors.navyBlue,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.circle,
                          color: TraceColors.navyBlue,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(flex: 1),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: TraceColors.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'ID: ${_student!.studentId}',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: TraceColors.navyBlue,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: TraceColors.lightGrey),
              const SizedBox(height: 16),
              GoldButton(
                label: 'View Attendance Summary',
                icon: Icons.analytics_outlined,
                fullWidth: true,
                onPressed: () =>
                    context.push('/student/summary/${_student!.studentId}'),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            icon: const Icon(Icons.edit_rounded, color: TraceColors.medGrey),
            tooltip: 'Edit Profile',
            onPressed: _openEditProfile,
          ),
        ),
      ],
    );
  }

  Widget _buildNoteWidget() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TraceColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TraceColors.gold.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: TraceColors.gold, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Note: After Scan Check your Attendance Summary Button, tap the On Going/Current Event to see if time in/time out is recorded.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: TraceColors.navyBlue,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWidget(String url) {
    if (url.isEmpty) {
      return const Icon(Icons.person, size: 54, color: TraceColors.lightGrey);
    }
    if (url.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(url.split(',').last),
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: TraceColors.gold,
          ),
        );
      },
      errorBuilder: (_, _, _) =>
          const Icon(Icons.person, size: 54, color: TraceColors.lightGrey),
    );
  }
}

// ===========================================================================
// Edit Profile Bottom Sheet
// ===========================================================================
class _EditProfileSheet extends StatefulWidget {
  final Student student;
  final void Function(Student) onSaved;
  const _EditProfileSheet({required this.student, required this.onSaved});
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late TextEditingController _nameCtrl;
  Uint8List? _pickedBytes;
  bool _isSaving = false;
  String? _generalError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.student.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _pickedBytes = bytes);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _generalError = 'Name cannot be empty.');
      return;
    }
    setState(() {
      _isSaving = true;
      _generalError = null;
    });
    try {
      String? newAvatarUrl;
      if (_pickedBytes != null) {
        // Upload to Firebase Storage; service handles fallback
        newAvatarUrl = await StudentService.uploadAvatar(
          _pickedBytes!,
          widget.student.studentId,
        );
      }
      await StudentService.updateStudentProfile(
        docId: widget.student.id,
        name: name,
        avatarUrl: newAvatarUrl,
      );
      final updated = Student(
        id: widget.student.id,
        studentId: widget.student.studentId, // ID is immutable from here
        name: name,
        course: widget.student.course,
        yearLevel: widget.student.yearLevel,
        qrHash: widget.student.qrHash,
        email: widget.student.email,
        avatarUrl: newAvatarUrl ?? widget.student.avatarUrl,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: TraceColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _generalError = 'Failed to save: $e';
        _isSaving = false;
      });
    }
  }

  Widget _avatarPreview() {
    if (_pickedBytes != null) {
      return Image.memory(_pickedBytes!, fit: BoxFit.cover);
    }
    final url = widget.student.avatarUrl;
    if (url.isEmpty) {
      return const Icon(Icons.person, size: 40, color: TraceColors.lightGrey);
    }
    if (url.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(url.split(',').last),
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.person, size: 40, color: TraceColors.lightGrey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: TraceColors.lightGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Edit Profile',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: TraceColors.navyBlue,
            ),
          ),
          const SizedBox(height: 24),

          // Avatar picker
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: TraceColors.gold, width: 3),
                      color: TraceColors.offWhite,
                    ),
                    child: ClipOval(child: _avatarPreview()),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        color: TraceColors.gold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: TraceColors.navyBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Full Name',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: TraceColors.medGrey,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              hintText: 'Enter full name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: TraceColors.navyBlue,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: GoogleFonts.inter(fontSize: 15, color: TraceColors.navyBlue),
          ),
          const SizedBox(height: 16),

          // Student ID is locked — displayed read-only
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: TraceColors.offWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TraceColors.lightGrey),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.badge_outlined,
                  color: TraceColors.medGrey,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student ID',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: TraceColors.medGrey,
                        ),
                      ),
                      Text(
                        widget.student.studentId,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: TraceColors.navyBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.lock_rounded,
                  color: TraceColors.medGrey,
                  size: 16,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'To change your Student ID, submit an ID Claim via the Org admin.',
            style: GoogleFonts.inter(fontSize: 11, color: TraceColors.medGrey),
          ),

          if (_generalError != null) ...[
            const SizedBox(height: 8),
            Text(
              _generalError!,
              style: GoogleFonts.inter(fontSize: 13, color: TraceColors.error),
            ),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: TraceColors.navyBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Save Changes',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
