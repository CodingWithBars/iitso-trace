import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class TraceAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? actions;
  final bool showBackButton;
  final Widget? leading;
  final double elevation;
  final bool centerTitle;

  const TraceAppBar({
    super.key,
    this.title,
    this.actions,
    this.showBackButton = true,
    this.leading,
    this.elevation = 0,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: TraceColors.navyBlue,
      foregroundColor: TraceColors.white,
      elevation: elevation,
      centerTitle: centerTitle,
      automaticallyImplyLeading: showBackButton,
      leading: leading,
      title: (title == null || title == 'TRACE')
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [Image.asset('assets/trace-logo3.png', height: 26)],
            )
          : Text(
              title!,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: TraceColors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(2),
        child: Container(
          height: 2,
          decoration: const BoxDecoration(gradient: TraceColors.goldGradient),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 2);
}

class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const GoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: TraceColors.gold,
        foregroundColor: TraceColors.navyBlue,
        elevation: 3,
        shadowColor: TraceColors.gold.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: TraceColors.navyBlue,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );

    if (fullWidth) return SizedBox(width: double.infinity, child: button);
    return button;
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.textColor = Colors.white,
  });

  factory StatusChip.fromStatus(String status) {
    switch (status.toLowerCase()) {
      // New canonical statuses
      case 'present':
        return StatusChip(label: 'Present', color: TraceColors.success);
      case 'incomplete':
        return StatusChip(label: 'Incomplete', color: TraceColors.warning);
      case 'absent':
        return StatusChip(label: 'Absent', color: TraceColors.error);
      case 'late':
        return StatusChip(
          label: 'Late',
          color: TraceColors.darkGold,
          textColor: TraceColors.navyBlue,
        );
      // Legacy statuses (backward compat for existing records)
      case 'complete':
      case 'whole_day_complete':
      case 'morning_complete':
      case 'pm_complete':
        return StatusChip(label: 'Present', color: TraceColors.success);
      case 'partial':
      case 'morning_in':
      case 'pm_in':
        return StatusChip(label: 'Incomplete', color: TraceColors.warning);
      case 'late entry':
        return StatusChip(
          label: 'Late',
          color: TraceColors.darkGold,
          textColor: TraceColors.navyBlue,
        );
      // Event statuses
      case 'upcoming':
        return StatusChip(label: 'Upcoming', color: TraceColors.medGrey);
      case 'ongoing':
        return StatusChip(label: 'Ongoing', color: TraceColors.success);
      case 'completed':
        return StatusChip(
          label: 'Completed',
          color: TraceColors.darkGold,
          textColor: TraceColors.navyBlue,
        );
      case 're-scheduled':
        return StatusChip(label: 'Re-Scheduled', color: TraceColors.warning);
      case 'cancelled':
        return StatusChip(label: 'Cancelled', color: TraceColors.error);
      default:
        return StatusChip(label: status, color: TraceColors.medGrey);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class GoldDivider extends StatelessWidget {
  const GoldDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: const BoxDecoration(gradient: TraceColors.goldGradient),
    );
  }
}

class TraceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool hasBorder;
  final VoidCallback? onTap;

  const TraceCard({
    super.key,
    required this.child,
    this.padding,
    this.hasBorder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TraceColors.white,
            borderRadius: BorderRadius.circular(16),
            border: hasBorder
                ? Border.all(color: TraceColors.gold, width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: TraceColors.royalBlue.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
