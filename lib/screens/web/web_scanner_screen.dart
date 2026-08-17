import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ntp/ntp.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/attendance_service.dart';
import '../../services/event_service.dart';
import '../../models/event.dart';
import '../../models/student.dart';
import '../../services/network_service.dart';
import 'dart:async';
import '../../widgets/scan_result_modal.dart';

class WebScannerScreen extends StatefulWidget {
  const WebScannerScreen({super.key});

  @override
  State<WebScannerScreen> createState() => _WebScannerScreenState();
}

class _WebScannerScreenState extends State<WebScannerScreen>
    with TickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
  );
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnim;

  bool _isProcessing = false;
  bool _isOfflineMode = false;
  List<Student>? _offlineStudents;
  Map<String, Map<String, dynamic>>? _offlineAttendance;
  Duration _ntpOffset = Duration.zero;
  Event? _selectedEvent;
  List<Event> _activeEvents = [];
  bool _loadingEvents = true;
  ScanPhase _manualPhase = ScanPhase.timeInAm;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnim = CurvedAnimation(
      parent: _scanLineController,
      curve: Curves.easeInOut,
    );
    _syncTime();
    _loadEvents();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final user = AuthService().currentUser;
    if (user != null) {
      if (user.email?.toLowerCase() == 'iitsoofficer@dorsu.bc') {
        if (mounted) setState(() => _isSuperAdmin = true);
        return;
      }
      try {
        final doc = await FirebaseFirestore.instance.collection('admins').doc(user.uid).get();
        if (doc.exists) {
          final role = doc.data()?['role']?.toString().toLowerCase();
          if (role == 'superadmin') {
            if (mounted) setState(() => _isSuperAdmin = true);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _syncTime() async {
    if (NetworkService().isOffline) return;
    try {
      final ntpTime = await NTP.now();
      _ntpOffset = ntpTime.difference(DateTime.now());
    } catch (_) {}
  }

  DateTime get _networkNow => DateTime.now().add(_ntpOffset);

  DateTime? _parseScheduledTime(String? timeStr, DateTime baseDate) {
    if (timeStr == null || timeStr.isEmpty) return null;
    DateTime? time;
    try {
      time = DateFormat('h:mm a').parse(timeStr);
    } catch (_) {
      try {
        time = DateFormat('HH:mm').parse(timeStr);
      } catch (_) {
        return null;
      }
    }
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      time.hour,
      time.minute,
    );
  }

  bool _isTimeOutEnabled(String? scheduledTimeStr, DateTime eventDate) {
    if (scheduledTimeStr == null || scheduledTimeStr.isEmpty) return true;
    final scheduledTime = _parseScheduledTime(scheduledTimeStr, eventDate);
    if (scheduledTime == null) return true;
    return _networkNow.isAfter(scheduledTime) ||
        _networkNow.isAtSameMomentAs(scheduledTime);
  }

  Future<void> _loadEvents() async {
    final snap = await FirestoreService.db
        .collection('events')
        .where('status', whereIn: ['upcoming', 'ongoing'])
        .get();
    if (!mounted) return;

    final now = DateTime.now();
    final events = <Event>[];

    for (var d in snap.docs) {
      final e = Event.fromMap(d.data(), d.id);
      final isToday =
          e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day;

      // Auto-complete event check
      DateTime? finalOut = _parseScheduledTime(e.endTime, e.date);

      if (finalOut != null &&
          now.isAfter(finalOut.add(const Duration(hours: 1)))) {
        // Event has expired by 1 hour past its final time out
        EventService.updateEvent(e.id, {'status': 'completed'}); // non-blocking
        continue;
      }

      if ((isToday && now.isAfter(e.date)) || e.status == 'ongoing') {
        events.add(e);
      }
    }

    setState(() {
      _activeEvents = events;
      _loadingEvents = false;
    });
    if (events.isNotEmpty) {
      if (_selectedEvent == null) {
        setState(() => _selectedEvent = events.first);
      } else {
        final match = events.where((e) => e.id == _selectedEvent!.id);
        setState(
          () => _selectedEvent = match.isNotEmpty ? match.first : events.first,
        );
      }
    } else {
      setState(() => _selectedEvent = null);
    }
  }

  ScanPhase? _determineActivePhase() {
    if (_selectedEvent == null) return null;
    if (_selectedEvent!.status == 'completed') return null;
    return _manualPhase;
  }

  Future<void> _downloadOfflineData() async {
    if (_selectedEvent == null) return;
    setState(() => _isProcessing = true);
    try {
      final stSnap = await FirestoreService.students.get();
      final atSnap = await FirestoreService.attendance
          .where('event_id', isEqualTo: _selectedEvent!.id)
          .get();

      final st = stSnap.docs
          .map((d) => Student.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      final at = {
        for (var d in atSnap.docs) d.id: d.data() as Map<String, dynamic>,
      };

      setState(() {
        _offlineStudents = st;
        _offlineAttendance = at;
        _isOfflineMode = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline data downloaded. Offline Mode ON.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmCutOffTime() async {
    if (_selectedEvent == null) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TraceColors.offWhite,
        title: Text(
          'End Time-In?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: TraceColors.warning,
          ),
        ),
        content: Text(
          'Are you sure you want to end the Time-In phase? Any subsequent scans will be marked as "Late Entry".',
          style: GoogleFonts.inter(color: TraceColors.medGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: TraceColors.medGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TraceColors.warning,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'End Time-In',
              style: GoogleFonts.inter(
                color: TraceColors.navyBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loadingEvents = true);
      await EventService.updateEvent(_selectedEvent!.id, {
        'time_in_closed': true,
        'cut_off_time': Timestamp.now(),
      });
      await _loadEvents();
    }
  }

  Future<void> _confirmEndEvent() async {
    if (_selectedEvent == null) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TraceColors.offWhite,
        title: Text(
          'End Event?',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: TraceColors.navyBlue,
          ),
        ),
        content: Text(
          'Are you sure you want to end "${_selectedEvent!.eventName}"? No more attendance will be recorded.',
          style: GoogleFonts.inter(color: TraceColors.medGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: TraceColors.medGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TraceColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'End Event',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loadingEvents = true);
      await EventService.updateEvent(_selectedEvent!.id, {
        'status': 'completed',
      });
      await _loadEvents();
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _selectedEvent == null) return;
    final activePhase = _determineActivePhase();
    if (activePhase == null) return; // No active window

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessing = true);
    await _controller.stop();

    final result = await AttendanceService.processScan(
      qrHash: rawValue,
      event: _selectedEvent!,
      phase: activePhase,
      isOfflineMode: _isOfflineMode,
      offlineStudents: _offlineStudents,
      offlineAttendance: _offlineAttendance,
    );

    if (!mounted) return;
    final bool canVoid =
        result.status == ScanResultStatus.timeInSuccess ||
        result.status == ScanResultStatus.timeOutSuccess ||
        result.status == ScanResultStatus.lateEntry ||
        result.status == ScanResultStatus.attendanceComplete;

    await ScanResultModal.show(
      context,
      result,
      activePhase,
      () {
        _controller.start();
        setState(() => _isProcessing = false);
      },
      onVoid: canVoid
          ? () async {
              if (result.attendanceDocId != null) {
                await AttendanceService.voidScan(
                  attendanceDocId: result.attendanceDocId!,
                  phase: activePhase,
                  event: _selectedEvent!,
                  isOfflineMode: _isOfflineMode,
                  offlineAttendance: _offlineAttendance,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scan voided successfully.')),
                  );
                }
              }
              _controller.start();
              setState(() => _isProcessing = false);
            }
          : null,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera view
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Top gradient overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Bottom gradient overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 240,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Top bar
          SafeArea(
            child: Column(
              children: [
                if (NetworkService().isOffline || _isOfflineMode)
                  Container(
                    width: double.infinity,
                    color: Colors.amber.shade200,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      _isOfflineMode
                          ? '⚡ OFFLINE MODE ACTIVE'
                          : '⚡ NO NETWORK DETECTED',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => context.go('/admin/dashboard'),
                      ),
                      const Spacer(),
                      ShaderMask(
                        shaderCallback: (b) =>
                            TraceColors.goldGradient.createShader(b),
                        child: Text(
                          'TRACE SCANNER',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      ValueListenableBuilder(
                        valueListenable: _controller,
                        builder: (ctx, state, _) {
                          final torchState = state.torchState;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isOfflineMode
                                      ? Icons.cloud_off
                                      : Icons.cloud_download,
                                  color: _isOfflineMode
                                      ? Colors.greenAccent
                                      : Colors.white,
                                ),
                                onPressed: _isOfflineMode
                                    ? null
                                    : _downloadOfflineData,
                              ),
                              IconButton(
                                icon: Icon(
                                  torchState == TorchState.on
                                      ? Icons.flash_on
                                      : Icons.flash_off,
                                  color: Colors.white,
                                ),
                                onPressed: () => _controller.toggleTorch(),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Event + Phase selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _loadingEvents
                          ? const LinearProgressIndicator(
                              color: TraceColors.gold,
                            )
                          : _activeEvents.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: TraceColors.error.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: TraceColors.error.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: TraceColors.error,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'No active events found.',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _glassDropdown(
                                    value: _selectedEvent,
                                    hint: 'Select Event',
                                    items: _activeEvents
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e.eventName),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (e) =>
                                        setState(() => _selectedEvent = e),
                                  ),
                                ),
                              ],
                            ),
                      if (!_loadingEvents && _activeEvents.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        // Dynamic Phase Buttons based on Event Type
                        if (_selectedEvent != null) ...[
                          if (_selectedEvent!.isWholeDay ||
                              _selectedEvent!.isAmOnly) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildPhaseBtn(
                                  'Morning In',
                                  ScanPhase.timeInAm,
                                ),
                                const SizedBox(width: 8),
                                _buildPhaseBtn(
                                  'Morning Out',
                                  ScanPhase.timeOutAm,
                                  isEnabled: _isTimeOutEnabled(
                                    _selectedEvent!.morningTimeOut,
                                    _selectedEvent!.date,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_selectedEvent!.isWholeDay ||
                              _selectedEvent!.isPmOnly) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildPhaseBtn(
                                  'Afternoon In',
                                  ScanPhase.timeInPm,
                                ),
                                const SizedBox(width: 8),
                                _buildPhaseBtn(
                                  'Afternoon Out',
                                  ScanPhase.timeOutPm,
                                  isEnabled: _isTimeOutEnabled(
                                    _selectedEvent!.afternoonTimeOut,
                                    _selectedEvent!.date,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // QR Viewfinder frame
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                children: [
                  // Dark overlay corners (visual frame)
                  CustomPaint(
                    size: const Size(260, 260),
                    painter: _ScannerFramePainter(),
                  ),
                  // Animated scan line
                  AnimatedBuilder(
                    animation: _scanLineAnim,
                    builder: (ctx, _) => Positioned(
                      top: 10 + _scanLineAnim.value * 240,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              TraceColors.gold,
                              TraceColors.gold,
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: TraceColors.gold.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Processing overlay
                  if (_isProcessing)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: TraceColors.gold,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom instructions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.qr_code_rounded,
                            color: TraceColors.gold,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Align the student\'s QR Code within the frame',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedEvent != null && _isSuperAdmin)
                      Row(
                        children: [
                          if (_selectedEvent?.timeInClosed != true) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TraceColors.warning
                                      .withValues(alpha: 0.2),
                                  foregroundColor: TraceColors.warning,
                                  side: BorderSide(
                                    color: TraceColors.warning.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.timer_off_rounded),
                                label: Text(
                                  'End Time-In',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _confirmCutOffTime,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TraceColors.error.withValues(
                                  alpha: 0.2,
                                ),
                                foregroundColor: TraceColors.error,
                                side: BorderSide(
                                  color: TraceColors.error.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.stop_circle_rounded),
                              label: Text(
                                'End Event',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: _selectedEvent!.status == 'completed'
                                  ? null
                                  : _confirmEndEvent,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassDropdown({
    required Event? value,
    required String hint,
    required List<DropdownMenuItem<Event>> items,
    required ValueChanged<Event?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Event>(
          value: value,
          hint: Text(
            hint,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
          ),
          isExpanded: true,
          dropdownColor: TraceColors.navyBlue,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: TraceColors.gold,
          ),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: items,
          onChanged: (e) {
            onChanged(e);
            if (e != null) {
              if (e.isAmOnly || e.isWholeDay) {
                setState(() => _manualPhase = ScanPhase.timeInAm);
              } else if (e.isPmOnly) {
                setState(() => _manualPhase = ScanPhase.timeInPm);
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildPhaseBtn(
    String label,
    ScanPhase phase, {
    bool isEnabled = true,
  }) {
    final bool isSelected = _manualPhase == phase;
    return Expanded(
      child: GestureDetector(
        onTap: isEnabled ? () => setState(() => _manualPhase = phase) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: !isEnabled
                ? Colors.white.withValues(alpha: 0.1)
                : (isSelected ? TraceColors.navyBlue : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: !isEnabled
                  ? Colors.white12
                  : (isSelected ? TraceColors.navyBlue : Colors.white30),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: !isEnabled
                  ? Colors.white30
                  : (isSelected ? Colors.white : Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TraceColors.gold
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 32.0;
    const r = 10.0;

    // Top-left
    canvas.drawLine(const Offset(r, 0), const Offset(cornerLen, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, cornerLen), paint);
    canvas.drawArc(
      const Rect.fromLTWH(0, 0, r * 2, r * 2),
      3.14159,
      3.14159 / 2,
      false,
      paint,
    );

    // Top-right
    canvas.drawLine(
      Offset(size.width - cornerLen, 0),
      Offset(size.width - r, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, r),
      Offset(size.width, cornerLen),
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(size.width - r * 2, 0, r * 2, r * 2),
      -3.14159 / 2,
      3.14159 / 2,
      false,
      paint,
    );

    // Bottom-left
    canvas.drawLine(const Offset(0, 0), const Offset(0, 0), paint);
    canvas.drawLine(
      Offset(r, size.height),
      Offset(cornerLen, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height - cornerLen),
      Offset(0, size.height - r),
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(0, size.height - r * 2, r * 2, r * 2),
      3.14159 / 2,
      3.14159 / 2,
      false,
      paint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - cornerLen, size.height),
      Offset(size.width - r, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - cornerLen),
      Offset(size.width, size.height - r),
      paint,
    );
    canvas.drawArc(
      Rect.fromLTWH(size.width - r * 2, size.height - r * 2, r * 2, r * 2),
      0,
      3.14159 / 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
