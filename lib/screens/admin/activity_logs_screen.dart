import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_theme.dart';
import '../../../services/activity_log_service.dart';
import '../../../services/auth_service.dart';
import 'package:intl/intl.dart';

class ActivityLogsScreen extends ConsumerStatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  ConsumerState<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends ConsumerState<ActivityLogsScreen> {
  String _searchQuery = '';
  String _sortBy = 'Newest';
  String _filterAction = 'All';
  bool _canDelete = false;

  int _currentLimit = 50;
  late Stream<QuerySnapshot> _logsStream;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _logsStream = ActivityLogService.stream(limit: _currentLimit);
    _scrollController.addListener(_onScroll);
    _checkRole();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Load more
      setState(() {
        _currentLimit += 50;
        _logsStream = ActivityLogService.stream(limit: _currentLimit);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkRole() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user != null) {
      final doc = await FirestoreService.admins.doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['role'] == 'superadmin') {
          if (mounted) setState(() => _canDelete = true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TraceColors.offWhite,
      appBar: AppBar(
        title: Text(
          'Activity Logs',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: TraceColors.white,
          ),
        ),
        backgroundColor: TraceColors.navyBlue,
        iconTheme: const IconThemeData(color: TraceColors.white),
        actions: [
          if (_canDelete)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear All Logs',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Clear All Logs?'),
                    content: const Text(
                      'Are you sure you want to permanently delete ALL activity logs? This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text(
                          'Clear All',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final snapshot = await FirestoreService.db
                      .collection('activity_logs')
                      .get();
                  for (var doc in snapshot.docs) {
                    doc.reference.delete();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All logs cleared.')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _logsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: TraceColors.navyBlue),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No activity logs found.',
                style: GoogleFonts.inter(color: TraceColors.medGrey),
              ),
            );
          }

          final allDocs = snapshot.data!.docs;

          // Extract unique actions for dynamic dropdown
          final Set<String> logTypes = {'All'};
          for (var doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final action = data['action'] as String?;
            if (action != null && action.isNotEmpty) {
              // Convert action like 'event_created' to 'Event Created'
              final formattedAction = action
                  .split('_')
                  .map(
                    (w) => w.isNotEmpty
                        ? '${w[0].toUpperCase()}${w.substring(1)}'
                        : '',
                  )
                  .join(' ');
              logTypes.add(formattedAction);
            }
          }

          var filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;

            // Search filter
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final message = (data['message'] ?? '').toString().toLowerCase();
              final actor = (data['actor_name'] ?? '').toString().toLowerCase();
              final action = (data['action'] ?? '').toString().toLowerCase();
              if (!message.contains(q) &&
                  !actor.contains(q) &&
                  !action.contains(q)) {
                return false;
              }
            }

            // Action filter
            if (_filterAction != 'All') {
              final action = data['action'] as String?;
              if (action == null) return false;
              final formattedAction = action
                  .split('_')
                  .map(
                    (w) => w.isNotEmpty
                        ? '${w[0].toUpperCase()}${w.substring(1)}'
                        : '',
                  )
                  .join(' ');
              if (formattedAction != _filterAction) {
                return false;
              }
            }

            return true;
          }).toList();

          // Sort
          filteredDocs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final timeA =
                (dataA['timestamp'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final timeB =
                (dataB['timestamp'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);

            if (_sortBy == 'Oldest') {
              return timeA.compareTo(timeB);
            } else {
              return timeB.compareTo(timeA);
            }
          });

          String formatLogMessage(String msg) {
            final reg = RegExp(r'₱(\d+)(?:\.(\d+))?');
            return msg.replaceAllMapped(reg, (match) {
              final wholeStr = match.group(1)!;
              final decStr = match.group(2);
              final wholeNum = int.tryParse(wholeStr) ?? 0;
              final format = NumberFormat('#,##0');
              final formattedWhole = format.format(wholeNum);
              if (decStr != null) {
                return '₱$formattedWhole.$decStr';
              } else {
                return '₱$formattedWhole.00';
              }
            });
          }

          return Column(
            children: [
              // Filters Section
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search logs (keywords, actor, action)...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 16,
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: logTypes.contains(_filterAction)
                                    ? _filterAction
                                    : 'All',
                                icon: const Icon(
                                  Icons.filter_list_rounded,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                                items: logTypes
                                    .map(
                                      (type) => DropdownMenuItem(
                                        value: type,
                                        child: Text(
                                          type,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) => setState(
                                  () => _filterAction = val ?? 'All',
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortBy,
                              icon: const Icon(
                                Icons.sort_rounded,
                                size: 20,
                                color: Colors.grey,
                              ),
                              items: ['Newest', 'Oldest']
                                  .map(
                                    (sort) => DropdownMenuItem(
                                      value: sort,
                                      child: Text(
                                        sort,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _sortBy = val ?? 'Newest'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: TraceColors.lightGrey,
              ),

              // List Section
              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                        child: Text(
                          'No logs match your search.',
                          style: GoogleFonts.inter(color: TraceColors.medGrey),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredDocs.length + (filteredDocs.length >= _currentLimit ? 1 : 0),
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          color: TraceColors.lightGrey,
                        ),
                        itemBuilder: (context, index) {
                          if (index == filteredDocs.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: CircularProgressIndicator(color: TraceColors.navyBlue),
                              ),
                            );
                          }

                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final timestamp = data['timestamp'] as Timestamp?;
                          final timeString = timestamp != null
                              ? DateFormat(
                                  'MMM d, yyyy • h:mm a',
                                ).format(timestamp.toDate())
                              : 'Just now';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.history_rounded,
                                  size: 24,
                                  color: TraceColors.medGrey.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        formatLogMessage(
                                          data['message'] ?? 'Unknown action',
                                        ),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: TraceColors.navyBlue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$timeString • by ${data['actor_name'] ?? 'System'}',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: TraceColors.medGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_canDelete)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: TraceColors.error,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title: const Text('Delete Log?'),
                                          content: const Text(
                                            'Are you sure you want to delete this activity log?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, false),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, true),
                                              child: const Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        doc.reference.delete();
                                      }
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
