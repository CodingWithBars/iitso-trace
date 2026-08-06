import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';

class StatsBar extends StatelessWidget {
  const StatsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService.db.collection('students').snapshots(),
      builder: (ctx, studentSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService.db.collection('events').snapshots(),
          builder: (ctx, eventSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirestoreService.db.collection('funds').snapshots(),
              builder: (ctx, fundsSnap) {
                final studentCount = studentSnap.hasData
                    ? studentSnap.data!.docs.length
                    : 0;
                final eventCount = eventSnap.hasData
                    ? eventSnap.data!.docs.length
                    : 0;

                double totalIncome = 0;
                if (fundsSnap.hasData) {
                  for (final d in fundsSnap.data!.docs) {
                    final data = d.data() as Map<String, dynamic>;
                    if (data['type'] == 'income' ||
                        data['type'] == 'contribution') {
                      totalIncome += (data['amount'] ?? 0).toDouble();
                    }
                  }
                }

                return Container(
                  color: TraceColors.navyBlue,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _statItem(studentCount.toString(), 'Students'),
                      ),
                      _statDivider(),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => TraceColors
                                    .goldGradient
                                    .createShader(bounds),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '₱${_formatAmount(totalIncome)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total Collected',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: TraceColors.white.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _statDivider(),
                      Expanded(
                        child: _statItem(eventCount.toString(), 'Events\nHeld'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _statItem(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                TraceColors.goldGradient.createShader(bounds),
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: TraceColors.white.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      height: 36,
      color: TraceColors.white.withValues(alpha: 0.1),
    );
  }

  String _formatAmount(double amount) {
    return NumberFormat('#,##0.00', 'en_US').format(amount);
  }
}
