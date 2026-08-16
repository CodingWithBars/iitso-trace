import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/activity_log_service.dart';
import '../../widgets/shared_widgets.dart';
import 'package:intl/intl.dart';

class ManageAdminsScreen extends ConsumerStatefulWidget {
  const ManageAdminsScreen({super.key});

  @override
  ConsumerState<ManageAdminsScreen> createState() => _ManageAdminsScreenState();
}

class _ManageAdminsScreenState extends ConsumerState<ManageAdminsScreen> {
  static const List<DropdownMenuItem<String>> _roleDropdownItems = [
    DropdownMenuItem(value: 'superadmin', child: Text('Superadmin (President)')),
    DropdownMenuItem(value: 'admin', child: Text('Admin')),
    DropdownMenuItem(value: 'vice_president', child: Text('Vice President')),
    DropdownMenuItem(value: 'assoc_vice_president', child: Text('Assoc. Vice President')),
    DropdownMenuItem(value: 'secretary', child: Text('Secretary')),
    DropdownMenuItem(value: 'assoc_secretary', child: Text('Assoc. Secretary')),
    DropdownMenuItem(value: 'treasurer', child: Text('Treasurer')),
    DropdownMenuItem(value: 'assoc_treasurer', child: Text('Assoc. Treasurer')),
    DropdownMenuItem(value: 'auditor', child: Text('Auditor')),
    DropdownMenuItem(value: 'assoc_auditor', child: Text('Assoc. Auditor')),
    DropdownMenuItem(value: 'pio', child: Text('P.I.O.')),
    DropdownMenuItem(value: 'assoc_pio', child: Text('Assoc. P.I.O.')),
    DropdownMenuItem(value: 'pro', child: Text('P.R.O.')),
    DropdownMenuItem(value: 'assoc_pro_1', child: Text('Assoc. P.R.O. I')),
    DropdownMenuItem(value: 'assoc_pro_2', child: Text('Assoc. P.R.O. II')),
    DropdownMenuItem(value: 'scanner', child: Text('Scanner (Generic)')),
  ];

  void _showAddAdminDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool isProcessing = false;
    bool obscurePassword = true;
    String role = 'vice_president';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: TraceColors.offWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Add New Admin',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: TraceColors.navyBlue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create an account for another administrator. They will use this email and password to log in.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: TraceColors.medGrey,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Admin Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordCtrl,
                  decoration: InputDecoration(
                    labelText: 'Password (min 6 chars)',
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setModalState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: obscurePassword,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: _roleDropdownItems,
                  onChanged: (v) {
                    if (v != null) {
                      setModalState(() => role = v);
                    }
                  },
                ),
                const SizedBox(height: 32),
                if (isProcessing)
                  const Center(child: CircularProgressIndicator())
                else
                  GoldButton(
                    label: 'Create Admin Account',
                    fullWidth: true,
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          emailCtrl.text.trim().isEmpty ||
                          passwordCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill all fields'),
                          ),
                        );
                        return;
                      }
                      if (passwordCtrl.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password must be at least 6 characters',
                            ),
                          ),
                        );
                        return;
                      }
                      setModalState(() => isProcessing = true);

                      final authService = ref.read(authServiceProvider);
                      final error = await authService.createAdmin(
                        nameCtrl.text.trim(),
                        emailCtrl.text.trim(),
                        passwordCtrl.text,
                        role: role,
                      );

                      if (!ctx.mounted) return;
                      setModalState(() => isProcessing = false);

                      if (error != null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: TraceColors.error,
                          ),
                        );
                      } else {
                        ActivityLogService.log(
                          action: 'Admin Account Created',
                          message:
                              'Created new admin account for ${emailCtrl.text.trim()}',
                          actorName:
                              ref
                                  .read(authServiceProvider)
                                  .currentUser
                                  ?.email ??
                              'Admin',
                        );
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Admin created successfully!'),
                            backgroundColor: TraceColors.success,
                          ),
                        );
                        Navigator.pop(ctx);
                      }
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditAdminDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: data['name'] ?? '');
    final emailCtrl = TextEditingController(text: data['email'] ?? '');
    String role = data['role'] ?? 'vice_president';
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: TraceColors.offWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Edit Admin Details',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: TraceColors.navyBlue,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Admin Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                  keyboardType: TextInputType.emailAddress,
                  enabled: false, // Cannot change auth email easily
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: _roleDropdownItems,
                  onChanged: (v) {
                    if (v != null) {
                      setModalState(() => role = v);
                    }
                  },
                ),
                const SizedBox(height: 32),
                if (isProcessing)
                  const Center(child: CircularProgressIndicator())
                else
                  GoldButton(
                    label: 'Save Changes',
                    fullWidth: true,
                    onPressed: () async {
                      setModalState(() => isProcessing = true);
                      await doc.reference.update({
                        'name': nameCtrl.text.trim(),
                        'role': role,
                      });
                      if (!ctx.mounted) return;
                      setModalState(() => isProcessing = false);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Updated successfully'),
                          backgroundColor: TraceColors.success,
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    if (data['email']?.toString().toLowerCase() == 'iitsoofficer@dorsu.bc') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete the master admin account.'),
          backgroundColor: TraceColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Admin?'),
        content: const Text(
          'Are you sure you want to delete this admin? They will lose access to the portal immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await doc.reference.delete();

              final email = (doc.data() as Map<String, dynamic>)['email'];
              ActivityLogService.log(
                action: 'Admin Deleted',
                message: 'Revoked access for admin $email',
                actorName:
                    ref.read(authServiceProvider).currentUser?.email ?? 'Admin',
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Admin deleted successfully'),
                    backgroundColor: TraceColors.success,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: TraceColors.error),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '--';
    try {
      final dt = (ts as Timestamp).toDate();
      return DateFormat('MM/dd/yyyy hh:mm a').format(dt);
    } catch (_) {
      return '--';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentEmail = ref.watch(authServiceProvider).currentUser?.email;
    final currentRole = ref.watch(adminRoleProvider).value;

    if (currentRole != 'superadmin') {
      return Scaffold(
        backgroundColor: TraceColors.offWhite,
        appBar: TraceAppBar(title: 'Manage Admins', showBackButton: true),
        body: const Center(
          child: Text('Permission Denied. Only Superadmins can manage accounts.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: TraceAppBar(
        title: 'Manage Admins',
        showBackButton: true,
        actions: [
          IconButton(
            onPressed: _showAddAdminDialog,
            icon: const Icon(Icons.person_add, color: TraceColors.gold),
            tooltip: 'Add Admin',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Administrator Accounts',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: TraceColors.navyBlue,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirestoreService.admins
                    .orderBy('created_at', descending: true)
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('No admins found.'));
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final doc = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final isMe =
                          currentEmail != null && currentEmail == data['email'];

                      return TraceCard(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: TraceColors.navyBlue.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings,
                                color: TraceColors.navyBlue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        data['name'] ?? data['email'] ?? '--',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: TraceColors.navyBlue,
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: TraceColors.gold,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            'YOU',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: TraceColors.navyBlue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Role: ${(data['role'] ?? 'Admin').toString().toUpperCase()}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: TraceColors.medGrey,
                                    ),
                                  ),
                                  Text(
                                    'Added: ${_formatDate(data['created_at'])}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: TraceColors.medGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isMe)
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_horiz,
                                  color: TraceColors.navyBlue,
                                ),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _showEditAdminDialog(doc);
                                  } else if (val == 'delete') {
                                    _confirmDelete(doc);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.edit_outlined,
                                          color: TraceColors.navyBlue,
                                          size: 20,
                                        ),
                                        SizedBox(width: 12),
                                        Text('Edit Admin'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          color: TraceColors.error,
                                          size: 20,
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: TraceColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
