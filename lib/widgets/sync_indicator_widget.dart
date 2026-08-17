import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/network_service.dart';
import '../theme/app_theme.dart';

class SyncIndicatorWidget extends StatefulWidget {
  const SyncIndicatorWidget({super.key});

  @override
  State<SyncIndicatorWidget> createState() => _SyncIndicatorWidgetState();
}

class _SyncIndicatorWidgetState extends State<SyncIndicatorWidget> {
  bool _isSyncing = false;

  Future<void> _forceSync() async {
    setState(() => _isSyncing = true);
    try {
      // Disable and re-enable network to force Firestore to push local queue
      await FirebaseFirestore.instance.disableNetwork();
      await Future.delayed(const Duration(milliseconds: 500));
      await FirebaseFirestore.instance.enableNetwork();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync complete! Database is up to date.'),
            backgroundColor: TraceColors.royalBlue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: TraceColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: NetworkService.onOfflineStateChanged,
      initialData: NetworkService().isOffline,
      builder: (context, snapshot) {
        final isOffline = snapshot.data ?? false;

        return GestureDetector(
          onTap: isOffline || _isSyncing ? null : _forceSync,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: TraceColors.navyBlue,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: TraceColors.navyBlue.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSyncing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                else
                  Icon(
                    isOffline ? Icons.cloud_off_rounded : Icons.cloud_sync_rounded,
                    color: isOffline ? TraceColors.gold : TraceColors.gold,
                    size: 18,
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isOffline ? 'Offline' : (_isSyncing ? 'Syncing...' : 'Sync Data'),
                    style: GoogleFonts.inter(
                      color: TraceColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
