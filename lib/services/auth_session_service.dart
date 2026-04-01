import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthSessionService {
  static const _storage = FlutterSecureStorage();

  static String? _cachedToken;
  static String? _cachedTokenType;
  static Map<String, String>? _cachedProfile;

  static const _tokenKey = 'auth_token';
  static const _tokenTypeKey = 'auth_token_type';
  static const _firstNameKey = 'auth_first_name';
  static const _lastNameKey = 'auth_last_name';
  static const _emailKey = 'auth_email';
  static const _statusKey = 'auth_status';

  static Future<void> saveSession({
    required String token,
    String tokenType = 'Bearer',
  }) async {
    _cachedToken = token;
    _cachedTokenType = tokenType;

    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _tokenTypeKey, value: tokenType);
  }

  static Future<void> saveUserProfile(Map<String, dynamic> user) async {
    _cachedProfile = {
      'firstName': (user['firstName'] ?? '').toString(),
      'lastName': (user['lastName'] ?? '').toString(),
      'email': (user['email'] ?? '').toString(),
      'status': (user['status'] ?? '').toString(),
    };

    await _storage.write(key: _firstNameKey, value: (user['firstName'] ?? '').toString());
    await _storage.write(key: _lastNameKey, value: (user['lastName'] ?? '').toString());
    await _storage.write(key: _emailKey, value: (user['email'] ?? '').toString());
    await _storage.write(key: _statusKey, value: (user['status'] ?? '').toString());
  }

  static Future<Map<String, String>> getCurrentUserProfile() async {
    if (_cachedProfile != null) {
      return _cachedProfile!;
    }

    final firstName = await _storage.read(key: _firstNameKey) ?? '';
    final lastName = await _storage.read(key: _lastNameKey) ?? '';
    final email = await _storage.read(key: _emailKey) ?? '';
    final status = await _storage.read(key: _statusKey) ?? '';

    _cachedProfile = {
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'status': status,
    };

    return _cachedProfile!;
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }

    _cachedToken = await _storage.read(key: _tokenKey);
    return _cachedToken;
  }

  static Future<String> getTokenType() async {
    if (_cachedTokenType != null && _cachedTokenType!.isNotEmpty) {
      return _cachedTokenType!;
    }

    _cachedTokenType = await _storage.read(key: _tokenTypeKey) ?? 'Bearer';
    return _cachedTokenType!;
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return {};
    }

    final tokenType = await getTokenType();
    return {
      'Authorization': '$tokenType $token',
    };
  }

  static Future<void> clearSession() async {
    _cachedToken = null;
    _cachedTokenType = null;
    _cachedProfile = null;

    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _tokenTypeKey);
    await _storage.delete(key: _firstNameKey);
    await _storage.delete(key: _lastNameKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _statusKey);
  }
}
