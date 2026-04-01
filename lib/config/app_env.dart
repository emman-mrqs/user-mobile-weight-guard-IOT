class AppEnv {
  // Override with --dart-define=API_BASE_URL=https://your-production-domain/api/mobile
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/mobile',
  );

  static const String appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'local',
  );
}
