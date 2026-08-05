import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

Widget buildSectionHeader(String title, Color color) {
  return Row(
    children: [
      Container(
        width: 4,
        height: 28,
        decoration: const BoxDecoration(gradient: TraceColors.goldGradient),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    ],
  );
}

Widget buildEmptyState(String message, IconData icon) {
  return Container(
    padding: const EdgeInsets.all(40),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: TraceColors.lightGrey.withValues(alpha: 0.5)),
    ),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 44, color: TraceColors.lightGrey),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.inter(color: TraceColors.medGrey, fontSize: 14),
          ),
        ],
      ),
    ),
  );
}

Widget buildBannerImage(String url, {BoxFit fit = BoxFit.cover}) {
  if (url.startsWith('data:image')) {
    try {
      final base64Str = url.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        fit: fit,
        width: double.infinity,
      );
    } catch (_) {
      return Container(color: TraceColors.lightGrey);
    }
  }
  return Image.network(
    url,
    fit: fit,
    width: double.infinity,
    errorBuilder: (ctx, e, s) => Container(color: TraceColors.lightGrey),
  );
}

String formatDate(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

String formatDateShort(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}';
}

String formatAmount(double amount) {
  return NumberFormat('#,##0.00', 'en_US').format(amount);
}
