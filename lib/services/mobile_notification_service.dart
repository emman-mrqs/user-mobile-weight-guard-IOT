import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_env.dart';
import 'api_routes.dart';
import 'auth_session_service.dart';

class MobileNotificationItem {
  final int recipientId;
  final int notificationId;
  final String title;
  final String message;
  final String type;
  final String priority;
  final String? targetAudience;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;
  final String senderName;

  const MobileNotificationItem({
    required this.recipientId,
    required this.notificationId,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.targetAudience,
    required this.isRead,
    required this.readAt,
    required this.createdAt,
    required this.senderName,
  });

  factory MobileNotificationItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    final sender = (json['sender'] is Map<String, dynamic>)
        ? json['sender'] as Map<String, dynamic>
        : <String, dynamic>{};

    return MobileNotificationItem(
      recipientId: (json['recipientId'] is num) ? (json['recipientId'] as num).toInt() : 0,
      notificationId: (json['notificationId'] is num) ? (json['notificationId'] as num).toInt() : 0,
      title: (json['title'] ?? '').toString().trim(),
      message: (json['message'] ?? '').toString().trim(),
      type: (json['type'] ?? 'announcement').toString().trim().toLowerCase(),
      priority: (json['priority'] ?? 'normal').toString().trim().toLowerCase(),
      targetAudience: (json['targetAudience'] ?? '').toString().trim().isEmpty
          ? null
          : (json['targetAudience']).toString().trim().toLowerCase(),
      isRead: json['isRead'] == true,
      readAt: parseDate(json['readAt']),
      createdAt: parseDate(json['createdAt']),
      senderName: (sender['name'] ?? 'System').toString(),
    );
  }
}

class MobileNotificationInbox {
  final List<MobileNotificationItem> items;
  final int unreadCount;

  const MobileNotificationInbox({
    required this.items,
    required this.unreadCount,
  });
}

class MobileNotificationService {
  static MobileNotificationInbox? _cachedInbox;
  static DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(seconds: 20);
  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  static Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 15);

  static void _setUnreadCount(int value) {
    final safeValue = value < 0 ? 0 : value;
    if (unreadCountNotifier.value != safeValue) {
      unreadCountNotifier.value = safeValue;
    }
  }

  static bool _hasValidCache() {
    if (_cachedInbox == null || _cachedAt == null) {
      return false;
    }

    return DateTime.now().difference(_cachedAt!) <= _cacheTtl;
  }

  static Future<MobileNotificationInbox> fetchInbox({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasValidCache()) {
      _setUnreadCount(_cachedInbox!.unreadCount);
      return _cachedInbox!;
    }

    final authHeaders = await AuthSessionService.getAuthHeaders();
    if (authHeaders.isEmpty) {
      throw Exception('No active session found. Please login again.');
    }

    final uri = Uri.parse('${AppEnv.apiBaseUrl}${ApiRoutes.mobileNotifications}');

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
        final list = (payload['data'] is List)
            ? (payload['data'] as List)
                .whereType<Map<String, dynamic>>()
                .map(MobileNotificationItem.fromJson)
                .toList()
            : <MobileNotificationItem>[];

        final unreadCount = (payload['unreadCount'] is num)
            ? (payload['unreadCount'] as num).toInt()
            : list.where((item) => !item.isRead).length;

        final inbox = MobileNotificationInbox(items: list, unreadCount: unreadCount);
        _cachedInbox = inbox;
        _cachedAt = DateTime.now();
        _setUnreadCount(unreadCount);
        return inbox;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await AuthSessionService.clearSession();
      }

      throw Exception((payload['message'] ?? 'Failed to fetch notifications.').toString());
    } on SocketException {
      if (_cachedInbox != null) {
        return _cachedInbox!;
      }
      throw Exception('Cannot connect to server. Please check your internet and API URL.');
    } on TimeoutException {
      if (_cachedInbox != null) {
        return _cachedInbox!;
      }
      throw Exception('Notification request timed out. Please try again.');
    }
  }

  static Future<void> markAllAsRead() async {
    final authHeaders = await AuthSessionService.getAuthHeaders();
    if (authHeaders.isEmpty) {
      throw Exception('No active session found. Please login again.');
    }

    final uri = Uri.parse('${AppEnv.apiBaseUrl}${ApiRoutes.mobileNotificationsReadAll}');

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

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception((payload['message'] ?? 'Failed to update notifications.').toString());
    }

    // Invalidate cache and let caller request a fresh copy.
    _cachedInbox = null;
    _cachedAt = null;
    _setUnreadCount(0);
  }

  /// Start periodic polling for notification updates (every 15 seconds).
  static Future<void> startPeriodicPolling() async {
    // Fetch immediately on startup
    try {
      await fetchInbox(forceRefresh: true);
    } catch (e) {
      if (kDebugMode) {
        print('Initial notification fetch failed: $e');
      }
    }

    // Stop existing timer if any
    _pollingTimer?.cancel();

    // Start new polling timer
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      try {
        await fetchInbox(forceRefresh: true);
      } catch (e) {
        if (kDebugMode) {
          print('Periodic notification fetch failed: $e');
        }
      }
    });
  }

  /// Stop periodic polling.
  static void stopPeriodicPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Check if polling is currently active.
  static bool get isPollingActive => _pollingTimer != null && _pollingTimer!.isActive;
}
