import 'package:flutter/material.dart';

enum ActivitySeverity { normal, warning, critical, completed, cancelled }

class ActivityRecord {
  final String id;
  final String tripCode;
  final String title;
  final String summary;
  final String locationName;
  final String startedAt;
  final String endedAt;
  final double beforeKg;
  final double afterKg;
  final ActivitySeverity severity;
  final List<String> timeline;

  const ActivityRecord({
    required this.id,
    required this.tripCode,
    required this.title,
    required this.summary,
    required this.locationName,
    required this.startedAt,
    required this.endedAt,
    required this.beforeKg,
    required this.afterKg,
    required this.severity,
    required this.timeline,
  });

  double get deltaKg => afterKg - beforeKg;

  String get statusLabel {
    switch (severity) {
      case ActivitySeverity.critical:
        return 'Cargo Loss';
      case ActivitySeverity.warning:
        return 'Overload';
      case ActivitySeverity.completed:
        return 'Completed';
      case ActivitySeverity.cancelled:
        return 'Cancelled';
      case ActivitySeverity.normal:
        return 'Normal';
    }
  }

  Color get statusColor {
    switch (severity) {
      case ActivitySeverity.critical:
        return const Color(0xFFEF4444);
      case ActivitySeverity.warning:
        return const Color(0xFFF59E0B);
      case ActivitySeverity.completed:
        return const Color(0xFF4ADE80);
      case ActivitySeverity.cancelled:
        return const Color(0xFF94A3B8);
      case ActivitySeverity.normal:
        return const Color(0xFF4ADE80);
    }
  }
}

const List<ActivityRecord> kActivityRecords = <ActivityRecord>[
  ActivityRecord(
    id: 'ACT-101',
    tripCode: 'Trip C-219',
    title: 'Sudden weight drop detected',
    summary: 'Weight changed quickly near Mandaue checkpoint and triggered cargo loss alert.',
    locationName: 'Mandaue Checkpoint',
    startedAt: '11:08 AM',
    endedAt: '11:17 AM',
    beforeKg: 676,
    afterKg: 635,
    severity: ActivitySeverity.critical,
    timeline: <String>[
      '11:08 AM - Initial reading captured (676 kg)',
      '11:12 AM - Continuous telemetry normal',
      '11:15 AM - Weight dropped to 635 kg',
      '11:17 AM - Cargo loss incident confirmed',
    ],
  ),
  ActivityRecord(
    id: 'ACT-102',
    tripCode: 'Trip C-220',
    title: 'Overload threshold exceeded briefly',
    summary: 'Vehicle exceeded expected max load while passing loading corridor.',
    locationName: 'Cebu Port Hub',
    startedAt: '01:35 PM',
    endedAt: '01:43 PM',
    beforeKg: 4420,
    afterKg: 4565,
    severity: ActivitySeverity.warning,
    timeline: <String>[
      '01:35 PM - Baseline load verified (4420 kg)',
      '01:38 PM - Incoming readings increasing',
      '01:40 PM - Overload marker raised (4565 kg)',
      '01:43 PM - Driver acknowledged overload warning',
    ],
  ),
  ActivityRecord(
    id: 'ACT-103',
    tripCode: 'Trip C-221',
    title: 'Trip completed without anomalies',
    summary: 'All checkpoints passed with stable cargo weight and normal route timing.',
    locationName: 'Naga Receiving Dock',
    startedAt: '04:10 PM',
    endedAt: '05:02 PM',
    beforeKg: 3210,
    afterKg: 3201,
    severity: ActivitySeverity.normal,
    timeline: <String>[
      '04:10 PM - Route started from Toledo yard',
      '04:32 PM - Mid-route telemetry stable',
      '04:51 PM - Destination reached',
      '05:02 PM - Final unload validated (3201 kg)',
    ],
  ),
];
