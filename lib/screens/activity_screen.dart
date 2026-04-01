import 'package:flutter/material.dart';
import 'package:mobile/widget/navbar.dart';

import 'activity_data.dart';
import 'activity_detail_screen.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final int criticalCount = kActivityRecords.where((ActivityRecord r) => r.severity == ActivitySeverity.critical).length;
    final int warningCount = kActivityRecords.where((ActivityRecord r) => r.severity == ActivitySeverity.warning).length;

    return Container(
      color: const Color(0xFF051E16),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const AppNavbar(
                title: 'Activity',
                subtitle: 'Trip alerts, logs, and cargo incident history',
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SummaryCard(
                      title: 'Total Logs',
                      value: '${kActivityRecords.length}',
                      icon: Icons.history_toggle_off_rounded,
                      accent: const Color(0xFF4ADE80),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Critical',
                      value: '$criticalCount',
                      icon: Icons.error_outline_rounded,
                      accent: const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Warning',
                      value: '$warningCount',
                      icon: Icons.warning_amber_rounded,
                      accent: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...kActivityRecords.map(
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

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
        ],
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0C2B22),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: record.statusColor.withValues(alpha: 0.16),
                shape: BoxShape.circle,
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
                          style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: record.statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          record.statusLabel,
                          style: TextStyle(color: record.statusColor, fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${record.tripCode}  •  ${record.locationName}',
                    style: const TextStyle(color: Colors.white60, fontSize: 11.8),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${record.beforeKg.toStringAsFixed(0)} kg -> ${record.afterKg.toStringAsFixed(0)} kg  (${negativeDelta ? '' : '+'}${record.deltaKg.toStringAsFixed(0)} kg)',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.2),
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
