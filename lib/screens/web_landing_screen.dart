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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/student_session_service.dart';
import '../services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Web-Only Marketing / Public Landing Page
// Only shown when kIsWeb == true (enforced via routes.dart redirect)
// ─────────────────────────────────────────────────────────────────────────────

import '../widgets/pwa_install_banner.dart';

class WebLandingScreen extends ConsumerStatefulWidget {
  const WebLandingScreen({super.key});

  @override
  ConsumerState<WebLandingScreen> createState() => _WebLandingScreenState();
}

class _WebLandingScreenState extends ConsumerState<WebLandingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      bottomNavigationBar: const PwaInstallBanner(),
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
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 700;
    final isSmallMobile = width < 420;

    final sessionAsync = ref.watch(studentSessionProvider);
    final studentId = sessionAsync.valueOrNull;
    final isLoggedInStudent = studentId != null && studentId.isNotEmpty;
    final isAdmin = ref.watch(authServiceProvider).isLoggedIn;

    return Container(
      color: TraceColors.navyBlue,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : (isSmallMobile ? 12 : 20),
        vertical: 14,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go('/'),
            child: ShaderMask(
              shaderCallback: (b) => TraceColors.goldGradient.createShader(b),
              child: Text(
                'trace',
                style: GoogleFonts.inter(
                  fontSize: isSmallMobile ? 20 : 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAdmin) ...[
                      TextButton.icon(
                        onPressed: () => context.push('/admin/dashboard'),
                        icon: const Icon(
                          Icons.admin_panel_settings_outlined,
                          color: TraceColors.gold,
                          size: 18,
                        ),
                        label: Text(
                          isSmallMobile ? 'Admin' : 'Admin Portal',
                          style: GoogleFonts.inter(
                            color: TraceColors.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: isSmallMobile ? 11 : 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (isLoggedInStudent) ...[
                      TextButton.icon(
                        onPressed: () => context.push('/student/summary/$studentId'),
                        icon: const Icon(
                          Icons.space_dashboard_rounded,
                          color: TraceColors.gold,
                          size: 18,
                        ),
                        label: Text(
                          isSmallMobile ? 'Portal' : 'Student Portal',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFFD700),
                            fontWeight: FontWeight.w700,
                            fontSize: isSmallMobile ? 12 : 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => context.push('/student/id/$studentId'),
                        icon: const Icon(
                          Icons.badge_outlined,
                          color: TraceColors.gold,
                          size: 18,
                        ),
                        label: Text(
                          'My ID',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFFD700),
                            fontWeight: FontWeight.w800,
                            fontSize: isSmallMobile ? 12 : 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (!isLoggedInStudent && !isAdmin) ...[
                      TextButton.icon(
                        onPressed: () => context.go('/student-login'),
                        icon: const Icon(
                          Icons.login_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: Text(
                          'Login',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: isSmallMobile ? 12 : 13,
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallMobile ? 4 : 10),
                      _registerButton(context, small: !isWide || isSmallMobile),
                    ],
                  ],
                ),
              ),
            ),
          ),
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
            horizontal: small ? 10 : 16,
            vertical: small ? 7 : 9,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFF5A623)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: TraceColors.gold.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.person_add_rounded,
                size: 15,
                color: Color(0xFF0D1B3E),
              ),
              SizedBox(width: small ? 3 : 6),
              Text(
                'Register',
                style: GoogleFonts.inter(
                  color: const Color(0xFF0D1B3E),
                  fontWeight: FontWeight.w800,
                  fontSize: small ? 11 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
