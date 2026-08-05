import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import 'web_landing_helpers.dart';

class StatsBar extends StatelessWidget {
  const StatsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('students').snapshots(),
      builder: (_, studentSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('events').snapshots(),
          builder: (_, eventSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('funds')
                  .snapshots(),
              builder: (_, fundsSnap) {
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

                return LayoutBuilder(
                  builder: (ctx, constraints) {
                    final isWide = constraints.maxWidth > 600;
                    return Container(
                      color: TraceColors.navyBlue,
                      padding: EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: isWide ? 80 : 24,
                      ),
                      child: isWide
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _statItem(
                                  studentCount.toString(),
                                  'Registered Students',
                                  Icons.people_rounded,
                                ),
                                _vDivider(),
                                _statItem(
                                  '₱${formatAmount(totalIncome)}',
                                  'Total Collected',
                                  Icons.monetization_on_rounded,
                                ),
                                _vDivider(),
                                _statItem(
                                  eventCount.toString(),
                                  'Events Held',
                                  Icons.event_rounded,
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _statItem(
                                      studentCount.toString(),
                                      'Students',
                                      Icons.people_rounded,
                                    ),
                                    _vDivider(),
                                    _statItem(
                                      eventCount.toString(),
                                      'Events',
                                      Icons.event_rounded,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _statItem(
                                  '₱${formatAmount(totalIncome)}',
                                  'Total Collected',
                                  Icons.monetization_on_rounded,
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
      },
    );
  }

  Widget _statItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: TraceColors.gold.withValues(alpha: 0.7), size: 18),
        const SizedBox(height: 6),
        ShaderMask(
          shaderCallback: (b) => TraceColors.goldGradient.createShader(b),
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _vDivider() {
    return Container(
      width: 1,
      height: 44,
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}
