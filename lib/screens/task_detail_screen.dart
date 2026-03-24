import 'package:flutter/material.dart';

import 'task_instruction_screen.dart';
import 'task_runtime_store.dart';

class TaskDetailScreen extends StatefulWidget {
  final dynamic task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  TaskRuntimeController? _runtime;

  @override
  void initState() {
    super.initState();
    _runtime = TaskRuntimeStore.existing(widget.task.taskId as String);
  }

  String _fmt(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF051E16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF051E16),
        elevation: 0,
        title: const Text('Task Detail', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.task.title as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.task.tripCode}  •  ETA ${widget.task.eta}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Task ${widget.task.taskId}  •  Driver ${widget.task.driverId}  •  Vehicle ${widget.task.vehicleId}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 14),
              if (_runtime != null)
                AnimatedBuilder(
                  animation: _runtime!,
                  builder: (context, _) {
                    return _Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Live Scale Session',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Latest weight: ${_runtime!.latestWeightKg.toStringAsFixed(1)} kg',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          Text(
                            'Status: ${_runtime!.loadStatus}  •  Started at: ${_fmt(_runtime!.startedAt)}',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                const _Card(
                  child: Text(
                    'No active scale session yet. Tap Begin to start live monitoring.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Pickup Point',
                locationName: widget.task.pickupName as String,
                lat: widget.task.pickupLat as double,
                lng: widget.task.pickupLng as double,
                icon: Icons.my_location_rounded,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Destination Point',
                locationName: widget.task.destinationName as String,
                lat: widget.task.destinationLat as double,
                lng: widget.task.destinationLng as double,
                icon: Icons.place_outlined,
              ),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Cargo Requirement',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Align and load cargo within max truck limit: ${widget.task.maxTruckKg} kg.',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final runtime = TaskRuntimeStore.forTask(
                      taskId: widget.task.taskId as String,
                      maxKg: widget.task.maxTruckKg as int,
                    );
                    runtime.start();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TaskInstructionScreen(task: widget.task),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A7B51),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Begin', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String locationName;
  final double lat;
  final double lng;
  final IconData icon;

  const _InfoCard({
    required this.title,
    required this.locationName,
    required this.lat,
    required this.lng,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1A7B51).withValues(alpha: 0.24),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF4ADE80)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(locationName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  'Lat: ${lat.toStringAsFixed(6)}  |  Lng: ${lng.toStringAsFixed(6)}',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
