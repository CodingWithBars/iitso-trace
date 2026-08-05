import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  static const String _apkUrl = 'https://tinyurl.com/mtptean6';

  void _launchApkDownload() async {
    final uri = Uri.parse(_apkUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1B3E), Color(0xFF1A3A7C), Color(0xFF0D1B3E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(top: -60, right: -60, child: _decorCircle(220, 0.08)),
          Positioned(bottom: -80, left: -80, child: _decorCircle(280, 0.05)),
          Positioned(
            top: 40,
            right: isWide ? 400 : -40,
            child: _decorCircle(120, 0.06),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 80 : 24,
              vertical: isWide ? 100 : 64,
            ),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildHeroContent(context, isWide: true),
                      ),
                      const SizedBox(width: 60),
                      Expanded(
                        flex: 4,
                        child: Image.asset(
                          'assets/hero-image.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset('assets/hero-image.png', fit: BoxFit.contain),
                      const SizedBox(height: 48),
                      _buildHeroContent(context, isWide: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _decorCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: TraceColors.gold.withValues(alpha: opacity),
          width: size / 5,
        ),
      ),
    );
  }

  Widget _buildHeroContent(BuildContext context, {required bool isWide}) {
    return Column(
      crossAxisAlignment: isWide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          'Transparent Records\n& Attendance for\nCampus Events',
          textAlign: isWide ? TextAlign.left : TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: isWide ? 52 : 34,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'A modern, real-time system for student attendance tracking,\nevent management, and full financial transparency.',
          textAlign: isWide ? TextAlign.left : TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: isWide ? 16 : 14,
            color: Colors.white.withValues(alpha: 0.65),
            height: 1.65,
          ),
        ),
        const SizedBox(height: 40),
        // CTA Buttons
        Wrap(
          alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.go('/student-login'),
                child: SizedBox(
                  width: 250,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: TraceColors.gold,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: TraceColors.gold.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.login_rounded,
                          color: TraceColors.navyBlue,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Login',
                          style: GoogleFonts.inter(
                            color: TraceColors.navyBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _launchApkDownload,
                child: SizedBox(
                  width: 250,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFF5A623)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: TraceColors.gold.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.android_rounded,
                          color: Color(0xFF0D1B3E),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Download trace',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF0D1B3E),
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Feature pills
        Wrap(
          alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            _featurePill(Icons.qr_code_2_rounded, 'QR Code ID'),
            _featurePill(Icons.visibility_rounded, 'Live Attendance'),
            _featurePill(
              Icons.account_balance_wallet_rounded,
              'Finance Ledger',
            ),
          ],
        ),
      ],
    );
  }

  Widget _featurePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
