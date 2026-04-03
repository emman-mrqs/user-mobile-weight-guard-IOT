import 'package:flutter/material.dart';
import 'package:mobile/services/mobile_activity_service.dart';
import 'package:mobile/widget/navbar.dart';

import 'activity_data.dart';
import 'activity_detail_screen.dart';

enum _ActivityFilter {
  all,
  completed,
  cancelled,
  critical,
  warning,
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  _ActivityFilter _selectedFilter = _ActivityFilter.all;

  double _contentBottomInset(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // Keep the last activity card fully visible above the floating bottom navbar.
    return 122 + mediaQuery.padding.bottom;
  }

  @override
  void initState() {
    super.initState();
    if (MobileActivityService.recordsNotifier.value.isEmpty) {
      MobileActivityService.refreshActivities(forceRefresh: true);
    }
  }

  bool _matchesFilter(ActivityRecord record, _ActivityFilter filter) {
    switch (filter) {
      case _ActivityFilter.all:
        return true;
      case _ActivityFilter.completed:
        return record.severity == ActivitySeverity.completed || record.severity == ActivitySeverity.normal;
      case _ActivityFilter.cancelled:
        return record.severity == ActivitySeverity.cancelled;
      case _ActivityFilter.critical:
        return record.severity == ActivitySeverity.critical;
      case _ActivityFilter.warning:
        return record.severity == ActivitySeverity.warning;
    }
  }

  String _filterLabel(_ActivityFilter filter) {
    switch (filter) {
      case _ActivityFilter.all:
        return 'All';
      case _ActivityFilter.completed:
        return 'Completed';
      case _ActivityFilter.cancelled:
        return 'Cancelled';
      case _ActivityFilter.critical:
        return 'Critical';
      case _ActivityFilter.warning:
        return 'Warning';
    }
  }

  IconData _filterIcon(_ActivityFilter filter) {
    switch (filter) {
      case _ActivityFilter.all:
        return Icons.view_agenda_rounded;
      case _ActivityFilter.completed:
        return Icons.check_circle_rounded;
      case _ActivityFilter.cancelled:
        return Icons.cancel_rounded;
      case _ActivityFilter.critical:
        return Icons.error_rounded;
      case _ActivityFilter.warning:
        return Icons.warning_amber_rounded;
    }
  }

  Color _filterColor(_ActivityFilter filter) {
    switch (filter) {
      case _ActivityFilter.all:
        return const Color(0xFF60A5FA);
      case _ActivityFilter.completed:
        return const Color(0xFF4ADE80);
      case _ActivityFilter.cancelled:
        return const Color(0xFF94A3B8);
      case _ActivityFilter.critical:
        return const Color(0xFFEF4444);
      case _ActivityFilter.warning:
        return const Color(0xFFF59E0B);
    }
  }

  String _relativeUpdatedAt(DateTime? updatedAt) {
    if (updatedAt == null) return 'Last updated: --';

    final Duration diff = DateTime.now().difference(updatedAt);
    if (diff.inSeconds < 5) return 'Last updated just now';
    if (diff.inMinutes < 1) return 'Last updated ${diff.inSeconds}s ago';
    if (diff.inHours < 1) return 'Last updated ${diff.inMinutes}m ago';
    return 'Last updated ${diff.inHours}h ago';
  }

  int _counter(Map<String, int> counters, String key) => counters[key] ?? 0;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = _contentBottomInset(context);

    return Container(
      color: const Color(0xFF051E16),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AppNavbar(
                title: 'Activity',
                subtitle: 'Trip alerts, logs, and cargo incident history',
              ),
              const SizedBox(height: 18),
              AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[
                  MobileActivityService.recordsNotifier,
                  MobileActivityService.countersNotifier,
                  MobileActivityService.isLoadingNotifier,
                  MobileActivityService.errorNotifier,
                  MobileActivityService.lastUpdatedNotifier,
                  MobileActivityService.isPollingNotifier,
                ]),
                builder: (context, _) {
                  final records = MobileActivityService.recordsNotifier.value;
                  final counters = MobileActivityService.countersNotifier.value;
                  final bool isLoading = MobileActivityService.isLoadingNotifier.value;
                  final String? error = MobileActivityService.errorNotifier.value;
                  final DateTime? lastUpdated = MobileActivityService.lastUpdatedNotifier.value;
                  final bool isPolling = MobileActivityService.isPollingNotifier.value;

                  final List<ActivityRecord> filteredRecords =
                      records.where((record) => _matchesFilter(record, _selectedFilter)).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C2B22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Quick Filters',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: <Widget>[
                                _LivePulseDot(isActive: isPolling),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    '${_counter(counters, 'all')} logs  •  ${_counter(counters, 'completed')} completed  •  ${_counter(counters, 'warning')} warning  •  ${_counter(counters, 'critical')} critical  •  ${_relativeUpdatedAt(lastUpdated)}',
                                    style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _ActivityFilter.values.map((filter) {
                                final bool isSelected = _selectedFilter == filter;
                                final Color accent = _filterColor(filter);
                                return FilterChip(
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedFilter = filter;
                                    });
                                  },
                                  avatar: Icon(
                                    _filterIcon(filter),
                                    size: 16,
                                    color: isSelected ? accent : Colors.white54,
                                  ),
                                  label: Text(_filterLabel(filter)),
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  selectedColor: accent.withValues(alpha: 0.18),
                                  backgroundColor: const Color(0xFF08241B),
                                  side: BorderSide(
                                    color: isSelected ? accent.withValues(alpha: 0.42) : Colors.white12,
                                  ),
                                  checkmarkColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                );
                              }).toList(),
                            ),
                            if (error != null) ...<Widget>[
                              const SizedBox(height: 10),
                              Text(
                                error,
                                style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (isLoading && records.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(color: Color(0xFF4ADE80)),
                          ),
                        )
                      else if (filteredRecords.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C2B22),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'No activity found for this filter.',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedFilter == _ActivityFilter.cancelled
                                    ? 'No cancelled records from assigned vehicle tasks yet.'
                                    : 'Try another filter to view available logs.',
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () => MobileActivityService.refreshActivities(forceRefresh: true),
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A7B51).withValues(alpha: 0.22),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                ),
                                child: const Text(
                                  'Refresh',
                                  style: TextStyle(
                                    color: Color(0xFF4ADE80),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...filteredRecords.map(
                          (ActivityRecord record) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ActivityCard(
                              record: record,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ActivityDetailScreen(record: record),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityRecord record;
  final VoidCallback onTap;

  const _ActivityCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool negativeDelta = record.deltaKg < 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0C2B22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 4,
              height: 86,
              margin: const EdgeInsets.only(right: 12, top: 2),
              decoration: BoxDecoration(
                color: record.statusColor.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: record.statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(Icons.timeline_rounded, size: 18, color: record.statusColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          record.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 14.2, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: record.statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: record.statusColor.withValues(alpha: 0.24)),
                        ),
                        child: Text(
                          record.statusLabel,
                          style: TextStyle(color: record.statusColor, fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${record.tripCode}  •  ${record.locationName}',
                    style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${record.beforeKg.toStringAsFixed(0)} kg -> ${record.afterKg.toStringAsFixed(0)} kg  (${negativeDelta ? '' : '+'}${record.deltaKg.toStringAsFixed(0)} kg)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.0),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }
}

class _LivePulseDot extends StatefulWidget {
  final bool isActive;

  const _LivePulseDot({required this.isActive});

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _LivePulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.isActive ? const Color(0xFF4ADE80) : Colors.white38;

    return FadeTransition(
      opacity: widget.isActive
          ? Tween<double>(begin: 0.35, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut))
          : const AlwaysStoppedAnimation<double>(1),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
