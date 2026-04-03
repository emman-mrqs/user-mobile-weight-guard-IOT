import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_env.dart';
import '../screens/activity_data.dart';
import 'api_routes.dart';
import 'auth_session_service.dart';

class MobileActivityService {
  static List<ActivityRecord> _cachedItems = <ActivityRecord>[];
  static DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(seconds: 20);
  static const Duration _pollingInterval = Duration(seconds: 12);
  static Timer? _pollingTimer;

  static final ValueNotifier<List<ActivityRecord>> recordsNotifier =
      ValueNotifier<List<ActivityRecord>>(<ActivityRecord>[]);
  static final ValueNotifier<Map<String, int>> countersNotifier =
      ValueNotifier<Map<String, int>>(<String, int>{
    'all': 0,
    'completed': 0,
    'cancelled': 0,
    'critical': 0,
    'warning': 0,
  });
  static final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<DateTime?> lastUpdatedNotifier = ValueNotifier<DateTime?>(null);
  static final ValueNotifier<bool> isPollingNotifier = ValueNotifier<bool>(false);

  static bool _hasValidCache() {
    if (_cachedAt == null) {
      return false;
    }
    return DateTime.now().difference(_cachedAt!) <= _cacheTtl;
  }

  static ActivitySeverity _severityFromString(String value) {
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'critical':
        return ActivitySeverity.critical;
      case 'warning':
        return ActivitySeverity.warning;
      case 'completed':
        return ActivitySeverity.completed;
      case 'cancelled':
        return ActivitySeverity.cancelled;
      default:
        return ActivitySeverity.normal;
    }
  }

  static String _toDisplayTime(dynamic value) {
    if (value == null) return '--';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return '--';

    final local = date.toLocal();
    int hour = local.hour;
    final String suffix = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final String minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute $suffix';
  }

  static ActivityRecord _recordFromJson(Map<String, dynamic> json) {
    final severity = _severityFromString((json['severity'] ?? 'normal').toString());
    final timeline = (json['timeline'] is List)
        ? (json['timeline'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final double before = (json['beforeKg'] is num) ? (json['beforeKg'] as num).toDouble() : 0.0;
    final double after = (json['afterKg'] is num) ? (json['afterKg'] as num).toDouble() : before;

    return ActivityRecord(
      id: (json['id'] ?? '').toString(),
      tripCode: (json['tripCode'] ?? 'Task').toString(),
      title: (json['title'] ?? 'Activity').toString(),
      summary: (json['summary'] ?? '').toString(),
      locationName: (json['locationName'] ?? 'N/A').toString(),
      startedAt: _toDisplayTime(json['startedAt']),
      endedAt: _toDisplayTime(json['endedAt']),
      beforeKg: before,
      afterKg: after,
      severity: severity,
      timeline: timeline,
    );
  }

  static void _setData({
    required List<ActivityRecord> records,
    required Map<String, int> counters,
  }) {
    _cachedItems = records;
    _cachedAt = DateTime.now();
    recordsNotifier.value = records;
    countersNotifier.value = counters;
    lastUpdatedNotifier.value = _cachedAt;
  }

  static Future<List<ActivityRecord>> fetchActivities({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasValidCache()) {
      return _cachedItems;
    }

    final authHeaders = await AuthSessionService.getAuthHeaders();
    if (authHeaders.isEmpty) {
      throw Exception('No active session found. Please login again.');
    }

    final uri = Uri.parse('${AppEnv.apiBaseUrl}${ApiRoutes.mobileActivities}?filter=all&limit=120');

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
        final List<ActivityRecord> records = (payload['data'] is List)
            ? (payload['data'] as List)
                .whereType<Map<String, dynamic>>()
                .map(_recordFromJson)
                .toList()
            : <ActivityRecord>[];

        final meta = (payload['meta'] is Map<String, dynamic>)
            ? payload['meta'] as Map<String, dynamic>
            : <String, dynamic>{};
        final rawCounters = (meta['counters'] is Map<String, dynamic>)
            ? meta['counters'] as Map<String, dynamic>
            : <String, dynamic>{};

        final counters = <String, int>{
          'all': (rawCounters['all'] is num) ? (rawCounters['all'] as num).toInt() : records.length,
          'completed': (rawCounters['completed'] is num) ? (rawCounters['completed'] as num).toInt() : 0,
          'cancelled': (rawCounters['cancelled'] is num) ? (rawCounters['cancelled'] as num).toInt() : 0,
          'critical': (rawCounters['critical'] is num) ? (rawCounters['critical'] as num).toInt() : 0,
          'warning': (rawCounters['warning'] is num) ? (rawCounters['warning'] as num).toInt() : 0,
        };

        _setData(records: records, counters: counters);
        return records;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await AuthSessionService.clearSession();
      }

      throw Exception((payload['message'] ?? 'Failed to load activities.').toString());
    } on SocketException {
      if (_cachedItems.isNotEmpty) {
        return _cachedItems;
      }
      throw Exception('Cannot connect to server. Please check your internet and API URL.');
    } on TimeoutException {
      if (_cachedItems.isNotEmpty) {
        return _cachedItems;
      }
      throw Exception('Activity request timed out. Please try again.');
    }
  }

  static Future<void> refreshActivities({bool forceRefresh = true}) async {
    isLoadingNotifier.value = true;
    try {
      await fetchActivities(forceRefresh: forceRefresh);
      errorNotifier.value = null;
    } catch (error) {
      errorNotifier.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoadingNotifier.value = false;
    }
  }

  static Future<void> startPeriodicPolling() async {
    await refreshActivities(forceRefresh: true);

    _pollingTimer?.cancel();
    isPollingNotifier.value = false;
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      await refreshActivities(forceRefresh: true);
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
