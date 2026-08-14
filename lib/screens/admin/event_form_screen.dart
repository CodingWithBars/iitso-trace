import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/event.dart';
import '../../theme/app_theme.dart';
import '../../services/event_service.dart';
import '../../widgets/shared_widgets.dart';

class EventFormScreen extends StatefulWidget {
  final Event? event;
  const EventFormScreen({super.key, this.event});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _venueCtrl;
  late TextEditingController _sanctionAmountCtrl;
  late TextEditingController _sanctionDescCtrl;
  late TextEditingController _contributionCtrl;

  late DateTime _eventDate;
  String _coverImageBase64 = '';
  
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  TimeOfDay? _mIn;
  TimeOfDay? _mOut;
  TimeOfDay? _aIn;
  TimeOfDay? _aOut;

  String _sanctionType = 'monetary';
  String _eventType = 'Whole Day';
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _nameCtrl = TextEditingController(text: e?.eventName ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _venueCtrl = TextEditingController(text: e?.venue ?? '');
    
    _eventDate = e?.date ?? DateTime.now();
    _coverImageBase64 = e?.bannerUrl ?? '';

    _startTime = _parseTimeOfDay(e?.startTime);
    _endTime = _parseTimeOfDay(e?.endTime);
    _mIn = _parseTimeOfDay(e?.morningTimeIn);
    _mOut = _parseTimeOfDay(e?.morningTimeOut);
    _aIn = _parseTimeOfDay(e?.afternoonTimeIn);
    _aOut = _parseTimeOfDay(e?.afternoonTimeOut);

    _sanctionAmountCtrl = TextEditingController(
      text: e?.sanctionAmount != null ? e!.sanctionAmount.toString() : '',
    );
    _sanctionDescCtrl = TextEditingController(
      text: e?.sanctionDescription ?? '',
    );
    _contributionCtrl = TextEditingController(
      text: e?.eventContribution != null ? e!.eventContribution.toString() : '',
    );

    if (e != null) {
      if (e.sanctionDescription != null && e.sanctionDescription!.isNotEmpty) {
        _sanctionType = 'non-monetary';
      }
      if (e.isWholeDay) {
        _eventType = 'Whole Day';
      } else if (e.isPmOnly) {
        _eventType = 'Afternoon';
      } else if (e.isAmOnly) {
        _eventType = 'Morning';
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _venueCtrl.dispose();
    _sanctionAmountCtrl.dispose();
    _sanctionDescCtrl.dispose();
    _contributionCtrl.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTimeOfDay(String? s) {
    if (s == null || s.isEmpty || !s.contains(':')) return null;
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String? _formatTimeOfDay(TimeOfDay? t) {
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String _displayTime(TimeOfDay? t) {
    return t == null ? 'Not set' : t.format(context);
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
      setState(() {
        _coverImageBase64 = 'data:image/jpeg;base64,$b64';
      });
    }
  }

  Future<void> _saveEvent() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event Name is required')),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final sanctionAmt = double.tryParse(_sanctionAmountCtrl.text.trim());
      final contribution = double.tryParse(_contributionCtrl.text.trim());
      
      final data = {
        'event_name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'venue': _venueCtrl.text.trim(),
        'date': _eventDate,
        'start_time': _formatTimeOfDay(_startTime),
        'end_time': _formatTimeOfDay(_endTime),
        'is_whole_day': _eventType == 'Whole Day',
        'is_pm_only': _eventType == 'Afternoon',
        'is_am_only': _eventType == 'Morning',
        'morning_time_in':
            (_eventType == 'Whole Day' || _eventType == 'Morning')
            ? _formatTimeOfDay(_mIn)
            : null,
        'morning_time_out':
            (_eventType == 'Whole Day' || _eventType == 'Morning')
            ? _formatTimeOfDay(_mOut)
            : null,
        'afternoon_time_in':
            (_eventType == 'Whole Day' || _eventType == 'Afternoon')
            ? _formatTimeOfDay(_aIn)
            : null,
        'afternoon_time_out':
            (_eventType == 'Whole Day' || _eventType == 'Afternoon')
            ? _formatTimeOfDay(_aOut)
            : null,
        'banner_url': _coverImageBase64,
        'status': widget.event?.status ?? 'upcoming',
        'sanction_amount': _sanctionType == 'monetary' ? sanctionAmt : null,
        'sanction_description': _sanctionType == 'non-monetary'
            ? _sanctionDescCtrl.text.trim().isEmpty ? null : _sanctionDescCtrl.text.trim()
            : null,
        'event_contribution': contribution,
      };

      if (widget.event == null) {
        await EventService.createEvent(data);
      } else {
        await EventService.updateEvent(widget.event!.id, data);
      }
      
      if (!mounted) return;
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving event: $e')),
      );
      setState(() => _isSaving = false);
    }
  }

  Widget _buildTimeTile(String label, TimeOfDay? val, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, style: const TextStyle(fontSize: 13, color: TraceColors.medGrey)),
        subtitle: Text(
          _displayTime(val),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: TraceColors.navyBlue,
          ),
        ),
        trailing: const Icon(Icons.access_time, size: 22, color: TraceColors.gold),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: AppBar(
        title: Text(
          isEditing ? 'Edit Event' : 'Create New Event',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: TraceColors.white,
          ),
        ),
        backgroundColor: TraceColors.navyBlue,
        iconTheme: const IconThemeData(color: TraceColors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGeneralInfoCard(),
                const SizedBox(height: 20),
                _buildScheduleCard(),
                const SizedBox(height: 20),
                _buildAccountabilityCard(),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => context.pop(),
                      child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 48,
                      width: 160,
                      child: GoldButton(
                        label: _isSaving ? 'Saving...' : (isEditing ? 'Save Event' : 'Create Event'),
                        onPressed: _isSaving ? () {} : _saveEvent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralInfoCard() {
    return TraceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'General Information',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: TraceColors.navyBlue,
            ),
          ),
          const SizedBox(height: 16),
          // Cover Image
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: TraceColors.lightGrey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: TraceColors.gold.withValues(alpha: 0.5),
                  width: 2,
                ),
                image: _coverImageBase64.isNotEmpty
                    ? DecorationImage(
                        image: MemoryImage(
                          base64Decode(_coverImageBase64.split(',').last),
                        ),
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
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Click to upload cover image (Optional)',
                          style: GoogleFonts.inter(
                            color: TraceColors.navyBlue,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Event Name',
              hintText: 'e.g. Intramurals 2026',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _venueCtrl,
            decoration: const InputDecoration(
              labelText: 'Venue',
              hintText: 'e.g. Main Gymnasium',
            ),
          ),
          const SizedBox(height: 16),
          // Agenda with much larger field
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Agenda / Description (Optional)',
              hintText: 'Paste or type large details here...',
              alignLabelWithHint: true,
            ),
            maxLines: 15,
            minLines: 5,
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    return TraceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule & Attendance',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: TraceColors.navyBlue,
            ),
          ),
          const SizedBox(height: 16),
          // Event Date
          Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Event Date', style: TextStyle(fontSize: 13, color: TraceColors.medGrey)),
              subtitle: Text(
                DateFormat('MMMM dd, yyyy').format(_eventDate),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: TraceColors.navyBlue),
              ),
              trailing: const Icon(Icons.calendar_today, size: 22, color: TraceColors.gold),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _eventDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (d != null) setState(() => _eventDate = d);
              },
            ),
          ),
          const Divider(height: 32),
          // Overall Times
          Row(
            children: [
              Expanded(
                child: _buildTimeTile('Overall Start', _startTime, () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _startTime ?? const TimeOfDay(hour: 8, minute: 0),
                  );
                  if (t != null) setState(() => _startTime = t);
                }),
              ),
              Expanded(
                child: _buildTimeTile('Overall End', _endTime, () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _endTime ?? const TimeOfDay(hour: 17, minute: 0),
                  );
                  if (t != null) setState(() => _endTime = t);
                }),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Event Type Dropdown
          DropdownButtonFormField<String>(
            initialValue: _eventType,
            items: const [
              DropdownMenuItem(value: 'Whole Day', child: Text('Whole Day Event (AM & PM)')),
              DropdownMenuItem(value: 'Morning', child: Text('Morning Only')),
              DropdownMenuItem(value: 'Afternoon', child: Text('Afternoon Only')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _eventType = val);
            },
            decoration: const InputDecoration(
              labelText: 'Attendance Required Phase',
            ),
          ),
          const SizedBox(height: 24),
          // Morning Phase
          if (_eventType == 'Whole Day' || _eventType == 'Morning') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TraceColors.offWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TraceColors.lightGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Morning Session Attendance',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: TraceColors.navyBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeTile('Required Time In', _mIn, () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _mIn ?? const TimeOfDay(hour: 8, minute: 0),
                          );
                          if (t != null) setState(() => _mIn = t);
                        }),
                      ),
                      Expanded(
                        child: _buildTimeTile('Time Out (Optional)', _mOut, () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _mOut ?? const TimeOfDay(hour: 12, minute: 0),
                          );
                          if (t != null) setState(() => _mOut = t);
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Afternoon Phase
          if (_eventType == 'Whole Day' || _eventType == 'Afternoon') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TraceColors.offWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TraceColors.lightGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.nightlight_round, color: TraceColors.navyBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Afternoon Session Attendance',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: TraceColors.navyBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeTile('Required Time In', _aIn, () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _aIn ?? const TimeOfDay(hour: 13, minute: 0),
                          );
                          if (t != null) setState(() => _aIn = t);
                        }),
                      ),
                      Expanded(
                        child: _buildTimeTile('Time Out (Optional)', _aOut, () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _aOut ?? const TimeOfDay(hour: 17, minute: 0),
                          );
                          if (t != null) setState(() => _aOut = t);
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountabilityCard() {
    return TraceCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_rounded, color: TraceColors.navyBlue),
              const SizedBox(width: 8),
              Text(
                'Accountability & Finance',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: TraceColors.navyBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Set optional sanctions for absentees or require a contribution from all students.',
            style: GoogleFonts.inter(fontSize: 13, color: TraceColors.medGrey),
          ),
          const SizedBox(height: 20),
          
          // Sanction Toggle
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _sanctionType = 'monetary'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _sanctionType == 'monetary' ? TraceColors.navyBlue : Colors.transparent,
                      border: Border.all(color: TraceColors.navyBlue),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    ),
                    child: Text(
                      '₱ Monetary Fine',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _sanctionType == 'monetary' ? Colors.white : TraceColors.navyBlue,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _sanctionType = 'non-monetary'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _sanctionType == 'non-monetary' ? TraceColors.navyBlue : Colors.transparent,
                      border: Border.all(color: TraceColors.navyBlue),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                    ),
                    child: Text(
                      'Non-Monetary Sanction',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _sanctionType == 'non-monetary' ? Colors.white : TraceColors.navyBlue,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_sanctionType == 'monetary')
            TextField(
              controller: _sanctionAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Fine Amount (₱) for Absentees',
                hintText: 'e.g. 50.00',
                prefixIcon: Icon(Icons.payments_rounded),
              ),
            )
          else
            TextField(
              controller: _sanctionDescCtrl,
              decoration: const InputDecoration(
                labelText: 'Sanction Description',
                hintText: 'e.g. 2 hours community service',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
              maxLines: 2,
            ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          TextField(
            controller: _contributionCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Event Contribution per Student (₱)',
              hintText: 'e.g. 150.00',
              prefixIcon: Icon(Icons.volunteer_activism_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
