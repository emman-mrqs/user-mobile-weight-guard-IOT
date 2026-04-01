import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_env.dart';
import 'api_routes.dart';
import 'auth_session_service.dart';

class MobileDashboardService {
  static Map<String, dynamic>? _cachedDashboard;
  static DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(seconds: 30);

  static bool _hasValidCache() {
    if (_cachedDashboard == null || _cachedAt == null) {
      return false;
    }

    return DateTime.now().difference(_cachedAt!) <= _cacheTtl;
  }

  static Future<Map<String, dynamic>> fetchDashboard({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasValidCache()) {
      return _cachedDashboard!;
    }

    final authHeaders = await AuthSessionService.getAuthHeaders();
    if (authHeaders.isEmpty) {
      throw Exception('No active session found. Please login again.');
    }

    final uri = Uri.parse('${AppEnv.apiBaseUrl}${ApiRoutes.mobileDashboard}');

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              ...authHeaders,
            },
          )
          .timeout(const Duration(seconds: 12));

      final Map<String, dynamic> payload = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = (payload['data'] is Map<String, dynamic>)
            ? payload['data'] as Map<String, dynamic>
            : <String, dynamic>{};

        _cachedDashboard = data;
        _cachedAt = DateTime.now();
        return data;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await AuthSessionService.clearSession();
      }

      final message = (payload['message'] ?? 'Failed to load dashboard.').toString();
      throw Exception(message);
    } on SocketException {
      if (_cachedDashboard != null) {
        return _cachedDashboard!;
      }
      throw Exception('Cannot connect to server. Please check your internet and API URL.');
    } on TimeoutException {
      if (_cachedDashboard != null) {
        return _cachedDashboard!;
      }
      throw Exception('Dashboard request timed out. Please try again.');
    }
  }
}
