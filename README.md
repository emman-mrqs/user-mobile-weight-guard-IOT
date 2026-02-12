# WeighGuard - Mobile App (Flutter)

The official Flutter mobile application for WeighGuard - an IoT-based real-time vehicle overloading detection system using Arduino, GPS, and Flutter for logistics and transportation fleet management.

## Overview

WeighGuard is an IoT-enabled mobile application designed to provide real-time visibility into cargo weight, vehicle location, and shipment integrity during transit. The system focuses on detecting vehicle overloading and cargo loss by continuously monitoring cargo weight and vehicle location in real-time. This prototype uses an RC pickup car for simulation, but the architecture scales to full-size fleet operations.

The mobile app enables drivers to receive instant alerts about overloading conditions and cargo loss incidents, while fleet managers and administrators can monitor the entire fleet from a centralized dashboard.

## Mobile App Features

### Driver Features
- **Real-time Weight Monitoring**: Display current cargo weight from load cell sensors
- **Cargo Status Indicators**: View cargo status (Normal / Overloaded / Cargo Loss Detected)
- **Overloading Alerts**: Instant notification when cargo exceeds safe weight limit
- **Cargo Loss Detection**: Alert when weight decreases unexpectedly during transit with GPS location
- **Real-time GPS Tracking**: View live vehicle location on interactive map
- **Trip History**: Access historical trip data with weight logs and GPS routes
- **Alert Notifications**: Receive immediate push notifications for cargo issues
- **Driver Dashboard**: Quick overview of current shipment status and location
- **Offline Alert Storage**: Alerts stored locally if connectivity is lost

### Admin/Fleet Manager Features
- **Real-Time Fleet Monitoring**: View live vehicle location and cargo weight status from all registered vehicles
- **Weight Status Overview**: Monitor current and historical weight data across fleet
- **Cargo Loss Incident Tracking**: View all cargo loss and overloading incidents with exact GPS location and timestamps
- **User Management (CRUD)**: Create, view, update, and delete system users (drivers, fleet managers, admins)
- **Vehicle Device Management**: Register and manage vehicles, IoT devices (Arduino, sensors), and sensor assignments
- **Historical Data & Reports**: Access trip history, cargo weight logs, and incident records for investigation and auditing
- **Route Analysis**: Identify high-risk routes where cargo loss frequently occurs
- **Dashboard Visualization**: View charts and summaries of fleet activity, cargo loss frequency, and route-based incidents
- **Emergency Alerts**: Monitor critical incidents and respond in real-time
- **Data Export**: Export incident and trip data for compliance and audit purposes

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
WeighGuard-Mobile/
├── lib/
│   ├── main.dart                      # Application entry point
│   ├── config/
│   │   ├── constants.dart             # App constants (weight limits, thresholds)
│   │   ├── routes.dart                # Navigation routes
│   │   └── theme.dart                 # App theming
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart      # Driver/Admin login
│   │   │   ├── register_screen.dart   # New driver registration
│   │   │   └── splash_screen.dart     # App splash/loading screen
│   │   ├── driver/
│   │   │   ├── home_screen.dart       # Driver home with weight display
│   │   │   ├── weight_monitoring_screen.dart  # Real-time weight graph
│   │   │   ├── cargo_status_screen.dart       # Cargo status display
│   │   │   ├── gps_tracking_screen.dart       # Live GPS map
│   │   │   ├── alert_screen.dart              # Alert notifications
│   │   │   ├── trip_history_screen.dart       # Past trips and logs
│   │   │   └── profile_screen.dart
│   │   ├── admin/
│   │   │   ├── dashboard_screen.dart          # Admin dashboard overview
│   │   │   ├── fleet_monitoring_screen.dart   # All vehicles real-time
│   │   │   ├── vehicle_details_screen.dart    # Detailed vehicle info
│   │   │   ├── incident_screen.dart           # Cargo loss/overload incidents
│   │   │   ├── incident_history_screen.dart   # Historical incidents
│   │   │   ├── weight_analytics_screen.dart   # Weight data graphs
│   │   │   ├── route_analysis_screen.dart     # Route risk analysis
│   │   │   ├── user_management_screen.dart    # CRUD for users/drivers
│   │   │   ├── vehicle_management_screen.dart # Register vehicles & sensors
│   │   │   ├── reports_screen.dart            # Generate/view reports
│   │   │   └── settings_screen.dart
│   │   └── common/
│   │       ├── loading_screen.dart
│   │       └── error_screen.dart
│   ├── widgets/
│   │   ├── weight_display_widget.dart        # Large weight display
│   │   ├── cargo_status_indicator.dart       # Status badge (Normal/Alert)
│   │   ├── map_widget.dart                   # Reusable map widget
│   │   ├── alert_card.dart                   # Alert notification card
│   │   ├── incident_card.dart                # Incident history card
│   │   ├── vehicle_card.dart                 # Vehicle list card
│   │   ├── weight_graph_widget.dart          # Weight trend graph
│   │   └── custom_buttons.dart
│   ├── models/
│   │   ├── user_model.dart                   # User/Driver model
│   │   ├── vehicle_model.dart                # Vehicle with sensor info
│   │   ├── weight_data_model.dart            # Weight readings
│   │   ├── location_model.dart               # GPS coordinates
│   │   ├── cargo_loss_incident_model.dart    # Cargo loss event
│   │   ├── overload_incident_model.dart      # Overload event
│   │   ├── trip_model.dart                   # Trip/Journey
│   │   └── alert_model.dart
│   ├── services/
│   │   ├── api_service.dart                  # REST API calls to backend
│   │   ├── websocket_service.dart            # Real-time weight/GPS data
│   │   ├── weight_data_service.dart          # Load cell sensor data
│   │   ├── gps_service.dart                  # GPS location service
│   │   ├── auth_service.dart                 # Authentication
│   │   ├── alert_service.dart                # Alert management
│   │   ├── notification_service.dart         # Push notifications
│   │   └── storage_service.dart              # Local database/storage
│   ├── providers/
│   │   ├── auth_provider.dart                # State management for auth
│   │   ├── weight_provider.dart              # Real-time weight state
│   │   ├── location_provider.dart            # Real-time GPS state
│   │   ├── fleet_provider.dart               # Fleet data state
│   │   ├── incident_provider.dart            # Incident management state
│   │   └── trip_provider.dart                # Current trip state
│   └── utils/
│       ├── validators.dart
│       ├── weight_calculator.dart             # Weight analysis utilities
│       ├── incident_detector.dart             # Cargo loss detection logic
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

### Phase 1 (MVP) - Core Functionality
- [x] User authentication (driver/admin login)
- [ ] Real-time weight monitoring display
- [ ] Cargo status indicators (Normal/Overloaded/Cargo Loss)
- [ ] GPS-based shipment tracking on map
- [ ] Overloading alerts and notifications
- [ ] Cargo loss detection and alerts
- [ ] Alert history logging
- [ ] Basic driver dashboard
- [ ] Push notifications to mobile device
- [ ] Real-time data sync via WebSocket

### Phase 2 - Admin Dashboard & Analytics
- [ ] Admin fleet monitoring dashboard
- [ ] Real-time view of all vehicles and cargo weight
- [ ] Historicalincident tracking (cargo loss + overloading)
- [ ] User management (CRUD for drivers/admins)
- [ ] Vehicle and IoT device management (register Arduino/sensors)
- [ ] Weight trend graphs and analytics
- [ ] Route analysis for high-risk areas
- [ ] Data export for reports
- [ ] Trip history with detailed logs

### Phase 3 - Advanced Features
- [ ] Offline mode with automatic data sync
- [ ] Advanced weight analytics with machine learning
- [ ] Route optimization to reduce cargo loss risk
- [ ] Integration with third-party logistics systems
- [ ] Multi-language support
- [ ] Biometric driver authentication
- [ ] Enhanced security and encryption

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

## Hardware Integration

WeighGuard uses a complete IoT hardware stack for real-time cargo monitoring:

### Core Components

1. **Load Cell Sensors**
   - Mounted on the RC pickup (or vehicle frame)
   - Continuously measure cargo weight
   - Multiple sensors can be connected for multi-point measurement

2. **HX711 Module**
   - Amplifies and converts analog signals from load cells
   - Provides digital weight data to Arduino
   - High precision weight measurement

3. **Arduino Mega**
   - Processes weight data from HX711 module
   - Compares weight against predefined safety limits
   - Detects overloading and cargo loss
   - Processes GPS data
   - Main data aggregator before transmission

4. **GPS Module**
   - Captures real-time geographic location (latitude/longitude)
   - Records location when overloading or cargo loss is detected
   - Enables route tracking and risk area identification

5. **ESP8266 Wi-Fi Module**
   - Transmits real-time weight and GPS data via Wi-Fi
   - Sends data to Flutter mobile app via WebSocket
   - Communicates with Node.js backend via REST APIs
   - Enables remote monitoring and control

### Data Flow
```
Load Cells → HX711 Module → Arduino Mega → ESP8266 → Mobile App (Flutter)
                                    ↓
                              Node.js Backend
                              PostgreSQL Database
```

### Prototype Setup (RC Pickup Car)
- Demonstrates real-world logistics scenarios at smaller scale
- Load cell mounted on RC pickup cargo bed
- GPS module tracks vehicle location
- Arduino Mega controls sensor data acquisition
- ESP8266 transmits data wirelessly

### Production Deployment
- Same architecture scales to full-size commercial vehicles
- Multiple load cells on different axles
- Industrial-grade GPS receivers for highways
- Cellular backup (LTE) in addition to Wi-Fi
- Fleet server infrastructure with redundancy

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

### Weight data not displaying
- Verify Arduino and load cell sensors are powered on
- Check HX711 module is properly calibrated
- Ensure ESP8266 is connected to Wi-Fi network
- Verify API endpoint is correctly configured in app config
- Check Arduino code is transmitting weight data

### GPS location not updating
- Check GPS module is powered and receiving satellites
- Verify location permissions are granted in app settings
- For Android: Ensure fine location permission in AndroidManifest.xml
- For iOS: Verify NSLocationWhenInUseUsageDescription in Info.plist
- Check GPS module has clear sky view

### Cargo loss alerts not working
- Verify weight threshold is correctly configured
- Ensure real-time weight updates are being received
- Check notification permissions are enabled
- For Android: Verify notification channel is created
- For iOS: Verify push notification capability is enabled
- Check Firebase Cloud Messaging is properly configured

### WebSocket connection fails
- Ensure backend server is running and accessible
- Check firewall settings allow WebSocket connections
- Verify API base URL is correctly configured
- Verify ESP8266 has internet connectivity
- Check network bandwidth is sufficient for real-time updates

### No incidents showing in admin dashboard
- Verify incidents are being recorded in PostgreSQL database
- Check backend API is returning incident data
- Ensure user has admin privileges to view incidents
- Verify incident filter dates are correct
- Check network connectivity to backend server

### Historical data not syncing
- Verify local database has offline data
- Ensure app has internet connectivity for sync
- Check backend database is accepting POST requests
- Verify token/authentication is valid
- Manual sync: Pull to refresh on history screen

## System Architecture

### Data Flow in WeighGuard
1. **Hardware Layer**: Load cells → HX711 → Arduino Mega → ESP8266
2. **Wireless Layer**: ESP8266 broadcasts via Wi-Fi
3. **Mobile Layer**: Flutter app receives via WebSocket
4. **Backend Layer**: Node.js API stores data in PostgreSQL
5. **Analysis Layer**: Admin dashboard processes and visualizes data

### Real-time vs Historical Data
- **Real-time**: Weight and GPS data streamed via WebSocket for immediate display
- **Historical**: Data stored in PostgreSQL for incident review and analytics
- **Offline**: Local database caches data if connectivity is lost, syncs when restored

## Contributing

We welcome contributions to WeighGuard! Please see the main README.md for detailed contribution guidelines.

### Contribution Areas Needed
- **IoT Integration**: Arduino and ESP8266 firmware improvements
- **Weight Analytics**: Algorithms for detecting cargo loss patterns
- **UI/UX**: Improve weight display and alert interfaces
- **Performance**: Optimize battery usage for continuous GPS tracking
- **Testing**: Unit tests for weight calculation and alert detection
- **Documentation**: Hardware setup guides and integration documentation
- **Features**: Implement planned Phase 2 and Phase 3 features from roadmap

### Mobile-Specific Guidelines

#### Weight Monitoring Features
- All weight-related calculations must handle sensor noise and calibration
- Weight threshold changes should require admin confirmation
- Zero-weight states should be handled gracefully
- Historical weight data must be accurate for auditing

#### GPS & Location Features
- Location updates must respect user privacy
- GPS accuracy validation before using in incident detection
- Fallback to cached location if GPS signal is lost
- Location data should not be transmitted more frequently than necessary

#### Alert System
- All alerts must be reversible if false positive
- Alert history must include reason and resolution
- Critical alerts should always use local notifications (not just push)
- Silent fail-over if notification service is unavailable

#### Hardware Communication
- Graceful handling of ESP8266/Arduino disconnection
- Automatic reconnection with exponential backoff
- Local buffering of sensor data during disconnection
- Data integrity validation from hardware sources

## Development Roadmap

The WeighGuard mobile app follows a phased development approach:

### Current Phase (MVP Development)
- **Focus**: Core weight monitoring and GPS tracking
- **Target**: Functional prototype with RC pickup car
- **Deliverables**: 
  - Real-time weight display
  - Overloading detection
  - Cargo loss alerts
  - Basic map display
  - Alert history

### Q1 2026 - MVP Release
- Complete core functionality
- Full driver dashboard
- Initial admin dashboard
- Basic reporting features
- Internal testing and QA

### Q2 2026 - Beta Testing
- Beta release to select partners
- Performance optimization
- Security hardening
- Expanded admin features
- Integration testing with full fleet

### Q3 2026 - Production Release
- Official app store releases (iOS & Android)
- Advanced analytics
- Route risk analysis
- Multi-language support
- Enterprise features for large fleets

### Q4 2026 & Beyond - Enhancement
- Machine learning for predictive alerts
- AI-based route optimization
- Integration with third-party TMS systems
- Mobile app features expansion
- Scalability improvements for enterprise deployments

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

## Contact & Support

For issues, questions, or feature requests:
1. Check the [GitHub Issues](https://github.com/your-repo/issues)
2. Review existing discussions
3. Create a new issue with detailed information including:
   - Device type and OS version
   - App version
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots or logs if applicable

### Quick Links
- [Main Project Repository](https://github.com/your-repo/weighguard)
- [Backend API Documentation](../README.md)
- [Hardware Setup Guide](../src/utils/HARDWARE_SETUP.md)
- [Issues & Bug Reports](https://github.com/your-repo/issues)

---

**Note**: This README is based on the WeighGuard IoT proposal. Code and implementation details will be added as development progresses.
