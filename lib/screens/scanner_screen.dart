import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ntp/ntp.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/attendance_service.dart';
import '../services/event_service.dart';
import '../services/offline_cache_service.dart';
import '../models/event.dart';
import '../models/student.dart';
import '../services/network_service.dart';
import 'dart:async';
import '../widgets/scan_result_modal.dart';

class ScannerScreen extends StatefulWidget {
  final String? eventId;
  const ScannerScreen({super.key, this.eventId});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
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
  DateTime? _lastSyncTime;   // tracks when offline data was last downloaded
  bool _autoDownloading = false; // prevents duplicate auto-download
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
    // Try loading previously-cached offline data immediately
    _tryLoadCachedData();
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

  /// Auto-loads cached offline data for the currently-selected event.
  /// Called on initState so data is available the moment the scanner opens,
  /// even before internet is confirmed.
  Future<void> _tryLoadCachedData() async {
    // Wait until _selectedEvent is populated (may be null on first call)
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || _selectedEvent == null) return;
    await _loadCachedDataForEvent(_selectedEvent!.id);
  }

  Future<void> _loadCachedDataForEvent(String eventId) async {
    final cache = await OfflineCacheService.getOfflineScannerData(eventId);
    if (cache == null) return;
    final syncTime = await OfflineCacheService.getLastSyncTime(eventId);
    if (!mounted) return;
    setState(() {
      _offlineStudents = cache.students;
      _offlineAttendance = cache.attendance;
      _lastSyncTime = syncTime;
      // Only activate offline mode if we're actually offline
      if (NetworkService().isOffline) {
        _isOfflineMode = true;
      }
    });
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
        await EventService.updateEvent(e.id, {'status': 'completed'});
        continue;
      }

      // FIX: Both 'ongoing' AND 'upcoming' statuses require isToday check
      // to prevent events from other dates appearing in the scanner.
      if (isToday) {
        events.add(e);
      }
    }

    setState(() {
      _activeEvents = events;
      _loadingEvents = false;
    });
    if (events.isNotEmpty) {
      if (widget.eventId != null && _selectedEvent == null) {
        final match = events.where((e) => e.id == widget.eventId);
        if (match.isNotEmpty) {
          _selectedEvent = match.first;
        }
      }
      
      if (_selectedEvent == null) {
        setState(() => _selectedEvent = events.first);
      } else {
        final match = events.where((e) => e.id == _selectedEvent!.id);
        setState(
          () => _selectedEvent = match.isNotEmpty ? match.first : events.first,
        );
      }
      // Auto-select the correct phase based on current time
      _autoDetectPhase();

      // Auto-download offline data in the background when online,
      // so it's cached and ready before the internet drops.
      if (!NetworkService().isOffline && !_autoDownloading) {
        _autoDownloadInBackground();
      }
    } else {
      setState(() => _selectedEvent = null);
    }
  }

  /// Silently downloads offline data in the background (no UI spinners).
  /// Only runs once per scanner session.
  Future<void> _autoDownloadInBackground() async {
    if (_selectedEvent == null || _autoDownloading) return;
    _autoDownloading = true;
    try {
      final stSnap = await FirestoreService.students.get();
      final atSnap = await FirestoreService.attendance
          .where('event_id', isEqualTo: _selectedEvent!.id)
          .get();

      final students = stSnap.docs
          .map((d) => Student.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
      final attendance = {
        for (var d in atSnap.docs) d.id: d.data() as Map<String, dynamic>,
      };

      // Persist to local cache
      await OfflineCacheService.saveOfflineScannerData(
        eventId: _selectedEvent!.id,
        students: students,
        attendance: attendance,
      );
      final syncTime = await OfflineCacheService.getLastSyncTime(_selectedEvent!.id);

      if (!mounted) return;
      setState(() {
        _offlineStudents = students;
        _offlineAttendance = attendance;
        _lastSyncTime = syncTime;
      });
    } catch (e) {
      debugPrint('Auto-download offline data failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Auto-detect phase based on current NTP time vs. event scheduled times
  // ---------------------------------------------------------------------------
  void _autoDetectPhase() {
    if (_selectedEvent == null) return;
    final event = _selectedEvent!;
    final now = _networkNow;

    final amIn = _parseScheduledTime(event.morningTimeIn, event.date);
    final amOut = _parseScheduledTime(event.morningTimeOut, event.date);
    final pmIn = _parseScheduledTime(event.afternoonTimeIn, event.date);
    final pmOut = _parseScheduledTime(event.afternoonTimeOut, event.date);


    ScanPhase detected = ScanPhase.timeInAm;
    if (event.isWholeDay || event.isAmOnly) {
      if (amOut != null && now.isAfter(amOut)) {
        // Past morning time-out window → morning is over
        detected = (event.isWholeDay || event.isPmOnly)
            ? (pmOut != null && now.isAfter(pmOut)
                ? ScanPhase.timeOutPm
                : (pmIn != null && now.isAfter(pmIn)
                    ? ScanPhase.timeOutPm
                    : ScanPhase.timeInPm))
            : ScanPhase.timeOutAm;
      } else if (amIn != null && now.isAfter(amIn)) {
        // During morning time-in window
        if (amOut != null && _isTimeOutEnabled(event.morningTimeOut, event.date)) {
          detected = ScanPhase.timeOutAm;
        } else {
          detected = ScanPhase.timeInAm;
        }
      } else {
        detected = ScanPhase.timeInAm;
      }
    } else if (event.isPmOnly) {
      if (pmIn != null && now.isAfter(pmIn)) {
        detected = ScanPhase.timeOutPm;
      } else {
        detected = ScanPhase.timeInPm;
      }
    }

    if (mounted && detected != _manualPhase) {
      setState(() {
        _manualPhase = detected;
      });
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

      // Persist to local storage so data survives app restarts
      await OfflineCacheService.saveOfflineScannerData(
        eventId: _selectedEvent!.id,
        students: st,
        attendance: at,
      );
      final syncTime = await OfflineCacheService.getLastSyncTime(_selectedEvent!.id);

      setState(() {
        _offlineStudents = st;
        _offlineAttendance = at;
        _isOfflineMode = true;
        _lastSyncTime = syncTime;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Offline data downloaded (${st.length} students). Offline Mode ON.',
            ),
            backgroundColor: Colors.green.shade700,
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

    // FIX: wrap stop() in try-catch so a camera error doesn't permanently lock the scanner
    try {
      await _controller.stop();
    } catch (_) {}

    final result = await AttendanceService.processScan(
      qrHash: rawValue,
      event: _selectedEvent!,
      phase: activePhase,
      isOfflineMode: _isOfflineMode,
      offlineStudents: _offlineStudents,
      offlineAttendance: _offlineAttendance,
    );

    if (_isOfflineMode && _offlineStudents != null && _offlineAttendance != null) {
      // Force persist the offline attendance map immediately so it survives restarts
      await OfflineCacheService.saveOfflineScannerData(
        eventId: _selectedEvent!.id,
        students: _offlineStudents!,
        attendance: _offlineAttendance!,
      );
    }

    if (!mounted) {
      // Widget was disposed while processing — reset state and bail
      return;
    }

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
        if (mounted) {
          _controller.start();
          setState(() => _isProcessing = false);
        }
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

                if (_isOfflineMode && _offlineStudents != null && _offlineAttendance != null) {
                  // Re-persist after voiding to ensure UI cache stays consistent
                  await OfflineCacheService.saveOfflineScannerData(
                    eventId: _selectedEvent!.id,
                    students: _offlineStudents!,
                    attendance: _offlineAttendance!,
                  );
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scan voided successfully.')),
                  );
                }
              }
              if (mounted) {
                _controller.start();
                setState(() => _isProcessing = false);
              }
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
    // On web, show instructions
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: TraceColors.navyBlue,
        appBar: AppBar(
          backgroundColor: TraceColors.navyBlue,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: TraceColors.gold),
            onPressed: () => context.go('/admin/dashboard'),
          ),
          title: Text(
            'QR Scanner',
            style: GoogleFonts.inter(
              color: TraceColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: TraceColors.goldGradient,
              ),
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: TraceColors.gold.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 80,
                      color: TraceColors.gold,
                    ),

                    const SizedBox(height: 20),
                    Text(
                      'Camera Scanner',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: TraceColors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please use the TRACE mobile app\nto access the QR scanner on your device.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: TraceColors.white.withValues(alpha: 0.6),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                  _buildOfflineBanner(),
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
                                      : (_lastSyncTime != null
                                          ? Icons.cloud_done
                                          : Icons.cloud_download),
                                  color: _isOfflineMode
                                      ? Colors.greenAccent
                                      : (_lastSyncTime != null
                                          ? Colors.lightGreenAccent
                                          : Colors.white),
                                ),
                                tooltip: _isOfflineMode
                                    ? 'Offline Mode Active — tap to re-sync'
                                    : (_lastSyncTime != null
                                        ? 'Data cached — tap to re-sync'
                                        : 'Download offline data'),
                                onPressed: NetworkService().isOffline
                                    ? null  // no internet, can't download
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
                                    onChanged: (e) {
                                      setState(() {
                                        _selectedEvent = e;
                                      });
                                      _autoDetectPhase();
                                    },
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

  /// Rich offline status banner shown at top of scanner when offline or cached data is loaded.
  Widget _buildOfflineBanner() {
    final bool isHardOffline = NetworkService().isOffline;
    final bool hasCachedData = _offlineStudents != null;

    final Color bannerColor = isHardOffline
        ? Colors.red.shade700
        : (_isOfflineMode ? Colors.orange.shade700 : Colors.amber.shade700);

    final String modeLabel = isHardOffline
        ? '⚡ NO NETWORK'
        : (_isOfflineMode ? '⚡ OFFLINE MODE' : '⚡ CACHED DATA READY');

    final String syncLabel = _lastSyncTime != null
        ? OfflineCacheService.syncAgoLabel(_lastSyncTime!)
        : (hasCachedData ? 'data loaded' : 'no cache');

    return Container(
      width: double.infinity,
      color: bannerColor,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$modeLabel  •  $syncLabel',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          if (!isHardOffline && !_isOfflineMode && hasCachedData)
            GestureDetector(
              onTap: _downloadOfflineData,
              child: Text(
                'Re-sync',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  decoration: TextDecoration.underline,
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
