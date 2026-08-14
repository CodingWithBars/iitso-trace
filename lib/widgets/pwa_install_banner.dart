import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../utils/pwa_helper.dart';

class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  bool _isDismissed  = false;
  bool _isInstalled  = false;
  bool _canInstall   = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _checkPwaStatus();
      _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) => _checkPwaStatus());
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _checkPwaStatus() {
    if (!mounted) return;
    try {
      final installed = isPwaInstalled();
      final hasPrompt = hasNativePwaPrompt();
      final ios = isIOSPlatform();
      
      final canInstall = hasPrompt || ios;
      
      if (installed != _isInstalled || canInstall != _canInstall) {
        setState(() {
          _isInstalled = installed;
          _canInstall = canInstall;
        });
      }
    } catch (_) {}
  }

  Future<void> _triggerInstall() async {
    // ── Android / Desktop Chrome: try native prompt first ─────────────
    if (hasNativePwaPrompt()) {
      try {
        final success = await triggerPwaInstall();
        if (success && mounted) {
          setState(() {
            _isInstalled = true;
            _isDismissed = true;
          });
          return;
        }
      } catch (_) {}
    }

    // ── iOS or unsupported native prompt: show manual guide ───────────
    if (!mounted) return;
    final isIOS     = isIOSPlatform();
    final isAndroid = isAndroidPlatform();
    _showInstallGuide(isIOS: isIOS, isAndroid: isAndroid);
  }

  void _showInstallGuide({required bool isIOS, required bool isAndroid}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _InstallGuideSheet(isIOS: isIOS, isAndroid: isAndroid),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _isDismissed || _isInstalled || !_canInstall) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: TraceColors.navyBlue,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: TraceColors.gold.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: TraceColors.gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_android_rounded,
                color: TraceColors.gold,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Install TRACE',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Add to your home screen for quick access.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.white60,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Install button
            ElevatedButton(
              onPressed: _triggerInstall,
              style: ElevatedButton.styleFrom(
                backgroundColor: TraceColors.gold,
                foregroundColor: TraceColors.navyBlue,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: const Size(70, 38),
              ),
              child: const Text('Install'),
            ),
            // Dismiss
            IconButton(
              onPressed: () => setState(() => _isDismissed = true),
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white54,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Install Guide Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _InstallGuideSheet extends StatelessWidget {
  final bool isIOS;
  final bool isAndroid;

  const _InstallGuideSheet({required this.isIOS, required this.isAndroid});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: TraceColors.navyBlue,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: TraceColors.gold.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: TraceColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_to_home_screen_rounded,
                        color: TraceColors.gold,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Install TRACE',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            isIOS
                                ? 'Add to iPhone / iPad Home Screen'
                                : 'Add to Android Home Screen',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                if (isIOS) ..._iosSteps() else ..._androidSteps(),

                const SizedBox(height: 20),

                // Note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: TraceColors.gold,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isIOS
                              ? 'Open this site in Safari for the best experience.'
                              : 'Works best in Chrome or Edge.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TraceColors.gold,
                      foregroundColor: TraceColors.navyBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Got it!'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  List<Widget> _iosSteps() => [
    _GuideStep(
      stepNumber: 1,
      icon: Icons.ios_share_rounded,
      iconColor: const Color(0xFF007AFF),
      title: 'Tap the Share button',
      subtitle: 'At the bottom of your Safari browser.',
    ),
    _GuideStep(
      stepNumber: 2,
      icon: Icons.add_box_outlined,
      iconColor: TraceColors.gold,
      title: 'Tap "Add to Home Screen"',
      subtitle: 'Scroll down in the Share menu to find it.',
    ),
    _GuideStep(
      stepNumber: 3,
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF34C759),
      title: 'Tap "Add"',
      subtitle: 'TRACE will appear on your home screen like a native app.',
    ),
  ];

  List<Widget> _androidSteps() => [
    _GuideStep(
      stepNumber: 1,
      icon: Icons.more_vert_rounded,
      iconColor: const Color(0xFF4285F4),
      title: 'Tap the Menu (⋮)',
      subtitle: 'Top-right corner of your browser.',
    ),
    _GuideStep(
      stepNumber: 2,
      icon: Icons.add_to_home_screen_rounded,
      iconColor: TraceColors.gold,
      title: 'Tap "Add to Home screen"',
      subtitle: 'Also shown as "Install app" on some browsers.',
    ),
    _GuideStep(
      stepNumber: 3,
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF34C759),
      title: 'Tap "Add" to confirm',
      subtitle: 'TRACE will be installed on your device.',
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Single Step Item
// ─────────────────────────────────────────────────────────────────────────────

class _GuideStep extends StatelessWidget {
  final int    stepNumber;
  final IconData icon;
  final Color  iconColor;
  final String title;
  final String subtitle;

  const _GuideStep({
    required this.stepNumber,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number bubble
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: TraceColors.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: TraceColors.gold.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                '$stepNumber',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: TraceColors.gold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
