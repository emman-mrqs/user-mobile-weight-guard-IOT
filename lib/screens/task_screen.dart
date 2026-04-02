import 'package:flutter/material.dart';
import 'package:mobile/widget/navbar.dart';
import 'task_detail_screen.dart';

class TaskScreen extends StatelessWidget {
  const TaskScreen({super.key});

  static const _AssignedTask _assignedTask = _AssignedTask(
    taskId: 'T-10021',
    vehiclePlateNumber: 'GAB 4201',
    vehicleType: 'Trailer Truck',
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
  );

  @override
  Widget build(BuildContext context) {
    final _AssignedTask task = _assignedTask;

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
                title: 'Tasks',
                subtitle: 'Assigned tasks for the current driver',
              ),
              const SizedBox(height: 18),
              _InfoCard(
                title: 'Assigned Task',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.near_me_rounded,
                            size: 16,
                            color: Color(0xFF4ADE80),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Current Location: ${task.pickupName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _LabelValueTile(
                            label: 'Plate Number',
                            value: task.vehiclePlateNumber,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _LabelValueTile(
                            label: 'Vehicle Type',
                            value: task.vehicleType,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      task.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${task.tripCode}  •  ETA ${task.eta}',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Task ${task.taskId}  •  Driver ${task.driverId}',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Timeline',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TimelineStep(
                      title: 'Pickup',
                      subtitle: task.pickupName,
                      icon: Icons.my_location_rounded,
                      isLast: false,
                    ),
                    _TimelineStep(
                      title: 'Load Cargo',
                      subtitle: 'Load and verify cargo up to ${task.maxTruckKg} kg',
                      icon: Icons.inventory_2_outlined,
                      isLast: false,
                    ),
                    _TimelineStep(
                      title: 'Destination',
                      subtitle: task.destinationName,
                      icon: Icons.place_outlined,
                      isLast: true,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TaskDetailScreen(task: task),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF1A7B51).withValues(alpha: 0.22),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        child: const Text(
                          'Start Task',
                          style: TextStyle(
                            color: Color(0xFF4ADE80),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _LabelValueTile extends StatelessWidget {
  final String label;
  final String value;

  const _LabelValueTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 26,
          child: Column(
            children: <Widget>[
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A7B51).withValues(alpha: 0.24),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: const Color(0xFF4ADE80)),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 26,
                  color: Colors.white24,
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AssignedTask {
  final String taskId;
  final String vehiclePlateNumber;
  final String vehicleType;
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
    required this.vehiclePlateNumber,
    required this.vehicleType,
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
