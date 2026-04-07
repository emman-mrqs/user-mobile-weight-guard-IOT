import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  // Prefer the packaged .env value, then dart-define, then the local default.
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/mobile',
  );

  static String get appEnv => dotenv.env['APP_ENV'] ?? String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'local',
  );
}
