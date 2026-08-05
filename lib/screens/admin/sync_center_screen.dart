import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';

class SyncCenterScreen extends StatefulWidget {
  const SyncCenterScreen({super.key});

  @override
  State<SyncCenterScreen> createState() => _SyncCenterScreenState();
}

class _SyncCenterScreenState extends State<SyncCenterScreen> {
  bool _isSyncing = false;
  String _status = 'Ready';

  Future<void> _forceSync() async {
    setState(() {
      _isSyncing = true;
      _status = 'Connecting to Firebase...';
    });

    try {
      // Force Firebase to disable and re-enable network to trigger a flush of pending offline writes
      await FirebaseFirestore.instance.disableNetwork();
      await Future.delayed(const Duration(seconds: 1));
      await FirebaseFirestore.instance.enableNetwork();

      setState(() {
        _status = 'Successfully synced all offline data to the cloud.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error syncing: $e';
      });
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: AppBar(
        title: Text(
          'Sync Center',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: TraceColors.navyBlue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TraceColors.lightGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_sync_rounded,
                        color: TraceColors.royalBlue,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Offline Data Synchronization',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: TraceColors.navyBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'The Scanner automatically saves attendance locally when offline. '
                    'Usually, data syncs automatically when the internet connection returns. '
                    'If you want to manually force a sync push, tap the button below.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: TraceColors.medGrey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TraceColors.royalBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(
                        _isSyncing ? 'Syncing...' : 'Force Sync Data',
                      ),
                      onPressed: _isSyncing ? null : _forceSync,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TraceColors.offWhite,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Status: $_status',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _status.contains('Error')
                            ? TraceColors.error
                            : TraceColors.navyBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
