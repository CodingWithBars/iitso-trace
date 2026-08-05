import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../shared_widgets.dart';

class LandingFooter extends StatelessWidget {
  const LandingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: TraceColors.black,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      child: Column(
        children: [
          const GoldDivider(),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              ShaderMask(
                shaderCallback: (b) => TraceColors.goldGradient.createShader(b),
                child: Text(
                  'TRACE',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Transparent Records & Attendance for Campus Events',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: TraceColors.white.withValues(alpha: 0.35),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Built by students, for students.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: TraceColors.white.withValues(alpha: 0.3),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => context.push('/privacy-policy'),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Privacy Policy',
                  style: GoogleFonts.inter(
                    color: TraceColors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '•',
                  style: TextStyle(
                    color: TraceColors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/terms-conditions'),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Terms & Conditions',
                  style: GoogleFonts.inter(
                    color: TraceColors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Copyright © 2026 trace. All rights reserved.',
            style: GoogleFonts.inter(
              color: TraceColors.white.withValues(alpha: 0.25),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
