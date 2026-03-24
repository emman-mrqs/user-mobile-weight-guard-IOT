import 'package:flutter/material.dart';
import 'package:mobile/widget/navbar.dart';
import 'task_detail_screen.dart';

class TaskScreen extends StatelessWidget {
  const TaskScreen({super.key});

  static const List<_AssignedTask> _pendingTasks = <_AssignedTask>[
    _AssignedTask(
      taskId: 'T-10021',
      vehicleId: 'VH-09',
      driverId: 'DRV-014',
      title: 'Verify route checkpoint at Mandaue',
      tripCode: 'Trip C-219',
      eta: '10:15 AM',
      pickupName: 'Cebu Port Hub',
      pickupLat: 10.3090,
      pickupLng: 123.8930,
      destinationName: 'Mandaue Checkpoint',
      destinationLat: 10.3342,
      destinationLng: 123.9411,
      maxTruckKg: 3000,
    ),
    _AssignedTask(
      taskId: 'T-10022',
      vehicleId: 'VH-09',
      driverId: 'DRV-014',
      title: 'Confirm unloading weight in Toledo',
      tripCode: 'Trip C-219',
      eta: '01:40 PM',
      pickupName: 'Mandaue Weigh Bridge',
      pickupLat: 10.3251,
      pickupLng: 123.9356,
      destinationName: 'Toledo Cargo Yard',
      destinationLat: 10.3784,
      destinationLng: 123.6386,
      maxTruckKg: 3000,
    ),
    _AssignedTask(
      taskId: 'T-10023',
      vehicleId: 'VH-09',
      driverId: 'DRV-014',
      title: 'Finalize delivery acknowledgment',
      tripCode: 'Trip C-219',
      eta: '03:10 PM',
      pickupName: 'Toledo Cargo Yard',
      pickupLat: 10.3784,
      pickupLng: 123.6386,
      destinationName: 'Naga Receiving Dock',
      destinationLat: 10.2100,
      destinationLng: 123.7587,
      maxTruckKg: 3000,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final int pendingCount = _pendingTasks.length;

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
                title: 'Tasks',
                subtitle: 'Assigned tasks for the current driver',
                notificationCount: 2,
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2B22),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Pending Assigned Tasks',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$pendingCount tasks are waiting to be started',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Initial reference weight, started at, and completed at will be created only after driver taps Start/Begin.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ..._pendingTasks.map((task) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TaskCard(
                      task: task,
                      onStart: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TaskDetailScreen(task: task),
                          ),
                        );
                      },
                    ),
                  )),
              if (_pendingTasks.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No pending tasks assigned.',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 2),
              const Text(
                'Flow: Pending -> Start -> Active/Loading -> Begin Trip (In Transit) -> Completed.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final _AssignedTask task;
  final VoidCallback onStart;

  const _TaskCard({
    required this.task,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule_rounded,
              size: 18,
              color: Colors.white60,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  task.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${task.tripCode}  •  ETA ${task.eta}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Task ${task.taskId}  •  Driver ${task.driverId}  •  Vehicle ${task.vehicleId}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onStart,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF1A7B51).withValues(alpha: 0.22),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: const Text(
              'Start',
              style: TextStyle(
                color: Color(0xFF4ADE80),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedTask {
  final String taskId;
  final String vehicleId;
  final String driverId;
  final String title;
  final String tripCode;
  final String eta;
  final String pickupName;
  final double pickupLat;
  final double pickupLng;
  final String destinationName;
  final double destinationLat;
  final double destinationLng;
  final int maxTruckKg;

  const _AssignedTask({
    required this.taskId,
    required this.vehicleId,
    required this.driverId,
    required this.title,
    required this.tripCode,
    required this.eta,
    required this.pickupName,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
    required this.maxTruckKg,
  });
}
