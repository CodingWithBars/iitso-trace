import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';

class FooterSection extends StatelessWidget {
  const FooterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF060D1F),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 32),
      child: Column(
        children: [
          Container(
            height: 1,
            decoration: const BoxDecoration(gradient: TraceColors.goldGradient),
          ),
          const SizedBox(height: 28),
          ShaderMask(
            shaderCallback: (b) => TraceColors.goldGradient.createShader(b),
            child: Text(
              'TRACE',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Transparent Records & Attendance for Campus Events',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Built by students, for students.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _footerLink(context, 'Privacy Policy', '/privacy-policy'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '•',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                ),
              ),
              _footerLink(context, 'Terms & Conditions', '/terms-conditions'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Copyright © 2026 trace. All rights reserved.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerLink(BuildContext context, String label, String route) {
    return TextButton(
      onPressed: () => context.push(route),
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 12,
        ),
      ),
    );
  }
}
