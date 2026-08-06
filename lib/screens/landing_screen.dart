import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/student_session_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/auth_service.dart';

import '../widgets/landing/hero_section.dart';
import '../widgets/landing/stats_bar.dart';
import '../widgets/landing/announcements_section.dart';
import '../widgets/landing/transparency_section.dart';
import '../widgets/landing/landing_footer.dart';
import '../widgets/web_landing/events_section.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final authService = ref.watch(authServiceProvider);
    final isAdmin = authService.isLoggedIn;

    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: TraceAppBar(
        showBackButton: false,
        actions: [
          if (!kIsWeb) ...[
            if (isAdmin)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () => context.push('/admin/dashboard'),
                  icon: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: TraceColors.gold,
                    size: 20,
                  ),
                  tooltip: 'Admin Dashboard',
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Consumer(
                  builder: (context, ref, _) {
                    final sessionAsync = ref.watch(studentSessionProvider);
                    final studentId = sessionAsync.valueOrNull;
                    final isLoggedIn =
                        studentId != null && studentId.isNotEmpty;

                    return TextButton.icon(
                      onPressed: () {
                        if (isLoggedIn) {
                          context.push('/student/id/$studentId');
                        } else {
                          context.push('/student-login');
                        }
                      },
                      icon: Icon(
                        isLoggedIn ? Icons.badge_outlined : Icons.login,
                        color: TraceColors.gold,
                        size: 18,
                      ),
                      label: Text(
                        isLoggedIn ? 'My ID' : 'Login',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFD700),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          child: Column(
            children: [
              HeroSection(isWide: isWide),
              const StatsBar(),
              const EventsSection(),
              AnnouncementsSection(isWide: isWide),
              TransparencySection(isWide: isWide),
              const LandingFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
