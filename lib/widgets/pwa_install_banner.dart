import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../utils/pwa_helper.dart';

class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  bool _isDismissed = false;
  bool _isInstalled = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _checkPwaStatus();
    }
  }

  void _checkPwaStatus() {
    try {
      if (isPwaInstalled()) {
        setState(() => _isInstalled = true);
      }
    } catch (_) {}
  }

  Future<void> _triggerInstall() async {
    try {
      final success = await triggerPwaInstall();
      if (success) {
        setState(() {
          _isInstalled = true;
          _isDismissed = true;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _isDismissed || _isInstalled) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TraceColors.navyBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TraceColors.gold.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: TraceColors.navyBlue.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: TraceColors.gold.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.desktop_windows_rounded,
              color: TraceColors.gold,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Install TRACE Web App',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add TRACE to your desktop or device for 1-click quick access.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _triggerInstall,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Install'),
            style: ElevatedButton.styleFrom(
              backgroundColor: TraceColors.gold,
              foregroundColor: TraceColors.navyBlue,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => setState(() => _isDismissed = true),
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}
