import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Wraps any screen in a sleek centered mobile container on Desktop Web viewports (> 520px),
/// while automatically expanding to 100% full width on mobile phone screens (<= 520px).
class DesktopMobileWrapper extends StatelessWidget {
  final Widget child;
  final String? title;
  final bool showFrameHeader;

  const DesktopMobileWrapper({
    super.key,
    required this.child,
    this.title,
    this.showFrameHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Mobile viewports fill 100% width
        if (constraints.maxWidth <= 540) {
          return child;
        }

        // Desktop / Laptop viewports display centered mobile app container
        return Scaffold(
          backgroundColor: const Color(0xFF070E22), // Deep Navy background for desktop canvas
          body: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              constraints: const BoxConstraints(
                maxWidth: 480,
                maxHeight: 900,
              ),
              decoration: BoxDecoration(
                color: TraceColors.offWhite,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 32,
                    spreadRadius: 2,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: TraceColors.gold.withValues(alpha: 0.15),
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
