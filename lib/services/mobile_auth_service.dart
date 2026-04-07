import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_env.dart';
import 'api_routes.dart';
import 'auth_session_service.dart';

class MobileAuthService {
  static const Duration _loginTimeout = Duration(seconds: 15);

  static Future<void> sendForgotPasswordCode({required String email}) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}${ApiRoutes.mobileAuthForgotPassword}');

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email,
            }),
          )
          .timeout(_loginTimeout);
    } on SocketException {
      throw Exception('Cannot connect to server. Please check your internet and API URL.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on Exception {
      throw Exception('Failed to send reset code. Please try again.');
    }

    final Map<String, dynamic> data =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
        await AuthSessionService.setMustChangePasswordRequired(false);
      return;
    }

    final message = (data['message'] ?? 'Failed to send reset code.').toString();
    throw Exception(message);
  }

  static Future<void> verifyForgotPasswordCode({
    required String email,
    required String code,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}${ApiRoutes.mobileAuthForgotPasswordVerifyCode}');

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'code': code,
            }),
          )
          .timeout(_loginTimeout);
    } on SocketException {
      throw Exception('Cannot connect to server. Please check your internet and API URL.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on Exception {
      throw Exception('Failed to verify code. Please try again.');
    }

    final Map<String, dynamic> data =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await AuthSessionService.setMustChangePasswordRequired(false);
      return;
    }

    final message = (data['message'] ?? 'Failed to verify code.').toString();
    throw Exception(message);
  }

  static Future<void> resetForgotPassword({
    required String email,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}${ApiRoutes.mobileAuthForgotPasswordResetPassword}');

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'code': code,
              'newPassword': newPassword,
              'confirmPassword': confirmPassword,
            }),
          )
          .timeout(_loginTimeout);
    } on SocketException {
      throw Exception('Cannot connect to server. Please check your internet and API URL.');
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    } on Exception {
      throw Exception('Failed to reset password. Please try again.');
    }

    final Map<String, dynamic> data =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final message = (data['message'] ?? 'Failed to reset password.').toString();
    throw Exception(message);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${AppEnv.apiBaseUrl}${ApiRoutes.mobileAuthLogin}');

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(_loginTimeout);
    } on SocketException {
      throw Exception('Cannot connect to server. Please check your internet and API URL.');
    } on HttpException {
      throw Exception('Server connection failed. Please try again.');
    } on FormatException {
      throw Exception('Invalid server response format.');
    } on TimeoutException {
      throw Exception('Login request timed out. Please try again.');
    } on Exception {
      throw Exception('Login request timed out. Please check your internet/server and try again.');
    }

    final Map<String, dynamic> data =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final token = (data['token'] ?? '').toString();
      final tokenType = (data['tokenType'] ?? 'Bearer').toString();
      final user = data['user'];

      if (token.isNotEmpty) {
        await AuthSessionService.saveSession(token: token, tokenType: tokenType);
      }

      if (user is Map<String, dynamic>) {
        await AuthSessionService.saveUserProfile(user);
      }

      return data;
    }

    final message = (data['message'] ?? 'Login failed.').toString();
    throw Exception(message);
  }

  static Future<bool> validateSession() async {
    final authHeaders = await AuthSessionService.getAuthHeaders();
    if (authHeaders.isEmpty) {
      return false;
    }

    final uri = Uri.parse('${AppEnv.apiBaseUrl}${ApiRoutes.mobileAuthMe}');

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              ...authHeaders,
            },
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = response.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body) as Map<String, dynamic>;
        final dynamic user = data['user'];
        if (user is Map<String, dynamic>) {
          await AuthSessionService.saveUserProfile(user);
        }
        return true;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await AuthSessionService.clearSession();
        return false;
      }

      return true;
    } on Exception {
      // Offline/temporary network issue: preserve local session.
      return true;
    }
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final authHeaders = await AuthSessionService.getAuthHeaders();
    if (authHeaders.isEmpty) {
      throw Exception('No active session found. Please login again.');
    }

    final uri = Uri.parse('${AppEnv.apiBaseUrl}${ApiRoutes.mobileAuthChangePassword}');

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              ...authHeaders,
            },
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
              'confirmPassword': confirmPassword,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } on SocketException {
      throw Exception('Cannot connect to server. Please check your internet and API URL.');
    } on TimeoutException {
      // Retry once for transient latency spikes.
      try {
        response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                ...authHeaders,
              },
              body: jsonEncode({
                'currentPassword': currentPassword,
                'newPassword': newPassword,
                'confirmPassword': confirmPassword,
              }),
            )
            .timeout(const Duration(seconds: 20));
      } on Exception {
        throw Exception('Password change request timed out. Make sure backend server is running, then try again.');
      }
    } on Exception {
      throw Exception('Password change request timed out. Please try again.');
    }

    final Map<String, dynamic> data =
        response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      await AuthSessionService.setMustChangePasswordRequired(false);
      return;
    }

    final message = (data['message'] ?? 'Failed to change password.').toString();
    throw Exception(message);
  }
}
