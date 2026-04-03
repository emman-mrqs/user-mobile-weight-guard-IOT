import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_env.dart';
import 'api_routes.dart';
import 'auth_session_service.dart';

class TaskTimelineStepData {
  final String key;
  final String title;
  final String subtitle;
  final bool isDone;
  final bool isActive;

  const TaskTimelineStepData({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.isActive,
  });

  factory TaskTimelineStepData.fromJson(Map<String, dynamic> json) {
    return TaskTimelineStepData(
      key: (json['key'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString().trim(),
      subtitle: (json['subtitle'] ?? '').toString().trim(),
      isDone: json['isDone'] == true,
      isActive: json['isActive'] == true,
    );
  }
}

class TaskInstructionStepData {
  final int step;
  final String title;
  final String detail;

  const TaskInstructionStepData({
    required this.step,
    required this.title,
    required this.detail,
  });

  factory TaskInstructionStepData.fromJson(Map<String, dynamic> json) {
    return TaskInstructionStepData(
      step: (json['step'] is num) ? (json['step'] as num).toInt() : 0,
      title: (json['title'] ?? '').toString().trim(),
      detail: (json['detail'] ?? '').toString().trim(),
    );
  }
}

class MobileAssignedTask {
  final String taskId;
  final String dispatchStatus;
  final String stageLabel;
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
  final String currentLocationLabel;
  final List<TaskTimelineStepData> timeline;
  final List<TaskInstructionStepData> detailedInstructions;

  String get badgeLabel {
    return _statusCopy(
      dispatchStatus,
      pending: 'Awaiting pickup',
      active: 'Pickup in progress',
      inTransit: 'On route to destination',
      completed: 'Completed',
      cancelled: 'Cancelled',
      fallback: stageLabel,
    );
  }

  String get locationLabel {
    return _statusCopy(
      dispatchStatus,
      pending: 'Awaiting pickup',
      active: 'Pickup in progress',
      inTransit: 'On route to destination',
      completed: 'Task completed',
      cancelled: 'Task cancelled',
      fallback: currentLocationLabel,
    );
  }

  String get summaryLabel {
    return _statusCopy(
      dispatchStatus,
      pending: 'Awaiting pickup',
      active: 'Pickup in progress',
      inTransit: 'On route to destination',
      completed: 'Task completed',
      cancelled: 'Task cancelled',
      fallback: locationLabel,
    );
  }

  const MobileAssignedTask({
    required this.taskId,
    required this.dispatchStatus,
    required this.stageLabel,
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
    required this.currentLocationLabel,
    required this.timeline,
    required this.detailedInstructions,
  });

  factory MobileAssignedTask.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> vehicle = (json['vehicle'] is Map<String, dynamic>)
        ? json['vehicle'] as Map<String, dynamic>
        : <String, dynamic>{};
    final Map<String, dynamic> driver = (json['driver'] is Map<String, dynamic>)
        ? json['driver'] as Map<String, dynamic>
        : <String, dynamic>{};
    final Map<String, dynamic> route = (json['route'] is Map<String, dynamic>)
        ? json['route'] as Map<String, dynamic>
        : <String, dynamic>{};

    final Map<String, dynamic> pickup = (route['pickup'] is Map<String, dynamic>)
        ? route['pickup'] as Map<String, dynamic>
        : <String, dynamic>{};
    final Map<String, dynamic> destination = (route['destination'] is Map<String, dynamic>)
        ? route['destination'] as Map<String, dynamic>
        : <String, dynamic>{};

    final int estDurationMin = (route['estDurationMin'] is num)
        ? (route['estDurationMin'] as num).toInt()
        : 0;

    final List<TaskTimelineStepData> timeline = (json['timeline'] is List)
        ? (json['timeline'] as List)
            .whereType<Map<String, dynamic>>()
            .map(TaskTimelineStepData.fromJson)
            .toList()
        : <TaskTimelineStepData>[];

    final List<TaskInstructionStepData> detailedInstructions = (json['detailedInstructions'] is List)
      ? (json['detailedInstructions'] as List)
        .whereType<Map<String, dynamic>>()
        .map(TaskInstructionStepData.fromJson)
        .toList()
      : <TaskInstructionStepData>[];

    return MobileAssignedTask(
      taskId: (json['assignmentId'] ?? '').toString(),
      dispatchStatus: _normalizeStatus(json['status']),
      stageLabel: (json['stageLabel'] ?? 'Dispatch').toString(),
      vehiclePlateNumber: (vehicle['plateNumber'] ?? 'Not assigned').toString(),
      vehicleType: (vehicle['vehicleType'] ?? 'Vehicle').toString(),
      driverId: (driver['id'] ?? '').toString(),
      title: (json['title'] ?? 'Assigned Task').toString(),
      tripCode: (json['stageLabel'] ?? 'Dispatch').toString(),
      eta: estDurationMin > 0 ? '$estDurationMin min' : 'TBD',
      pickupName: (pickup['label'] ?? 'Pickup Point').toString(),
      pickupLat: (pickup['lat'] is num) ? (pickup['lat'] as num).toDouble() : 0,
      pickupLng: (pickup['lng'] is num) ? (pickup['lng'] as num).toDouble() : 0,
      destinationName: (destination['label'] ?? 'Destination Point').toString(),
      destinationLat: (destination['lat'] is num) ? (destination['lat'] as num).toDouble() : 0,
      destinationLng: (destination['lng'] is num) ? (destination['lng'] as num).toDouble() : 0,
      maxTruckKg: (vehicle['maxCapacityKg'] is num) ? (vehicle['maxCapacityKg'] as num).round() : 0,
      currentLocationLabel: (json['currentLocationLabel'] ?? 'Current Location').toString(),
      timeline: timeline,
      detailedInstructions: detailedInstructions,
    );
  }

  static String _normalizeStatus(dynamic value) {
    return (value ?? 'pending')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_');
  }

  static String _statusCopy(
    dynamic value, {
    required String pending,
    required String active,
    required String inTransit,
    required String completed,
    required String cancelled,
    required String fallback,
  }) {
    switch (_normalizeStatus(value)) {
      case 'pending':
        return pending;
      case 'active':
        return active;
      case 'in_transit':
        return inTransit;
      case 'completed':
        return completed;
      case 'cancelled':
        return cancelled;
      default:
        return fallback;
    }
  }
}

class MobileTaskService {
  static MobileAssignedTask? _cachedTask;
  static DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(seconds: 20);
  static const Duration _pollingInterval = Duration(seconds: 10);
  static Timer? _pollingTimer;

  static final ValueNotifier<MobileAssignedTask?> currentTaskNotifier = ValueNotifier<MobileAssignedTask?>(null);
  static final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String?> taskErrorNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<DateTime?> lastUpdatedNotifier = ValueNotifier<DateTime?>(null);
  static final ValueNotifier<bool> isPollingNotifier = ValueNotifier<bool>(false);

  static bool _hasValidCache() {
    if (_cachedAt == null) {
      return false;
    }
    return DateTime.now().difference(_cachedAt!) <= _cacheTtl;
  }

  static void _setTask(MobileAssignedTask? task) {
    _cachedTask = task;
    _cachedAt = DateTime.now();
    currentTaskNotifier.value = task;
    lastUpdatedNotifier.value = _cachedAt;
  }

  static Future<MobileAssignedTask?> fetchCurrentTask({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasValidCache()) {
      return _cachedTask;
    }

    final authHeaders = await AuthSessionService.getAuthHeaders();
    if (authHeaders.isEmpty) {
      throw Exception('No active session found. Please login again.');
    }

    final uri = Uri.parse('${AppEnv.apiBaseUrl}${ApiRoutes.mobileTaskCurrent}');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          ...authHeaders,
        },
      ).timeout(const Duration(seconds: 12));

      final Map<String, dynamic> payload = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic data = payload['data'];
        if (data is! Map<String, dynamic>) {
          return null;
        }
        
        final task = MobileAssignedTask.fromJson(data);
        return task;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await AuthSessionService.clearSession();
      }

      throw Exception((payload['message'] ?? 'Failed to load current task.').toString());
    } on SocketException {
      throw Exception('Cannot connect to server. Please check your internet and API URL.');
    } on TimeoutException {
      throw Exception('Task request timed out. Please try again.');
    }
  }

  static Future<void> refreshCurrentTask({bool forceRefresh = true}) async {
    isLoadingNotifier.value = true;
    try {
      final task = await fetchCurrentTask(forceRefresh: forceRefresh);
      _setTask(task);
      taskErrorNotifier.value = null;
    } catch (error) {
      taskErrorNotifier.value = error.toString().replaceFirst('Exception: ', '');
      if (_cachedTask != null) {
        currentTaskNotifier.value = _cachedTask;
      } else {
        currentTaskNotifier.value = null;
      }
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  static Future<MobileAssignedTask?> startCurrentTask() async {
    final authHeaders = await AuthSessionService.getAuthHeaders();
    if (authHeaders.isEmpty) {
      throw Exception('No active session found. Please login again.');
    }

    final uri = Uri.parse('${AppEnv.apiBaseUrl}${ApiRoutes.mobileTaskStart}');

    try {
      final response = await http.patch(
        uri,
        headers: {
          'Accept': 'application/json',
          ...authHeaders,
        },
      ).timeout(const Duration(seconds: 12));

      final Map<String, dynamic> payload = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic data = payload['data'];
        if (data is Map<String, dynamic>) {
          final task = MobileAssignedTask.fromJson(data);
          _setTask(task);
          taskErrorNotifier.value = null;
          return task;
        }

        await refreshCurrentTask(forceRefresh: true);
        taskErrorNotifier.value = null;
        return _cachedTask;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await AuthSessionService.clearSession();
      }

      throw Exception((payload['message'] ?? 'Failed to start current task.').toString());
    } on SocketException {
      throw Exception('Cannot connect to server. Please check your internet and API URL.');
    } on TimeoutException {
      throw Exception('Task start request timed out. Please try again.');
    }
  }

  static Future<void> startPeriodicPolling() async {
    await refreshCurrentTask(forceRefresh: true);

    _pollingTimer?.cancel();
    isPollingNotifier.value = false;
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      await refreshCurrentTask(forceRefresh: true);
    });
    isPollingNotifier.value = true;
  }

  static void stopPeriodicPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    isPollingNotifier.value = false;
  }

  static bool get isPollingActive => _pollingTimer != null && _pollingTimer!.isActive;
}