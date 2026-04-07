import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/services/app_tab_service.dart';
import 'package:mobile/services/mobile_task_service.dart';

import 'task_runtime_store.dart';

class TaskDetailScreen extends StatefulWidget {
  final dynamic task;
  final bool autoPromptUnload;

  const TaskDetailScreen({
    super.key,
    required this.task,
    this.autoPromptUnload = false,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  static const double _unloadConfirmThresholdKg = 0.1;
  static const double _pickupArrivalThresholdMeters = 20;

  TaskRuntimeController? _runtime;

  MobileAssignedTask? _liveTaskSnapshot;
  bool _didAutoPromptUnload = false;

  String get _taskId => widget.task.taskId as String;

  MobileAssignedTask get _taskView =>
      _liveTaskSnapshot ?? widget.task as MobileAssignedTask;

  void _syncLiveTaskSnapshot() {
    final MobileAssignedTask? currentTask =
        MobileTaskService.currentTaskNotifier.value;
    if (currentTask != null && currentTask.taskId == _taskId) {
      _liveTaskSnapshot = currentTask;
    }
  }

  String get _dispatchStatus =>
      _taskView.dispatchStatus.toString().trim().toLowerCase();

  bool get _isPendingStage => _dispatchStatus == 'pending';

  bool get _isPickupVerifiedStage => _dispatchStatus == 'active';

  bool get _isPickupArrivalConfirmed {
    if (AppTabService.isPickupArrived(_taskId)) {
      return true;
    }

    final double? liveLat = _taskView.liveLatitude;
    final double? liveLng = _taskView.liveLongitude;
    if (liveLat == null || liveLng == null) {
      return false;
    }

    return _distanceMeters(
          LatLng(liveLat, liveLng),
          LatLng(_taskView.pickupLat, _taskView.pickupLng),
        ) <=
        _pickupArrivalThresholdMeters;
  }

  bool get _canConfirmPickupLoading {
    return _isPickupVerifiedStage && _isPickupArrivalConfirmed;
  }

  String get _beginButtonLabel {
    if (_isPendingStage) {
      return 'Begin Task (Go to Pickup)';
    }
    if (_isPickupVerifiedStage) {
      return _canConfirmPickupLoading
          ? 'Confirm & Continue'
          : 'Await Pickup Arrival';
    }
    if (_dispatchStatus == 'in_transit') {
      return 'Unload Cargo & Complete';
    }
    if (_dispatchStatus == 'completed') {
      return 'Task Completed';
    }
    if (_dispatchStatus == 'cancelled') {
      return 'Task Cancelled';
    }
    return 'Begin Task';
  }

  double _distanceMeters(LatLng from, LatLng to) {
    const double earthRadius = 6371000;
    final double dLat = (to.latitude - from.latitude) * math.pi / 180;
    final double dLng = (to.longitude - from.longitude) * math.pi / 180;
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(from.latitude * math.pi / 180) *
            math.cos(to.latitude * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * (2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)));
  }

  String _liveVehicleStateLabel() {
    final String state = _taskView.vehicleCurrentState.toString().trim();
    return state.isEmpty ? 'Unknown' : state;
  }

  String _liveLoadStatusLabel() {
    final String status = _taskView.vehicleCurrentLoadStatus.toString().trim();
    return status.isEmpty ? 'Unknown' : status;
  }

  String _liveCurrentWeightLabel() {
    final double? rawWeight = _resolvedLiveCurrentWeightKg();
    if (rawWeight == null) {
      return '-- kg';
    }
    return '${rawWeight.toDouble().toStringAsFixed(0)} kg';
  }

  double? _resolvedLiveCurrentWeightKg() {
    final dynamic taskWeight = _taskView.liveCurrentWeightKg;
    if (taskWeight is num) {
      return taskWeight.toDouble();
    }

    final TaskRuntimeController? runtime = _runtime;
    if (runtime != null) {
      return runtime.latestWeightKg;
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _runtime = TaskRuntimeStore.existing(_taskId);
    _syncLiveTaskSnapshot();
    MobileTaskService.currentTaskNotifier.addListener(_handleTaskSnapshotUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoPromptUnload();
    });
  }

  @override
  void dispose() {
    MobileTaskService.currentTaskNotifier.removeListener(
      _handleTaskSnapshotUpdate,
    );
    super.dispose();
  }

  void _handleTaskSnapshotUpdate() {
    if (!mounted) {
      return;
    }

    final MobileAssignedTask? currentTask =
        MobileTaskService.currentTaskNotifier.value;
    if (currentTask != null && currentTask.taskId == _taskId) {
      setState(() {
        _liveTaskSnapshot = currentTask;
      });
    }
  }

  void _maybeAutoPromptUnload() {
    if (!mounted || _didAutoPromptUnload || !widget.autoPromptUnload) {
      return;
    }

    if (_dispatchStatus != 'in_transit') {
      return;
    }

    _didAutoPromptUnload = true;
    _confirmUnloadAndComplete();
  }

  String _fmt(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmBeginTask() async {
    if (_dispatchStatus == 'in_transit') {
      await _confirmUnloadAndComplete();
      return;
    }

    if (_dispatchStatus == 'completed' || _dispatchStatus == 'cancelled') {
      return;
    }

    if (_isPickupVerifiedStage) {
      if (!_isPickupArrivalConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wait until the vehicle reaches the pickup point.'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      await _confirmInitialReferenceWeight();
      return;
    }

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
                          child: const Text('Start Pickup Trip', style: TextStyle(fontWeight: FontWeight.w700)),
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
      AppTabService.clearPickupArrived(_taskId);
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
      taskId: _taskId,
      maxKg: _taskView.maxTruckKg,
    );
    runtime.start();

    setState(() {
      _runtime = runtime;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pickup trip started. Redirecting to Trips.'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    AppTabService.selectTab(2);
    AppTabService.revealTripNavigation();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmUnloadAndComplete() async {
    final bool? shouldComplete = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final List<Listenable> listenables = <Listenable>[
          MobileTaskService.currentTaskNotifier,
          if (_runtime != null) _runtime! as Listenable,
        ];

        return AnimatedBuilder(
          animation: Listenable.merge(listenables),
          builder: (context, _) {
            final double? liveWeight = _resolvedLiveCurrentWeightKg();
            final bool canComplete =
                liveWeight != null && liveWeight <= _unloadConfirmThresholdKg;

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
                        'Unload Cargo Confirmation',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Unload all cargo at destination. Completion is allowed only when current load reaches zero.',
                        style: TextStyle(color: Colors.white70, fontSize: 13.5),
                      ),
                      const SizedBox(height: 14),
                      _ConfirmSummaryCard(
                        icon: Icons.monitor_weight_rounded,
                        label: 'Current load',
                        value: liveWeight == null
                            ? '-- kg'
                            : '${liveWeight.toStringAsFixed(1)} kg',
                      ),
                      const SizedBox(height: 10),
                      _ConfirmSummaryCard(
                        icon: Icons.local_shipping_rounded,
                        label: 'Live vehicle state',
                        value:
                            '${_liveVehicleStateLabel()} • ${_liveLoadStatusLabel()}',
                      ),
                      if (!canComplete) ...<Widget>[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7F1D1D).withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.32),
                            ),
                          ),
                          child: const Text(
                            'Current load is not zero yet. Continue unloading to 0.0 kg to complete this dispatch task.',
                            style: TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: canComplete
                                  ? () => Navigator.of(context).pop(true)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A7B51),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Confirm Unloaded & Complete',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
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
      },
    );

    if (shouldComplete != true || !mounted) {
      return;
    }

    try {
      await MobileTaskService.completeCurrentTask();
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispatch task completed successfully.'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    AppTabService.selectTab(1);
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmInitialReferenceWeight() async {
    final int maxTruckKg = (widget.task.maxTruckKg is num)
        ? (widget.task.maxTruckKg as num).toInt()
        : 0;
    final double? liveCurrentWeight = _resolvedLiveCurrentWeightKg();

    if (liveCurrentWeight == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Live current weight is not available yet.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    final double? submittedWeight = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final List<Listenable> listenables = <Listenable>[
          MobileTaskService.currentTaskNotifier,
          if (_runtime != null) _runtime! as Listenable,
        ];

        return AnimatedBuilder(
          animation: Listenable.merge(listenables),
          builder: (context, _) {
            final double? modalLiveWeight = _resolvedLiveCurrentWeightKg();
            final bool modalIsOverCapacity =
                modalLiveWeight != null && modalLiveWeight > maxTruckKg.toDouble();

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
                        'Confirm live cargo weight',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The live scale reading will be used as the initial reference weight. Confirm it before proceeding to destination.',
                        style: TextStyle(color: Colors.white70, fontSize: 13.5),
                      ),
                      const SizedBox(height: 14),
                      _ConfirmSummaryCard(
                        icon: Icons.scale_rounded,
                        label: 'Truck max capacity',
                        value: '$maxTruckKg kg',
                      ),
                      const SizedBox(height: 10),
                      _ConfirmSummaryCard(
                        icon: Icons.monitor_weight_rounded,
                        label: 'Live current weight',
                        value: modalLiveWeight == null
                            ? '-- kg'
                            : '${modalLiveWeight.toStringAsFixed(0)} kg',
                      ),
                      const SizedBox(height: 10),
                      _ConfirmSummaryCard(
                        icon: Icons.local_shipping_rounded,
                        label: 'Live vehicle state',
                        value:
                            '${_liveVehicleStateLabel()} • ${_liveLoadStatusLabel()}',
                      ),
                      if (modalIsOverCapacity) ...<Widget>[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7F1D1D).withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.32),
                            ),
                          ),
                          child: const Text(
                            'Live weight exceeds truck max capacity. Confirm is blocked until the load is within limit.',
                            style: TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: modalIsOverCapacity || modalLiveWeight == null
                                  ? null
                                  : () => Navigator.of(context).pop(modalLiveWeight),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A7B51),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Confirm & Continue',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
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
      },
    );

    if (submittedWeight == null || !mounted) {
      return;
    }

    try {
      AppTabService.clearPickupArrived(_taskId);
      await MobileTaskService.startCurrentTask(
        initialReferenceWeightKg: submittedWeight,
      );
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

    final MobileAssignedTask? refreshedTask =
        MobileTaskService.currentTaskNotifier.value;
    final String refreshedStatus =
        refreshedTask?.dispatchStatus.toLowerCase().trim() ?? '';
    if (refreshedTask == null || refreshedStatus != 'in_transit') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Weight saved but task is not yet in transit. Please refresh task state.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reference weight saved. Heading to destination.'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    AppTabService.revealTripNavigation();
    AppTabService.selectTab(2);
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
                '${_taskView.pickupName} → ${_taskView.destinationName}',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${_taskView.summaryLabel}  •  ETA ${_taskView.eta}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '${_taskView.vehiclePlateNumber}  •  ${_taskView.vehicleType}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 14),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Vehicle Live State',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Current state: ${_liveVehicleStateLabel()}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Load status: ${_liveLoadStatusLabel()}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Live current weight: ${_liveCurrentWeightLabel()}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Maximum capacity: ${_taskView.maxTruckKg} kg',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                locationName: _taskView.pickupName,
                lat: _taskView.pickupLat,
                lng: _taskView.pickupLng,
                icon: Icons.my_location_rounded,
              ),
              const SizedBox(height: 12),
              _InfoCard(
                title: 'Destination Point',
                locationName: _taskView.destinationName,
                lat: _taskView.destinationLat,
                lng: _taskView.destinationLng,
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
                      'Align and load cargo within max truck limit: ${_taskView.maxTruckKg} kg.',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    if (_isPickupVerifiedStage)
                      Text(
                        _isPickupArrivalConfirmed
                            ? 'Pickup reached. Use the live weight below to confirm loading and continue.'
                            : 'Vehicle has not reached the pickup point yet. Loading confirmation stays disabled until arrival.',
                        style: TextStyle(
                          color: _isPickupArrivalConfirmed
                              ? const Color(0xFF4ADE80)
                              : Colors.white60,
                          fontSize: 12.5,
                        ),
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
                  onPressed: (_dispatchStatus == 'completed' ||
                    _dispatchStatus == 'cancelled' ||
                          (_isPickupVerifiedStage && !_canConfirmPickupLoading))
                      ? null
                      : _confirmBeginTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A7B51),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(_beginButtonLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
