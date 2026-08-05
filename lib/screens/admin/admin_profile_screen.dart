import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_theme.dart';
import '../../widgets/shared_widgets.dart';
import '../../services/auth_service.dart';
import '../../services/activity_log_service.dart';

class AdminProfileScreen extends ConsumerStatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  ConsumerState<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends ConsumerState<AdminProfileScreen> {
  final _emailCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _currentPassCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscureNewPass = true;
  String? _profileBase64;
  String? _adminName;
  String? _adminRole;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;

    final doc = await FirestoreService.admins.doc(uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        _profileBase64 = data['profile_image_base64'];
        _adminName = data['name'] ?? 'Admin';
        _adminRole = data['role'] ?? 'Admin';
        _emailCtrl.text = data['email'] ?? '';
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await picked.readAsBytes();
      final b64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final uid = ref.read(authServiceProvider).currentUser!.uid;
      await FirestoreService.admins.doc(uid).update({
        'profile_image_base64': b64,
      });

      await ActivityLogService.log(
        action: 'profile_updated',
        message: 'Updated profile picture',
        entityType: 'admin',
        entityId: uid,
        actorName: _adminName ?? 'Admin',
      );

      setState(() {
        _profileBase64 = b64;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update picture: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateEmail() async {
    final newEmail = _emailCtrl.text.trim();
    if (newEmail.isEmpty) return;

    final currentPass = await _promptForCurrentPassword();
    if (currentPass == null || currentPass.isEmpty) return;

    setState(() => _isLoading = true);

    final err = await ref
        .read(authServiceProvider)
        .updateEmail(currentPass, newEmail);
    if (mounted) {
      setState(() => _isLoading = false);
      if (err != null) {
        _showError(err);
      } else {
        final uid = ref.read(authServiceProvider).currentUser!.uid;
        await ActivityLogService.log(
          action: 'profile_email_updated',
          message: 'Updated email address',
          entityType: 'admin',
          entityId: uid,
          actorName: _adminName ?? 'Admin',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification email sent. Please check your inbox before logging in again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _updatePassword() async {
    final newPass = _newPassCtrl.text.trim();
    if (newPass.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    final currentPass = await _promptForCurrentPassword();
    if (currentPass == null || currentPass.isEmpty) return;

    setState(() => _isLoading = true);

    final err = await ref
        .read(authServiceProvider)
        .updatePassword(currentPass, newPass);
    if (mounted) {
      setState(() => _isLoading = false);
      if (err != null) {
        _showError(err);
      } else {
        _newPassCtrl.clear();
        final uid = ref.read(authServiceProvider).currentUser!.uid;
        await ActivityLogService.log(
          action: 'profile_password_updated',
          message: 'Changed password',
          entityType: 'admin',
          entityId: uid,
          actorName: _adminName ?? 'Admin',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully!')),
        );
      }
    }
  }

  Future<String?> _promptForCurrentPassword() async {
    _currentPassCtrl.clear();
    bool obscureCurrentPass = true;

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Security Verification'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please enter your current password to confirm this change.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _currentPassCtrl,
                obscureText: obscureCurrentPass,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureCurrentPass
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setStateDialog(() {
                        obscureCurrentPass = !obscureCurrentPass;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _currentPassCtrl.text),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: TraceColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: TraceColors.white,
          ),
        ),
        backgroundColor: TraceColors.navyBlue,
        iconTheme: const IconThemeData(color: TraceColors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TraceColors.navyBlue),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profile Header Card
                      TraceCard(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: TraceColors.navyBlue
                                        .withValues(alpha: 0.1),
                                    backgroundImage:
                                        _profileBase64 != null &&
                                            _profileBase64!.isNotEmpty
                                        ? MemoryImage(
                                            base64Decode(
                                              _profileBase64!.split(',').last,
                                            ),
                                          )
                                        : null,
                                    child:
                                        _profileBase64 == null ||
                                            _profileBase64!.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            size: 50,
                                            color: TraceColors.navyBlue,
                                          )
                                        : null,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
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
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _adminName ?? 'Loading...',
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: TraceColors.navyBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: TraceColors.gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                (_adminRole ?? '').toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: TraceColors.darkGold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Account Details Card
                      TraceCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.email_outlined,
                                  color: TraceColors.navyBlue,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Account Details',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: TraceColors.navyBlue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _emailCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Email Address',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _updateEmail,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: TraceColors.navyBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Update'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Security Card
                      TraceCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.security_outlined,
                                  color: TraceColors.navyBlue,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Security Settings',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: TraceColors.navyBlue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _newPassCtrl,
                                    obscureText: _obscureNewPass,
                                    decoration: InputDecoration(
                                      labelText: 'New Password',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureNewPass
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscureNewPass = !_obscureNewPass;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _updatePassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: TraceColors.gold,
                                    foregroundColor: TraceColors.navyBlue,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Change',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
