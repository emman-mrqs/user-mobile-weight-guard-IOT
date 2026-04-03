import 'package:flutter/material.dart';
import 'package:mobile/services/mobile_task_service.dart';

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

  Future<void> _confirmBeginTask() async {
    final bool? shouldStart = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: 20 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0C2B22),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Start this task?',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.task.pickupName} → ${widget.task.destinationName}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  _ConfirmSummaryCard(
                    icon: Icons.local_shipping_rounded,
                    label: 'Vehicle',
                    value: '${widget.task.vehiclePlateNumber} • ${widget.task.vehicleType}',
                  ),
                  const SizedBox(height: 10),
                  _ConfirmSummaryCard(
                    icon: Icons.route_rounded,
                    label: 'Stage',
                    value: '${widget.task.badgeLabel} • ETA ${widget.task.eta}',
                  ),
                  const SizedBox(height: 10),
                  _ConfirmSummaryCard(
                    icon: Icons.scale_rounded,
                    label: 'Load limit',
                    value: '${widget.task.maxTruckKg} kg max',
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A7B51),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Start Task', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (shouldStart != true || !mounted) {
      return;
    }

    try {
      await MobileTaskService.startCurrentTask();
      // Force refresh to ensure UI is synced with latest server state
      await MobileTaskService.refreshCurrentTask(forceRefresh: true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final runtime = TaskRuntimeStore.forTask(
      taskId: widget.task.taskId as String,
      maxKg: widget.task.maxTruckKg as int,
    );
    runtime.start();

    setState(() {
      _runtime = runtime;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task started. Follow the detailed instruction above.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  ({bool isDone, bool isActive}) _resolveStepState(int index) {
    final dynamic rawTimeline = widget.task.timeline;
    if (rawTimeline is! List || rawTimeline.isEmpty) {
      return (isDone: false, isActive: false);
    }

    final List<TaskTimelineStepData> steps = rawTimeline.whereType<TaskTimelineStepData>().toList();
    if (steps.isEmpty) {
      return (isDone: false, isActive: false);
    }

    const List<String> keys = <String>['pickup', 'load', 'destination'];
    final String key = index >= 0 && index < keys.length ? keys[index] : '';
    final TaskTimelineStepData? matched = steps.where((s) => s.key.toLowerCase() == key).cast<TaskTimelineStepData?>().firstWhere(
          (s) => s != null,
          orElse: () => null,
        );

    if (matched == null) {
      return (isDone: false, isActive: false);
    }

    return (isDone: matched.isDone, isActive: matched.isActive);
  }

  List<Widget> _buildInstructionItems() {
    final dynamic raw = widget.task.detailedInstructions;

    if (raw is List && raw.isNotEmpty) {
      final List<TaskInstructionStepData> steps = raw.whereType<TaskInstructionStepData>().toList();
      if (steps.isNotEmpty) {
        return steps.asMap().entries.map((entry) {
          final int index = entry.key;
          final TaskInstructionStepData step = entry.value;
          final state = _resolveStepState(index);
          final Color accent = state.isDone
              ? const Color(0xFF4ADE80)
              : state.isActive
                  ? const Color(0xFF22D3EE)
                  : Colors.white38;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.7)),
                  ),
                  child: Center(
                    child: state.isDone
                        ? const Icon(Icons.check, size: 12, color: Color(0xFF4ADE80))
                        : Text(
                            '${step.step}',
                            style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        step.title,
                        style: TextStyle(
                          color: state.isActive ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.detail,
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList();
      }
    }

    return <Widget>[
      Text(
        '1. Proceed to ${widget.task.pickupName}.',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      const SizedBox(height: 4),
      Text(
        '2. Load and verify cargo using the live scale monitor (max ${widget.task.maxTruckKg} kg).',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      const SizedBox(height: 4),
      Text(
        '3. Complete the trip and deliver to ${widget.task.destinationName}.',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    ];
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
                'Current Dispatch',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.task.pickupName} → ${widget.task.destinationName}',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.task.summaryLabel}  •  ETA ${widget.task.eta}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.task.vehiclePlateNumber}  •  ${widget.task.vehicleType}',
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
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Detailed Instruction',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ..._buildInstructionItems(),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _confirmBeginTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A7B51),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Begin Task', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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

class _DialogRow extends StatelessWidget {
  final String label;
  final String value;

  const _DialogRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmSummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ConfirmSummaryCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
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
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
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
