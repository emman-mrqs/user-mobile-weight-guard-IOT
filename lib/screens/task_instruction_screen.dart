import 'package:flutter/material.dart';
import 'task_runtime_store.dart';

class TaskInstructionScreen extends StatefulWidget {
  final dynamic task;

  const TaskInstructionScreen({super.key, required this.task});

  @override
  State<TaskInstructionScreen> createState() => _TaskInstructionScreenState();
}

class _TaskInstructionScreenState extends State<TaskInstructionScreen> {
  late final TaskRuntimeController _runtime;

  @override
  void initState() {
    super.initState();
    _runtime = TaskRuntimeStore.forTask(
      taskId: widget.task.taskId as String,
      maxKg: widget.task.maxTruckKg as int,
    );
    _runtime.start();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _fmt(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final int maxKg = widget.task.maxTruckKg as int;

    return Scaffold(
      backgroundColor: const Color(0xFF051E16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF051E16),
        elevation: 0,
        title: const Text('Task Instruction', style: TextStyle(color: Colors.white)),
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
                'Task ${widget.task.taskId}  •  Driver ${widget.task.driverId}  •  Vehicle ${widget.task.vehicleId}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 14),
              const _Panel(
                title: 'Instruction',
                child: Text(
                  'Go to the pickup point. Once you arrive, load cargo aligned with the truck maximum capacity. The weight below is from the connected scale stream.',
                  style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.45),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _runtime,
                builder: (context, _) {
                  return _Panel(
                    title: 'Scale Monitor (Dynamic)',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _runtime.isScaleConnected ? const Color(0xFF4ADE80) : Colors.white38,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _runtime.isScaleConnected ? 'Scale Connected' : 'Scale Disconnected',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                            Switch(
                              value: _runtime.isScaleConnected,
                              activeThumbColor: const Color(0xFF4ADE80),
                              onChanged: (bool value) {
                                _runtime.setConnected(value);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Live weight: ${_runtime.latestWeightKg.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _runtime.utilization,
                            minHeight: 10,
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4ADE80)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Max capacity: $maxKg kg  •  ${(_runtime.latestWeightKg / maxKg * 100).toStringAsFixed(1)}% utilization',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              AnimatedBuilder(
                animation: _runtime,
                builder: (context, _) {
                  return _Panel(
                    title: 'Task Runtime Status',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const _KV(label: 'Status', value: 'Active'),
                        _KV(label: 'Started at', value: _fmt(_runtime.startedAt)),
                        _KV(label: 'Initial reference weight', value: '${_runtime.initialReferenceWeightKg.toStringAsFixed(1)} kg'),
                        _KV(label: 'Current load status', value: _runtime.loadStatus),
                      ],
                    ),
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

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({required this.title, required this.child});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  final String label;
  final String value;

  const _KV({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          Text(value, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }
}
