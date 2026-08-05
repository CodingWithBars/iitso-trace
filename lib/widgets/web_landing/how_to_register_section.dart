import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'web_landing_helpers.dart';

class HowToRegisterSection extends StatelessWidget {
  const HowToRegisterSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    final hPad = isWide ? 80.0 : 24.0;
    return Container(
      color: TraceColors.white,
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: buildSectionHeader(
              'How to Register & Get Your QR Code',
              TraceColors.navyBlue,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Text(
              'Follow these 5 simple steps to register your account and generate your official Trace QR Code.',
              style: GoogleFonts.inter(
                color: TraceColors.medGrey,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 48),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: Row(
              children: List.generate(5, (index) {
                final stepNum = index + 1;
                return Padding(
                  padding: const EdgeInsets.only(right: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        height: 500, // Fixed height for screenshots
                        decoration: BoxDecoration(
                          color: TraceColors.offWhite,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: TraceColors.lightGrey.withValues(alpha: 0.5),
                          ),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: Image.asset(
                          'assets/$stepNum.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: TraceColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: TraceColors.gold.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          'STEP $stepNum',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: TraceColors.navyBlue,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
