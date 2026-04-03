import 'package:flutter/material.dart';
import 'package:mobile/services/mobile_task_service.dart';
import 'package:mobile/widget/navbar.dart';

import 'task_detail_screen.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  @override
  void initState() {
    super.initState();
    MobileTaskService.refreshCurrentTask(forceRefresh: true);
  }

  String _taskActionLabel(MobileAssignedTask task) {
    if (task.dispatchStatus == 'pending') {
      return 'Start Task';
    }

    return 'View Your Current Task';
  }

  void _reloadTask() {
    MobileTaskService.refreshCurrentTask(forceRefresh: true);
  }

  String _relativeUpdatedAt(DateTime? updatedAt) {
    if (updatedAt == null) {
      return 'Last updated: --';
    }

    final Duration diff = DateTime.now().difference(updatedAt);
    if (diff.inSeconds < 5) {
      return 'Last updated just now';
    }
    if (diff.inMinutes < 1) {
      return 'Last updated ${diff.inSeconds}s ago';
    }
    if (diff.inHours < 1) {
      return 'Last updated ${diff.inMinutes}m ago';
    }
    return 'Last updated ${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
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
              AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[
                  MobileTaskService.currentTaskNotifier,
                  MobileTaskService.isLoadingNotifier,
                  MobileTaskService.taskErrorNotifier,
                  MobileTaskService.lastUpdatedNotifier,
                  MobileTaskService.isPollingNotifier,
                ]),
                builder: (context, _) {
                  final bool isLoading = MobileTaskService.isLoadingNotifier.value;
                  final MobileAssignedTask? task = MobileTaskService.currentTaskNotifier.value;
                  final String? errorMessage = MobileTaskService.taskErrorNotifier.value;
                  final DateTime? lastUpdatedAt = MobileTaskService.lastUpdatedNotifier.value;
                  final bool isPolling = MobileTaskService.isPollingNotifier.value;

                  if (isLoading && task == null) {
                    return const _InfoCard(
                      title: 'Assigned Task',
                      child: SizedBox(
                        height: 120,
                        child: Center(
                          child: CircularProgressIndicator(color: Color(0xFF4ADE80)),
                        ),
                      ),
                    );
                  }

                  if (errorMessage != null && task == null) {
                    return _InfoCard(
                      title: 'Assigned Task',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Unable to load task right now.',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            errorMessage,
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _reloadTask,
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF1A7B51).withValues(alpha: 0.22),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            ),
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (task == null) {
                    return _InfoCard(
                      title: 'Assigned Task',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'No active task assigned yet.',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your dispatcher will assign your next trip soon.',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _reloadTask,
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
                    );
                  }

                  return _InfoCard(
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
                                    'Current Location: ${task.locationLabel}',
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
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Current Dispatch',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _StatusChip(status: task.dispatchStatus, label: task.badgeLabel),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            _LivePulseDot(isActive: isPolling),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                _relativeUpdatedAt(lastUpdatedAt),
                                style: const TextStyle(color: Colors.white54, fontSize: 11.2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${task.pickupName} → ${task.destinationName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${task.summaryLabel}  •  ETA ${task.eta}',
                          style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (errorMessage != null) ...<Widget>[
                          const SizedBox(height: 8),
                          const Text(
                            'Live update paused. Reconnecting automatically...',
                            style: TextStyle(color: Colors.white54, fontSize: 11.5),
                          ),
                        ],
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
                        ..._buildTimeline(task),
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
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            ),
                            child: Text(
                              _taskActionLabel(task),
                              style: const TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
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

  List<Widget> _buildTimeline(MobileAssignedTask task) {
    if (task.timeline.isNotEmpty) {
      return task.timeline.asMap().entries.map((entry) {
        final int index = entry.key;
        final TaskTimelineStepData step = entry.value;
        return _TimelineStep(
          title: step.title,
          subtitle: step.subtitle,
          icon: _timelineIcon(step.key),
          isLast: index == task.timeline.length - 1,
        );
      }).toList();
    }

    return <Widget>[
      _TimelineStep(
        title: 'Pickup',
        subtitle: task.pickupName,
        icon: Icons.my_location_rounded,
        isLast: false,
      ),
      _TimelineStep(
        title: 'Load Cargo',
        subtitle: task.maxTruckKg > 0 ? 'Load and verify cargo up to ${task.maxTruckKg} kg' : 'Load and verify cargo',
        icon: Icons.inventory_2_outlined,
        isLast: false,
      ),
      _TimelineStep(
        title: 'Destination',
        subtitle: task.destinationName,
        icon: Icons.place_outlined,
        isLast: true,
      ),
    ];
  }

  IconData _timelineIcon(String key) {
    switch (key.toLowerCase()) {
      case 'pickup':
        return Icons.my_location_rounded;
      case 'load':
        return Icons.inventory_2_outlined;
      case 'destination':
        return Icons.place_outlined;
      default:
        return Icons.timeline_rounded;
    }
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

class _StatusChip extends StatelessWidget {
  final String status;
  final String label;

  const _StatusChip({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final String normalized = status.toLowerCase();
    final Color color;

    switch (normalized) {
      case 'completed':
        color = const Color(0xFF4ADE80);
        break;
      case 'cancelled':
        color = const Color(0xFF94A3B8);
        break;
      case 'in_transit':
        color = const Color(0xFF22D3EE);
        break;
      case 'active':
        color = const Color(0xFFF59E0B);
        break;
      default:
        color = const Color(0xFF60A5FA);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 10.8, fontWeight: FontWeight.w700),
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
