import 'package:flutter/material.dart';
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

  bool _matchesFilter(ActivityRecord record, _ActivityFilter filter) {
    switch (filter) {
      case _ActivityFilter.all:
        return true;
      case _ActivityFilter.completed:
        return record.severity == ActivitySeverity.normal;
      case _ActivityFilter.cancelled:
        return false;
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

  @override
  Widget build(BuildContext context) {
    final int criticalCount = kActivityRecords.where((ActivityRecord r) => r.severity == ActivitySeverity.critical).length;
    final int warningCount = kActivityRecords.where((ActivityRecord r) => r.severity == ActivitySeverity.warning).length;
    final int completedCount = kActivityRecords.where((ActivityRecord r) => r.severity == ActivitySeverity.normal).length;
    final List<ActivityRecord> filteredRecords = kActivityRecords.where((ActivityRecord record) => _matchesFilter(record, _selectedFilter)).toList();

    return Container(
      color: const Color(0xFF051E16),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AppNavbar(
                title: 'Activity',
                subtitle: 'Trip alerts, logs, and cargo incident history',
              ),
              const SizedBox(height: 18),
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
                    Text(
                      '${kActivityRecords.length} logs total  •  $completedCount completed  •  $warningCount warning  •  $criticalCount critical',
                      style: const TextStyle(color: Colors.white60, fontSize: 11.8),
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
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (filteredRecords.isEmpty)
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
                            ? 'Cancelled records are not available yet.'
                            : 'Try another filter to view available logs.',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
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
