import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/web_landing/hero_section.dart';
import '../widgets/web_landing/how_to_register_section.dart';
import '../widgets/web_landing/stats_bar.dart';
import '../widgets/web_landing/events_section.dart';
import '../widgets/web_landing/announcements_section.dart';
import '../widgets/web_landing/transparency_section.dart';
import '../widgets/web_landing/footer_section.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Web-Only Marketing / Public Landing Page
// Only shown when kIsWeb == true (enforced via routes.dart redirect)
// ─────────────────────────────────────────────────────────────────────────────

class WebLandingScreen extends StatefulWidget {
  const WebLandingScreen({super.key});

  @override
  State<WebLandingScreen> createState() => _WebLandingScreenState();
}

class _WebLandingScreenState extends State<WebLandingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      body: SelectionArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildNavbar(context),
              const HeroSection(),
              const HowToRegisterSection(),
              const StatsBar(),
              const EventsSection(),
              const AnnouncementsSection(),
              const TransparencySection(),
              const FooterSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── NAVBAR ────────────────────────────────────────────────────────────────

  Widget _buildNavbar(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    return Container(
      color: TraceColors.navyBlue,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 24, vertical: 16),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => TraceColors.goldGradient.createShader(b),
            child: Text(
              'trace',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const Spacer(),
          _registerButton(context, small: !isWide),
        ],
      ),
    );
  }

  Widget _registerButton(BuildContext context, {bool small = false}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/register'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: small ? 12 : 18,
            vertical: small ? 8 : 10,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFF5A623)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: TraceColors.gold.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_add_rounded,
                size: 16,
                color: Color(0xFF0D1B3E),
              ),
              SizedBox(width: small ? 4 : 6),
              Text(
                'Register',
                style: GoogleFonts.inter(
                  color: const Color(0xFF0D1B3E),
                  fontWeight: FontWeight.w800,
                  fontSize: small ? 12 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
