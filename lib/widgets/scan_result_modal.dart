import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../theme/app_theme.dart';
import '../services/attendance_service.dart';

class ScanResultModal extends StatefulWidget {
  final ScanResult result;
  final ScanPhase phase;
  final VoidCallback onContinue;
  final VoidCallback? onVoid;

  const ScanResultModal({
    super.key,
    required this.result,
    required this.phase,
    required this.onContinue,
    this.onVoid,
  });

  static Future<void> show(
    BuildContext context,
    ScanResult result,
    ScanPhase phase,
    VoidCallback onContinue, {
    VoidCallback? onVoid,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ScanResultModal(
        result: result,
        phase: phase,
        onContinue: onContinue,
        onVoid: onVoid,
      ),
    );
  }

  @override
  State<ScanResultModal> createState() => _ScanResultModalState();
}

class _ScanResultModalState extends State<ScanResultModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 24,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 340,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: TraceColors.white,
                  border: Border.all(color: config.borderColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: config.borderColor.withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar with Status Badge
                    Stack(
                      alignment: Alignment.bottomRight,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: TraceColors.offWhite,
                            border: Border.all(
                              color: config.borderColor,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child:
                                widget.result.studentAvatarUrl != null &&
                                    widget.result.studentAvatarUrl!.isNotEmpty
                                ? (widget.result.studentAvatarUrl!.startsWith(
                                        'data:image',
                                      )
                                      ? Image.memory(
                                          const Base64Decoder().convert(
                                            widget.result.studentAvatarUrl!
                                                .split(',')
                                                .last,
                                          ),
                                          fit: BoxFit.cover,
                                          width: 80,
                                          height: 80,
                                          errorBuilder: (ctx, err, stack) =>
                                              const Icon(
                                                Icons.person,
                                                size: 40,
                                                color: TraceColors.medGrey,
                                              ),
                                        )
                                      : Image.network(
                                          widget.result.studentAvatarUrl!,
                                          fit: BoxFit.cover,
                                          width: 80,
                                          height: 80,
                                          errorBuilder: (ctx, err, stack) =>
                                              const Icon(
                                                Icons.person,
                                                size: 40,
                                                color: TraceColors.medGrey,
                                              ),
                                        ))
                                : const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: TraceColors.medGrey,
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: config.iconBg,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: TraceColors.white,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              config.icon,
                              size: 16,
                              color: config.iconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Status label
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: config.iconBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        config.label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: config.iconColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Student name
                    if (widget.result.studentName != null) ...[
                      Text(
                        widget.result.studentName!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: TraceColors.navyBlue,
                        ),
                      ),
                      if (widget.result.studentId != null)
                        Text(
                          'ID: ${widget.result.studentId}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: TraceColors.medGrey,
                          ),
                        ),
                    ],
                    // Timestamp
                    if (widget.result.timestamp != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: TraceColors.offWhite,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: TraceColors.royalBlue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(widget.result.timestamp!),
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: TraceColors.royalBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Custom message
                    if (widget.result.message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.result.message!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: TraceColors.medGrey,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onContinue();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: config.borderColor,
                          foregroundColor: config.buttonTextColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Continue Scanning',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onVoid != null &&
                  widget.result.attendanceDocId != null)
                Positioned(
                  top: 12,
                  right: 12,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onVoid!();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: TraceColors.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.undo_rounded, size: 16),
                    label: Text(
                      'Void',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m:$s $period';
  }

  _ModalConfig _getConfig() {
    switch (widget.result.status) {
      case ScanResultStatus.timeInSuccess:
        return _ModalConfig(
          icon: Icons.check_circle_rounded,
          iconColor: TraceColors.success,
          iconBg: TraceColors.successLight,
          borderColor: TraceColors.success,
          label: '✓ TIME-IN RECORDED',
          buttonTextColor: TraceColors.white,
        );
      case ScanResultStatus.timeOutSuccess:
        return _ModalConfig(
          icon: Icons.logout_rounded,
          iconColor: TraceColors.royalBlue,
          iconBg: const Color(0xFFE3F2FD),
          borderColor: TraceColors.royalBlue,
          label: '✓ TIME-OUT RECORDED',
          buttonTextColor: TraceColors.white,
        );
      case ScanResultStatus.lateEntry:
        return _ModalConfig(
          icon: Icons.schedule_rounded,
          iconColor: TraceColors.late,
          iconBg: TraceColors.lateLight,
          borderColor: TraceColors.late,
          label: '⏰ LATE ENTRY',
          buttonTextColor: TraceColors.navyBlue,
        );
      case ScanResultStatus.attendanceComplete:
        return _ModalConfig(
          icon: Icons.workspace_premium_rounded,
          iconColor: TraceColors.darkGold,
          iconBg: TraceColors.lateLight,
          borderColor: TraceColors.gold,
          label: '🏆 ATTENDANCE COMPLETE',
          buttonTextColor: TraceColors.navyBlue,
        );
      case ScanResultStatus.alreadyTimedIn:
        return _ModalConfig(
          icon: Icons.warning_amber_rounded,
          iconColor: TraceColors.warning,
          iconBg: TraceColors.warningLight,
          borderColor: TraceColors.warning,
          label: '⚠ ALREADY TIMED IN',
          buttonTextColor: TraceColors.white,
        );
      case ScanResultStatus.alreadyTimedOut:
        return _ModalConfig(
          icon: Icons.warning_amber_rounded,
          iconColor: TraceColors.warning,
          iconBg: TraceColors.warningLight,
          borderColor: TraceColors.warning,
          label: '⚠ ALREADY TIMED OUT',
          buttonTextColor: TraceColors.white,
        );
      case ScanResultStatus.studentNotFound:
        return _ModalConfig(
          icon: Icons.person_off_rounded,
          iconColor: TraceColors.error,
          iconBg: TraceColors.errorLight,
          borderColor: TraceColors.error,
          label: '✕ STUDENT NOT FOUND',
          buttonTextColor: TraceColors.white,
        );
      case ScanResultStatus.eventNotActive:
        return _ModalConfig(
          icon: Icons.event_busy_rounded,
          iconColor: TraceColors.error,
          iconBg: TraceColors.errorLight,
          borderColor: TraceColors.error,
          label: '✕ NO ACTIVE EVENT',
          buttonTextColor: TraceColors.white,
        );
      case ScanResultStatus.wrongPhase:
        return _ModalConfig(
          icon: Icons.block_rounded,
          iconColor: TraceColors.error,
          iconBg: TraceColors.errorLight,
          borderColor: TraceColors.error,
          label: '✕ WRONG SCAN PHASE',
          buttonTextColor: TraceColors.white,
        );
      case ScanResultStatus.error:
        return _ModalConfig(
          icon: Icons.error_outline_rounded,
          iconColor: TraceColors.error,
          iconBg: TraceColors.errorLight,
          borderColor: TraceColors.error,
          label: '✕ SCAN ERROR',
          buttonTextColor: TraceColors.white,
        );
    }
  }
}

class _ModalConfig {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color borderColor;
  final String label;
  final Color buttonTextColor;

  _ModalConfig({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.borderColor,
    required this.label,
    required this.buttonTextColor,
  });
}
