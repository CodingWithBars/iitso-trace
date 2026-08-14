import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/activity_log_service.dart';
import '../../models/announcement.dart';
import '../../widgets/shared_widgets.dart';

class AnnouncementFormScreen extends StatefulWidget {
  final Announcement? announcement;

  const AnnouncementFormScreen({super.key, this.announcement});

  @override
  State<AnnouncementFormScreen> createState() => _AnnouncementFormScreenState();
}

class _AnnouncementFormScreenState extends State<AnnouncementFormScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  String _category = 'Upcoming';
  String _coverImageBase64 = '';
  DateTime? _scheduledDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final ann = widget.announcement;
    _titleCtrl = TextEditingController(text: ann?.title ?? '');
    _contentCtrl = TextEditingController(text: ann?.content ?? '');
    if (ann != null) {
      _category = ann.category;
      _coverImageBase64 = ann.bannerUrl;
      _scheduledDate = ann.scheduledDate;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final b64 = base64Encode(bytes);
      setState(() => _coverImageBase64 = 'data:image/jpeg;base64,$b64');
    }
  }

  Future<void> _selectDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => _scheduledDate = d);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {
        'title': _titleCtrl.text,
        'content': _contentCtrl.text,
        'category': _category,
        'scheduled_date': _scheduledDate,
        'banner_url': _coverImageBase64,
        if (widget.announcement == null) 'liked_by': [],
        if (widget.announcement == null) 'comment_count': 0,
      };

      if (widget.announcement == null) {
        payload['date_posted'] = FieldValue.serverTimestamp();
        await FirestoreService.db.collection('announcements').add(payload);
        await ActivityLogService.log(
          action: 'announcement_posted',
          message: 'Posted new announcement: "${_titleCtrl.text}"',
          entityType: 'announcement',
          entityId: '',
        );
      } else {
        await FirestoreService.db
            .collection('announcements')
            .doc(widget.announcement!.id)
            .update(payload);
        await ActivityLogService.log(
          action: 'announcement_updated',
          message: 'Updated announcement: "${_titleCtrl.text}"',
          entityType: 'announcement',
          entityId: widget.announcement!.id,
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: TraceAppBar(
        title: widget.announcement == null
            ? 'Post Announcement'
            : 'Edit Announcement',
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: TraceColors.royalBlue),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: TraceColors.lightGrey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: TraceColors.gold.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          image: _coverImageBase64.isNotEmpty
                              ? DecorationImage(
                                  image: _coverImageBase64.startsWith('data:image')
                                      ? MemoryImage(
                                          base64Decode(
                                            _coverImageBase64.split(',').last,
                                          ),
                                        ) as ImageProvider
                                      : NetworkImage(_coverImageBase64),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _coverImageBase64.isEmpty
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.add_photo_alternate_rounded,
                                    color: TraceColors.gold,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Upload Cover Image',
                                    style: GoogleFonts.inter(
                                      color: TraceColors.navyBlue,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: TraceColors.royalBlue, width: 2),
                        ),
                      ),
                      style: GoogleFonts.inter(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _contentCtrl,
                      minLines: 8,
                      maxLines: 15,
                      decoration: const InputDecoration(
                        labelText: 'Content (Agenda/Details)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: TraceColors.royalBlue, width: 2),
                        ),
                      ),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Upcoming', 'Ongoing', 'Previous', 'Cancelled']
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v ?? _category),
                    ),
                    const SizedBox(height: 16),
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        tileColor: Colors.white,
                        title: const Text(
                          'Scheduled Date (Optional)',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          _scheduledDate == null
                              ? 'Not set'
                              : DateFormat('MM/dd/yyyy').format(_scheduledDate!),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.calendar_today, size: 20),
                        onTap: _selectDate,
                      ),
                    ),
                    const SizedBox(height: 32),
                    GoldButton(
                      label: widget.announcement == null ? 'Post' : 'Save Changes',
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
