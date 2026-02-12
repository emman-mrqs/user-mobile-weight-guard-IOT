# IOT WeighGuard - Mobile App (Flutter)

The official Flutter mobile application for IOT WeighGuard - a comprehensive IoT fleet management system for real-time GPS tracking, incident monitoring, and vehicle management on the go.

## Overview

The IOT WeighGuard Mobile App brings the power of fleet management to your mobile device. Drivers and dispatchers can monitor vehicles, report incidents, track locations, and manage fleet operations directly from their smartphones.

## Mobile App Features (Planned)

### Driver Features
- **Real-time GPS Tracking**: View live location of your assigned vehicle
- **Incident Reporting**: Quickly report accidents, breakdowns, or safety concerns
- **Route Navigation**: Get turn-by-turn directions to delivery destinations
- **Delivery Management**: Track assigned deliveries and mark as complete
- **Notifications**: Receive push notifications for important updates and alerts
- **Offline Mode**: Continue recording data even without internet connection
- **Performance Metrics**: View your driving performance and safety scores

### Dispatcher/Admin Features
- **Fleet Overview**: Monitor all vehicles in real-time on a map
- **Driver Management**: View driver status, location, and performance
- **Incident Management**: Review and manage reported incidents
- **Route Planning**: Create and optimize delivery routes
- **Real-time Alerts**: Monitor critical fleet events and alerts
- **Reports Access**: View fleet reports and analytics
- **Communication**: Send messages to drivers in the field
- **Emergency Features**: Quick access to SOS and emergency contacts

### Device Integration
- **GPS Services**: Continuous location tracking with battery optimization
- **Camera Integration**: Capture photos for incident reports
- **Maps Integration**: Google Maps and native maps support
- **Sensors**: Weight sensor data integration (if device has capability)
- **Notifications**: Local and push notifications
- **Storage**: Local database for offline functionality

## Prerequisites

### Development Requirements
- **Flutter SDK** (v3.0 or higher) - [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Dart SDK** (comes with Flutter)
- **Android Studio** or **VS Code** with Flutter extension
- **Xcode** (for iOS development) - macOS only
- **Git**

### Device Requirements
- **Android**: Version 7.0 (API level 24) or higher
- **iOS**: Version 12.0 or higher

### Backend Requirements
- Running instance of IOT WeighGuard backend API
- WebSocket support for real-time tracking
- API endpoint configuration

## Project Setup (Coming Soon)

### 1. Flutter Installation

```bash
# Install Flutter
flutter --version

# Update Flutter
flutter upgrade

# Install dependencies
flutter pub get
```

### 2. Project Structure (Planned)

```
IoT-WeighGuard-Mobile/
├── lib/
│   ├── main.dart                      # Application entry point
│   ├── config/
│   │   ├── constants.dart             # App constants and configurations
│   │   ├── routes.dart                # Navigation routes
│   │   └── theme.dart                 # App theming
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   └── splash_screen.dart
│   │   ├── driver/
│   │   │   ├── home_screen.dart
│   │   │   ├── tracking_screen.dart
│   │   │   ├── incident_report_screen.dart
│   │   │   ├── navigation_screen.dart
│   │   │   └── profile_screen.dart
│   │   ├── dispatcher/
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── fleet_map_screen.dart
│   │   │   ├── driver_list_screen.dart
│   │   │   ├── incident_screen.dart
│   │   │   └── settings_screen.dart
│   │   └── common/
│   │       ├── loading_screen.dart
│   │       └── error_screen.dart
│   ├── widgets/
│   │   ├── map_widget.dart            # Reusable map widget
│   │   ├── vehicle_card.dart
│   │   ├── incident_card.dart
│   │   └── custom_buttons.dart
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── vehicle_model.dart
│   │   ├── location_model.dart
│   │   ├── incident_model.dart
│   │   └── driver_model.dart
│   ├── services/
│   │   ├── api_service.dart           # REST API calls
│   │   ├── websocket_service.dart     # WebSocket for real-time data
│   │   ├── auth_service.dart          # Authentication
│   │   ├── location_service.dart      # GPS and location services
│   │   ├── notification_service.dart  # Push notifications
│   │   └── storage_service.dart       # Local database/storage
│   ├── providers/
│   │   ├── auth_provider.dart         # State management for auth
│   │   ├── location_provider.dart     # Real-time location state
│   │   ├── fleet_provider.dart        # Fleet data state
│   │   └── incident_provider.dart     # Incident state
│   └── utils/
│       ├── validators.dart
│       ├── helpers.dart
│       └── logger.dart
├── pubspec.yaml                       # Flutter dependencies
├── pubspec.lock                       # Locked dependency versions
├── android/                           # Android-specific code
├── ios/                               # iOS-specific code
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/
└── test/                              # Unit and widget tests
    ├── widget_test.dart
    └── unit_tests/
```

### 3. Pubspec.yaml Dependencies (Planned)

The following packages will be used:

```yaml
dependencies:
  flutter: sdk: flutter
  
  # State Management
  provider: ^latest_version
  
  # HTTP and Networking
  http: ^latest_version
  web_socket_channel: ^latest_version
  
  # Maps
  google_maps_flutter: ^latest_version
  location: ^latest_version
  geolocator: ^latest_version
  
  # Local Database
  sqflite: ^latest_version
  hive: ^latest_version
  
  # Push Notifications
  firebase_messaging: ^latest_version
  
  # UI/UX
  flutter_spinkit: ^latest_version
  cached_network_image: ^latest_version
  intl: ^latest_version
  
  # Authentication
  flutter_secure_storage: ^latest_version
  
  # Logging
  logger: ^latest_version
```

## Configuration

### API Configuration

Create a `lib/config/api_config.dart` file:

```dart
class ApiConfig {
  static const String baseUrl = 'http://your-server-url:3000';
  static const String wsUrl = 'ws://your-server-url:3000';
  static const Duration timeout = Duration(seconds: 30);
}
```

### Firebase Setup (for push notifications)

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Add Android and iOS apps to your Firebase project
3. Download and configure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

## Building & Running

### Run on Development Device/Emulator

```bash
# List connected devices
flutter devices

# Run the app
flutter run

# Run with specific device
flutter run -d device_id
```

### Build for Android

```bash
# Build APK
flutter build apk

# Build AAB (for Play Store)
flutter build appbundle
```

### Build for iOS

```bash
# Build IPA
flutter build ipa

# Build for simulator
flutter build ios --no-codesign
```

## Features in Development

### Phase 1 (MVP)
- [ ] User authentication (login/register)
- [ ] Basic driver dashboard
- [ ] Real-time GPS tracking
- [ ] Basic incident reporting
- [ ] Push notifications

### Phase 2
- [ ] Offline mode with data sync
- [ ] Map-based fleet view
- [ ] Advanced incident management
- [ ] Route optimization
- [ ] Performance analytics

### Phase 3
- [ ] AR features for navigation
- [ ] Voice commands
- [ ] Advanced reporting
- [ ] Biometric authentication
- [ ] Augmented reality incident documentation

## Mobile App Architecture

### State Management
- **Provider Pattern** for efficient state management
- **ChangeNotifier** for reactive UI updates
- **Providers** for API services and data access

### API Communication
- **REST API** for standard CRUD operations
- **WebSocket** for real-time location tracking and notifications
- **Automatic retry** with exponential backoff
- **Request/Response** logging for debugging

### Local Storage
- **SQLite** for offline capability
- **Hive** for fast caching
- **Secure Storage** for sensitive data (tokens, passwords)

### Real-time Features
- **WebSocket** connection for live GPS tracking
- **Push Notifications** via Firebase Cloud Messaging
- **Background Tasks** for location updates

## Security Considerations

- **JWT Tokens** for API authentication
- **Secure Storage** for sensitive credentials
- **SSL/TLS** encryption for all network communication
- **Data Encryption** for local storage
- **Permission Management** for sensitive device features
- **Token Refresh** mechanism for session management

## Testing

### Unit Tests
```bash
flutter test
```

### Widget Tests
```bash
flutter test --verbose
```

### Integration Tests
```bash
flutter test integration_test/
```

## Performance Optimization

- **Image Caching** to reduce network calls
- **Location Update Rate** optimization based on driving speed
- **Battery Optimization** for GPS tracking
- **Data Synchronization** in batches
- **Lazy Loading** for large data sets
- **Memory Management** with proper disposal of resources

## Troubleshooting

### App won't run
- Ensure Flutter SDK is properly installed: `flutter doctor`
- Check that an emulator/device is connected: `flutter devices`
- Clean build: `flutter clean && flutter pub get && flutter run`

### Location services not working
- Check location permissions in app settings
- Ensure device has GPS enabled
- For Android: Verify fine location permission in AndroidManifest.xml
- For iOS: Verify NSLocationWhenInUseUsageDescription in Info.plist

### WebSocket connection fails
- Ensure backend server is running and accessible
- Check firewall settings allow WebSocket connections
- Verify API base URL is correctly configured
- Check browser console for connection errors

### Push notifications not working
- Ensure Firebase is properly configured
- Check internet connection
- Verify app has notification permissions
- For Android: Ensure notification channel is created
- For iOS: Verify push notification capability is enabled

## Contributing

We welcome contributions! Please see the main README.md for contribution guidelines.

### Contribution Areas Needed
- **UI/UX Design**: Polish and improve user interfaces
- **Performance**: Optimize app speed and battery usage
- **Testing**: Write tests for new features
- **Documentation**: Improve code documentation
- **Features**: Implement planned features from the roadmap

## Development Roadmap

- **Q1 2026**: Complete MVP with basic features
- **Q2 2026**: Launch beta on Play Store and App Store
- **Q3 2026**: Public release with Phase 2 features
- **Q4 2026**: Advanced features and optimizations

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Language Guide](https://dart.dev/guides)
- [Google Maps for Flutter](https://pub.dev/packages/google_maps_flutter)
- [Provider State Management](https://pub.dev/packages/provider)
- [Firebase for Flutter](https://firebase.flutter.dev/)

## Support

For issues, questions, or feature requests:
1. Check the [GitHub Issues](https://github.com/your-repo/issues)
2. Review existing discussions
3. Create a new issue with detailed information

## License

ISC

## Contact

For more information or inquiries about the mobile app, please reach out through GitHub issues or the project repository.

---

**Note**: This is a placeholder README for the Flutter mobile app. Code and implementation details will be added as development progresses.
