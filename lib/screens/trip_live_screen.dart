import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/app_tab_service.dart';
import '../services/mobile_task_service.dart';
import '../services/trip_overlay_service.dart';
import 'task_detail_screen.dart';
import '../widget/navbar.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> with TickerProviderStateMixin {
  static const String _osrmServiceUrl =
      'https://router.project-osrm.org/route/v1/driving';
  static const LatLng _defaultCenter = LatLng(10.3090, 123.8930);
  static const double _destinationReachedThresholdMeters = 30;
  static const double _routeSnapThresholdMeters = 45;
  static const double _routeRerouteThresholdMeters = 80;
  static const double _cameraUpdateMinDistanceMeters = 2.5;
  static const double _cameraLeadSeconds = 4.0;
  static const double _cameraLeadMinMeters = 18;
  static const double _cameraLeadMaxMeters = 140;
  static const double _followZoomMin = 15.2;
  static const double _followZoomMax = 18.0;
  static const double _floatingBottomNavChipClearance = 110;
  static const Duration _routeRerouteCooldown = Duration(seconds: 8);
  static const Duration _cameraFollowMinInterval = Duration(
    milliseconds: 420,
  );

  final MapController _mapController = MapController();

  MobileAssignedTask? _task;
  List<LatLng> _routeCoordinates = <LatLng>[];
  List<LatLng> _completedPath = <LatLng>[];
  List<LatLng> _remainingPath = <LatLng>[];
  List<_RouteTurnStep> _liveTurnSteps = <_RouteTurnStep>[];

  LatLng? _vehiclePosition;
  double _vehicleHeadingRad = 0;
  double _mapZoom = 13.8;
  double _mapRotationDeg = 0;
  LatLng _mapCenter = _defaultCenter;

  bool _isLoadingRoute = false;
  bool _isAutoFollow = true;
  bool _showTopTurnByTurn = true;
  bool _showBottomNavigation = true;
  String _routeProgressStatus = 'Waiting for route updates';
  String? _routeError;
  DateTime? _lastRerouteAt;
  DateTime? _lastCameraFollowAt;
  String? _lastArrivalHandledKey;
  bool _isHandlingArrival = false;

  late final AnimationController _vehicleSmoothingController;
  LatLng? _vehicleAnimFrom;
  LatLng? _vehicleAnimTo;
  double _vehicleHeadingFrom = 0;
  double _vehicleHeadingTo = 0;
  AnimationController? _cameraMoveController;
  late final AnimationController _pulseController;
  String _routeSignature = '';
  int _routeLoadToken = 0;

  @override
  void initState() {
    super.initState();
    _vehicleSmoothingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )
      ..addListener(() {
        final LatLng? from = _vehicleAnimFrom;
        final LatLng? to = _vehicleAnimTo;
        if (from == null || to == null) {
          return;
        }

        final double t = Curves.linear.transform(
          _vehicleSmoothingController.value,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _vehiclePosition = _lerpLatLng(from, to, t);
          _vehicleHeadingRad = _lerpAngle(_vehicleHeadingFrom, _vehicleHeadingTo, t);
        });
      });
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    MobileTaskService.currentTaskNotifier.addListener(_handleTaskUpdate);
    AppTabService.tripNavigationRevealNotifier.addListener(
      _handleTripNavigationReveal,
    );
    _publishMainBottomNavVisibility();
    _handleTaskUpdate();
  }

  @override
  void dispose() {
    TripOverlayService.setMainBottomNavHidden(false);
    MobileTaskService.currentTaskNotifier.removeListener(_handleTaskUpdate);
    AppTabService.tripNavigationRevealNotifier.removeListener(
      _handleTripNavigationReveal,
    );
    _vehicleSmoothingController.dispose();
    _cameraMoveController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTripNavigationReveal() {
    if (!mounted) {
      return;
    }

    setState(() {
      _showTopTurnByTurn = true;
      _showBottomNavigation = true;
      _isAutoFollow = true;
    });
    _publishMainBottomNavVisibility();

    final MobileAssignedTask? task = _task;
    if (task != null) {
      _recenterToVehicle(task);
    }
  }

  void _publishMainBottomNavVisibility() {
    final bool shouldHide =
        _task != null &&
        _showBottomNavigation &&
        _canShowNavigationForTask(_task!);
    TripOverlayService.setMainBottomNavHidden(shouldHide);
  }

  bool _canShowNavigationForTask(MobileAssignedTask task) {
    final String status = task.dispatchStatus.toLowerCase();

    if (status == 'pending') {
      return false;
    }

    if (status == 'completed' || status == 'cancelled') {
      return false;
    }

    return true;
  }

  void _handleTaskUpdate() {
    final MobileAssignedTask? task =
        MobileTaskService.currentTaskNotifier.value;
    _syncTask(task);
  }

  Future<void> _syncTask(MobileAssignedTask? task) async {
    if (!mounted) {
      return;
    }

    if (task == null) {
      setState(() {
        _task = null;
        _routeCoordinates = <LatLng>[];
        _completedPath = <LatLng>[];
        _remainingPath = <LatLng>[];
        _liveTurnSteps = <_RouteTurnStep>[];
        _vehiclePosition = null;
        _mapRotationDeg = 0;
        _showTopTurnByTurn = true;
        _showBottomNavigation = true;
        _routeProgressStatus = 'Waiting for route updates';
        _routeError = null;
        _isLoadingRoute = false;
        _routeSignature = '';
      });
      _publishMainBottomNavVisibility();
      return;
    }

    if (task.dispatchStatus == 'in_transit') {
      AppTabService.clearPickupArrived(task.taskId);
    }

    if (!_canShowNavigationForTask(task)) {
      setState(() {
        _task = task;
        _routeCoordinates = <LatLng>[];
        _completedPath = <LatLng>[];
        _remainingPath = <LatLng>[];
        _liveTurnSteps = <_RouteTurnStep>[];
        _isLoadingRoute = false;
        _routeError = null;
        _routeProgressStatus = 'Navigation hidden for current task stage';
      });
      _publishMainBottomNavVisibility();
      return;
    }

    final String signature = _buildRouteSignature(task);
    final LatLng livePosition = _resolveVehiclePosition(task);
    final bool sameTask = _task != null && _task!.taskId == task.taskId;

    if (sameTask && signature == _routeSignature) {
      setState(() {
        _task = task;
      });
      _publishMainBottomNavVisibility();
      if (_vehiclePosition == null ||
          _distanceMeters(_vehiclePosition!, livePosition) > 3) {
        _animateVehicleTo(livePosition);
      }
      _updateRouteProgress(livePosition, task);
      return;
    }

    _routeSignature = signature;
    _task = task;
    _routeError = null;

    setState(() {
      if (!sameTask) {
        _showTopTurnByTurn = true;
        _showBottomNavigation = true;
      }
      _isLoadingRoute = true;
      _routeProgressStatus = 'Loading navigation route...';
    });
    _publishMainBottomNavVisibility();

    _animateVehicleTo(livePosition, instant: _vehiclePosition == null);
    await _loadRouteForTask(task, livePosition);
  }

  Future<void> _loadRouteForTask(
    MobileAssignedTask task,
    LatLng livePosition,
  ) async {
    final int token = ++_routeLoadToken;
    final LatLng destination = _navigationTarget(task);
    final LatLng startPoint = _routeStartPoint(task, livePosition);

    _RouteData routeData = _RouteData(
      coordinates: <LatLng>[startPoint, destination],
      steps: <_RouteTurnStep>[],
    );
    try {
      routeData = await _fetchRoute(startPoint, destination);
    } catch (_) {
      routeData = _RouteData(
        coordinates: <LatLng>[startPoint, destination],
        steps: <_RouteTurnStep>[],
      );
    }

    if (!mounted || token != _routeLoadToken) {
      return;
    }

    setState(() {
      _routeCoordinates = routeData.coordinates;
      _liveTurnSteps = routeData.steps;
      _isLoadingRoute = false;
      _routeError = routeData.coordinates.length < 2
          ? 'Unable to load navigation route.'
          : null;
    });

    _applyRouteProgress(livePosition, task, fitCamera: true);
  }

  Future<_RouteData> _fetchRoute(LatLng start, LatLng destination) async {
    final Uri uri = Uri.parse(
      '$_osrmServiceUrl/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson&steps=true',
    );

    final http.Response response = await http
        .get(uri, headers: <String, String>{'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Route request failed (${response.statusCode}).');
    }

    if (response.body.isEmpty) {
      throw Exception('Route response was empty.');
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Route response had an unexpected shape.');
    }

    final Map<String, dynamic> payload = decoded;

    final dynamic routes = payload['routes'];
    if (routes is! List || routes.isEmpty) {
      throw Exception('Route response had no routes.');
    }

    final Map<String, dynamic> routePayload =
        routes.first is Map<String, dynamic>
        ? routes.first as Map<String, dynamic>
        : <String, dynamic>{};

    final dynamic geometry = routePayload['geometry'];
    final dynamic coordinates = geometry is Map<String, dynamic>
        ? geometry['coordinates']
        : null;
    if (coordinates is! List || coordinates.length < 2) {
      throw Exception('Route response had no coordinates.');
    }

    final List<LatLng> decodedCoordinates = coordinates
        .whereType<List<dynamic>>()
        .where((point) => point.length >= 2)
        .map(
          (point) => LatLng(
            (point[1] as num).toDouble(),
            (point[0] as num).toDouble(),
          ),
        )
        .toList(growable: false);

    final dynamic legs = routePayload['legs'];
    final List<_RouteTurnStep> steps = <_RouteTurnStep>[];

    if (legs is List) {
      for (final dynamic leg in legs.whereType<Map<String, dynamic>>()) {
        final dynamic legSteps = leg['steps'];
        if (legSteps is! List) {
          continue;
        }

        for (final dynamic rawStep
            in legSteps.whereType<Map<String, dynamic>>()) {
          final _RouteTurnStep? parsed = _parseRouteTurnStep(
            rawStep,
            decodedCoordinates,
          );
          if (parsed != null) {
            steps.add(parsed);
          }
        }
      }
    }

    return _RouteData(coordinates: decodedCoordinates, steps: steps);
  }

  _RouteTurnStep? _parseRouteTurnStep(
    Map<String, dynamic> rawStep,
    List<LatLng> routeCoordinates,
  ) {
    final double? distanceMeters = (rawStep['distance'] is num)
        ? (rawStep['distance'] as num).toDouble()
        : null;
    if (distanceMeters == null || distanceMeters <= 0) {
      return null;
    }

    final Map<String, dynamic> maneuver =
        (rawStep['maneuver'] is Map<String, dynamic>)
        ? rawStep['maneuver'] as Map<String, dynamic>
        : <String, dynamic>{};

    final String type = (maneuver['type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final String modifier = (maneuver['modifier'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final String roadName = (rawStep['name'] ?? '').toString().trim();
    final String instruction = _buildManeuverInstruction(type, modifier);

    int routeIndex = 0;
    final dynamic location = maneuver['location'];
    if (location is List && location.length >= 2) {
      final double? lng = (location[0] is num)
          ? (location[0] as num).toDouble()
          : null;
      final double? lat = (location[1] is num)
          ? (location[1] as num).toDouble()
          : null;
      if (lat != null && lng != null && routeCoordinates.isNotEmpty) {
        routeIndex = _findNearestRouteIndex(routeCoordinates, LatLng(lat, lng));
      }
    }

    if (routeIndex < 0) {
      routeIndex = 0;
    }

    return _RouteTurnStep(
      routeIndex: routeIndex,
      distanceMeters: distanceMeters,
      maneuverType: type,
      maneuverModifier: modifier,
      instruction: instruction,
      roadName: roadName,
    );
  }

  String _buildManeuverInstruction(String type, String modifier) {
    if (type == 'arrive') {
      return 'arrive at destination';
    }
    if (type == 'roundabout' || type == 'rotary') {
      return 'enter the roundabout';
    }

    switch (modifier) {
      case 'left':
        return 'turn left';
      case 'right':
        return 'turn right';
      case 'slight left':
        return 'keep slightly left';
      case 'slight right':
        return 'keep slightly right';
      case 'sharp left':
        return 'turn sharply left';
      case 'sharp right':
        return 'turn sharply right';
      case 'uturn':
        return 'make a U-turn';
      case 'straight':
        return 'continue straight';
      default:
        return type == 'depart' ? 'depart' : 'continue';
    }
  }

  LatLng _routeStartPoint(MobileAssignedTask task, LatLng fallback) {
    if (task.liveLatitude != null && task.liveLongitude != null) {
      return LatLng(task.liveLatitude!, task.liveLongitude!);
    }
    if (task.pickupLat != 0 || task.pickupLng != 0) {
      return LatLng(task.pickupLat, task.pickupLng);
    }
    return fallback;
  }

  bool _isPickupLeg(MobileAssignedTask task) {
    return task.dispatchStatus == 'pending' || task.dispatchStatus == 'active';
  }

  LatLng _navigationTarget(MobileAssignedTask task) {
    if (_isPickupLeg(task)) {
      return LatLng(task.pickupLat, task.pickupLng);
    }
    return LatLng(task.destinationLat, task.destinationLng);
  }

  LatLng _resolveVehiclePosition(MobileAssignedTask task) {
    if (task.liveLatitude != null && task.liveLongitude != null) {
      return LatLng(task.liveLatitude!, task.liveLongitude!);
    }
    if (task.pickupLat != 0 || task.pickupLng != 0) {
      return LatLng(task.pickupLat, task.pickupLng);
    }
    return _defaultCenter;
  }

  String _buildRouteSignature(MobileAssignedTask task) {
    return [
      task.taskId,
      task.dispatchStatus,
      task.pickupLat.toStringAsFixed(5),
      task.pickupLng.toStringAsFixed(5),
      task.destinationLat.toStringAsFixed(5),
      task.destinationLng.toStringAsFixed(5),
    ].join('|');
  }

  void _animateVehicleTo(LatLng target, {bool instant = false}) {
    final LatLng start = _vehiclePosition ?? target;
    final double distanceMeters = _distanceMeters(start, target);
    final double startHeading = _vehicleHeadingRad;
    final double endHeading = _bearingRadians(start, target);

    if (instant || distanceMeters < 2.0) {
      _vehicleSmoothingController.stop();
      _vehicleAnimFrom = target;
      _vehicleAnimTo = target;
      _vehicleHeadingFrom = endHeading;
      _vehicleHeadingTo = endHeading;
      setState(() {
        _vehiclePosition = target;
        _vehicleHeadingRad = endHeading;
      });
      return;
    }

    final double currentT = _vehicleSmoothingController.isAnimating
        ? _vehicleSmoothingController.value
        : 1.0;
    final LatLng? activeFrom = _vehicleAnimFrom;
    final LatLng? activeTo = _vehicleAnimTo;
    final LatLng liveFrom =
        (activeFrom != null && activeTo != null)
        ? _lerpLatLng(activeFrom, activeTo, currentT)
        : start;
    final double liveHeading = _vehicleSmoothingController.isAnimating
        ? _lerpAngle(_vehicleHeadingFrom, _vehicleHeadingTo, currentT)
        : startHeading;

    _vehicleAnimFrom = liveFrom;
    _vehicleAnimTo = target;
    _vehicleHeadingFrom = liveHeading;
    _vehicleHeadingTo = endHeading;

    final int durationMs = (distanceMeters * 10).round().clamp(180, 480);
    _vehicleSmoothingController.duration = Duration(milliseconds: durationMs);
    _vehicleSmoothingController
      ..stop()
      ..value = 0
      ..forward();
  }

  void _animateCameraTo(
    LatLng target, {
    double? zoom,
    Duration duration = const Duration(milliseconds: 260),
  }) {
    final double centerShift = _distanceMeters(_mapCenter, target);
    final double zoomShift = ((zoom ?? _mapZoom) - _mapZoom).abs();
    if (centerShift < _cameraUpdateMinDistanceMeters && zoomShift < 0.05) {
      return;
    }

    final AnimationController? previousController = _cameraMoveController;
    _cameraMoveController = null;
    previousController?.dispose();

    final LatLng from = _mapCenter;
    final double fromZoom = _mapZoom;
    final double toZoom = zoom ?? _mapZoom;
    final double fromRotation = _mapRotationDeg;
    final double toRotation = _isAutoFollow
        ? -(_vehicleHeadingRad * 180 / math.pi)
        : 0;

    final AnimationController controller = AnimationController(
      vsync: this,
      duration: duration,
    );
    _cameraMoveController = controller;

    controller.addListener(() {
      final double t = Curves.easeInOut.transform(controller.value);
      _mapCenter = _lerpLatLng(from, target, t);
      _mapZoom = _lerpDouble(fromZoom, toZoom, t);
      _mapRotationDeg = _lerpDouble(fromRotation, toRotation, t);

      final dynamic dynamicController = _mapController;
      try {
        dynamicController.moveAndRotate(_mapCenter, _mapZoom, _mapRotationDeg);
      } catch (_) {
        _mapController.move(_mapCenter, _mapZoom);
      }
    });

    controller.forward();
  }

  LatLng _destinationPoint(
    LatLng from,
    double headingRad,
    double distanceMeters,
  ) {
    const double earthRadius = 6371000;
    final double lat1 = _degToRad(from.latitude);
    final double lng1 = _degToRad(from.longitude);
    final double angularDistance = distanceMeters / earthRadius;

    final double lat2 = math.asin(
      (math.sin(lat1) * math.cos(angularDistance)) +
          (math.cos(lat1) * math.sin(angularDistance) * math.cos(headingRad)),
    );

    final double lng2 =
        lng1 +
        math.atan2(
          math.sin(headingRad) * math.sin(angularDistance) * math.cos(lat1),
          math.cos(angularDistance) - (math.sin(lat1) * math.sin(lat2)),
        );

    return LatLng(lat2 * 180 / math.pi, lng2 * 180 / math.pi);
  }

  LatLng _cameraTargetForNavigation(
    LatLng vehiclePosition,
    MobileAssignedTask task,
  ) {
    final double heading = _cameraHeadingForFollow(vehiclePosition, task);
    final double lookAheadMeters =
        ((task.liveSpeedKmh * 1000 / 3600) * _cameraLeadSeconds).clamp(
          _cameraLeadMinMeters,
          _cameraLeadMaxMeters,
        );
    return _destinationPoint(vehiclePosition, heading, lookAheadMeters);
  }

  double _followZoomForTask(MobileAssignedTask task) {
    final double speed = task.liveSpeedKmh.clamp(0, 90);
    final double t = (speed / 90).clamp(0, 1);
    // Closer zoom at low speed, slightly wider zoom at higher speed.
    return _lerpDouble(_followZoomMax, _followZoomMin, t);
  }

  double _cameraHeadingForFollow(
    LatLng vehiclePosition,
    MobileAssignedTask task,
  ) {
    if (_routeCoordinates.length >= 2) {
      final int nearestIndex = _findNearestRouteIndex(
        _routeCoordinates,
        vehiclePosition,
      );
      if (nearestIndex >= 0) {
        final int nextIndex = (nearestIndex + 1).clamp(
          0,
          _routeCoordinates.length - 1,
        );
        if (nextIndex != nearestIndex) {
          return _bearingRadians(
            _routeCoordinates[nearestIndex],
            _routeCoordinates[nextIndex],
          );
        }
      }
    }

    if (task.liveHeading != null) {
      return _degToRad(task.liveHeading!);
    }

    return _vehicleHeadingRad;
  }

  void _updateRouteProgress(LatLng vehiclePosition, MobileAssignedTask task) {
    if (_routeCoordinates.length < 2) {
      return;
    }

    final LatLng nearestPoint =
        _findNearestRoutePoint(_routeCoordinates, vehiclePosition) ??
        _routeCoordinates.first;
    final double deviationMeters = _distanceMeters(
      vehiclePosition,
      nearestPoint,
    );
    final LatLng target = _navigationTarget(task);
    final double destinationDistance = _distanceMeters(vehiclePosition, target);

    if (deviationMeters > _routeRerouteThresholdMeters) {
      final DateTime now = DateTime.now();
      if (_lastRerouteAt == null ||
          now.difference(_lastRerouteAt!) >= _routeRerouteCooldown) {
        _lastRerouteAt = now;
        _routeProgressStatus = 'Rerouting from live vehicle position';
        _routeLoadToken += 1;
        _loadRouteForTask(task, vehiclePosition);
      }
    } else if (deviationMeters > _routeSnapThresholdMeters) {
      _routeProgressStatus = 'Off route by ${deviationMeters.round()}m';
    } else if (destinationDistance <= _destinationReachedThresholdMeters) {
      _routeProgressStatus = _isPickupLeg(task)
          ? 'Pickup point reached'
          : 'Destination reached';
      unawaited(_handleArrival(task));
    } else {
      _routeProgressStatus = 'On planned route';
    }

    final int nearestIndex = _findNearestRouteIndex(
      _routeCoordinates,
      vehiclePosition,
    );
    if (nearestIndex < 0) {
      return;
    }

    final List<LatLng> completed = _routeCoordinates
        .take(math.min(_routeCoordinates.length, math.max(2, nearestIndex + 1)))
        .toList(growable: false);
    final List<LatLng> remaining = _routeCoordinates
        .skip(math.max(0, nearestIndex))
        .toList(growable: false);

    setState(() {
      _completedPath = completed;
      _remainingPath = remaining;
      if (_isAutoFollow) {
        final DateTime now = DateTime.now();
        final bool shouldUpdateCamera =
            _lastCameraFollowAt == null ||
            now.difference(_lastCameraFollowAt!) >= _cameraFollowMinInterval;
        if (shouldUpdateCamera) {
          _lastCameraFollowAt = now;
          _animateCameraTo(
            _cameraTargetForNavigation(vehiclePosition, task),
            zoom: _followZoomForTask(task),
          );
        }
      }
    });
  }

  void _applyRouteProgress(
    LatLng vehiclePosition,
    MobileAssignedTask task, {
    required bool fitCamera,
  }) {
    if (_routeCoordinates.length < 2) {
      return;
    }

    final int nearestIndex = _findNearestRouteIndex(
      _routeCoordinates,
      vehiclePosition,
    );
    if (nearestIndex < 0) {
      return;
    }

    final List<LatLng> completed = _routeCoordinates
        .take(math.min(_routeCoordinates.length, math.max(2, nearestIndex + 1)))
        .toList(growable: false);
    final List<LatLng> remaining = _routeCoordinates
        .skip(math.max(0, nearestIndex))
        .toList(growable: false);

    setState(() {
      _completedPath = completed;
      _remainingPath = remaining;
      _routeProgressStatus = 'On planned route';
      if (fitCamera) {
        final DateTime now = DateTime.now();
        final bool shouldUpdateCamera =
            _lastCameraFollowAt == null ||
            now.difference(_lastCameraFollowAt!) >= _cameraFollowMinInterval;
        if (shouldUpdateCamera) {
          _lastCameraFollowAt = now;
          _animateCameraTo(
            _cameraTargetForNavigation(vehiclePosition, task),
            zoom: _followZoomForTask(task),
          );
        }
      }
    });

    _maybeReroute(vehiclePosition, task);
  }

  Future<void> _handleArrival(MobileAssignedTask task) async {
    if (!mounted || _isHandlingArrival) {
      return;
    }

    final String arrivalKey = '${task.taskId}:${task.dispatchStatus}';
    if (_lastArrivalHandledKey == arrivalKey) {
      return;
    }

    _isHandlingArrival = true;

    try {
      if (_isPickupLeg(task)) {
        AppTabService.markPickupArrived(task.taskId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pickup reached. Redirecting to Task Detail.'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        MobileAssignedTask? latestTask;
        try {
          await MobileTaskService.refreshCurrentTask(forceRefresh: true);
          latestTask = MobileTaskService.currentTaskNotifier.value;
        } catch (_) {
          latestTask = MobileTaskService.currentTaskNotifier.value;
        }

        final MobileAssignedTask targetTask = latestTask ?? task;
        if (mounted) {
          AppTabService.selectTab(1);
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TaskDetailScreen(task: targetTask)),
          );
          _lastArrivalHandledKey = arrivalKey;
        }
        return;
      }

      if (task.dispatchStatus == 'in_transit') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Destination reached. Redirecting to unload confirmation.'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        MobileAssignedTask? latestTask;
        try {
          await MobileTaskService.refreshCurrentTask(forceRefresh: true);
          latestTask = MobileTaskService.currentTaskNotifier.value;
        } catch (_) {
          latestTask = MobileTaskService.currentTaskNotifier.value;
        }

        final MobileAssignedTask targetTask = latestTask ?? task;
        if (mounted) {
          AppTabService.selectTab(1);
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TaskDetailScreen(
                task: targetTask,
                autoPromptUnload: true,
              ),
            ),
          );
          _lastArrivalHandledKey = arrivalKey;
        }
      }
    } finally {
      _isHandlingArrival = false;
    }
  }

  void _maybeReroute(LatLng vehiclePosition, MobileAssignedTask task) {
    if (_routeCoordinates.length < 2) {
      return;
    }

    final LatLng nearestPoint =
        _findNearestRoutePoint(_routeCoordinates, vehiclePosition) ??
        _routeCoordinates.first;
    final double deviationMeters = _distanceMeters(
      vehiclePosition,
      nearestPoint,
    );
    if (deviationMeters <= _routeRerouteThresholdMeters) {
      return;
    }

    final DateTime now = DateTime.now();
    if (_lastRerouteAt != null &&
        now.difference(_lastRerouteAt!) < _routeRerouteCooldown) {
      return;
    }

    _lastRerouteAt = now;
    setState(() {
      _routeProgressStatus = 'Rerouting from live vehicle position';
    });
    _routeLoadToken += 1;
    _loadRouteForTask(task, vehiclePosition);
  }

  int _findNearestRouteIndex(List<LatLng> route, LatLng point) {
    if (route.isEmpty) {
      return -1;
    }

    int nearestIndex = 0;
    double nearestDistance = double.infinity;

    for (int index = 0; index < route.length; index += 1) {
      final double distance = _distanceMeters(route[index], point);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }

    return nearestIndex;
  }

  LatLng? _findNearestRoutePoint(List<LatLng> route, LatLng point) {
    final int index = _findNearestRouteIndex(route, point);
    if (index < 0) {
      return null;
    }
    return route[index];
  }

  double _distanceMeters(LatLng from, LatLng to) {
    const double earthRadius = 6371000;
    final double dLat = _degToRad(to.latitude - from.latitude);
    final double dLng = _degToRad(to.longitude - from.longitude);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(from.latitude)) *
            math.cos(_degToRad(to.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadius * (2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)));
  }

  double _degToRad(double value) => value * math.pi / 180;

  LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + ((b.latitude - a.latitude) * t),
      a.longitude + ((b.longitude - a.longitude) * t),
    );
  }

  double _lerpDouble(double a, double b, double t) => a + ((b - a) * t);

  double _bearingRadians(LatLng from, LatLng to) {
    final double lat1 = _degToRad(from.latitude);
    final double lat2 = _degToRad(to.latitude);
    final double dLng = _degToRad(to.longitude - from.longitude);
    final double y = math.sin(dLng) * math.cos(lat2);
    final double x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return math.atan2(y, x);
  }

  double _lerpAngle(double a, double b, double t) {
    final double diff = ((b - a + math.pi) % (2 * math.pi)) - math.pi;
    return a + diff * t;
  }

  String _conditionLabel(MobileAssignedTask task) {
    final String loadStatus = task.vehicleCurrentLoadStatus
        .trim()
        .toLowerCase();
    if (loadStatus.contains('loss')) {
      return 'Cargo Loss';
    }
    if (loadStatus.contains('overload')) {
      return 'Overload';
    }
    if (loadStatus.contains('above_reference')) {
      return 'Above Reference';
    }
    return 'Normal';
  }

  Color _conditionColor(MobileAssignedTask task) {
    final String label = _conditionLabel(task);
    switch (label) {
      case 'Cargo Loss':
        return const Color(0xFFEF4444);
      case 'Overload':
        return const Color(0xFFF59E0B);
      case 'Above Reference':
        return const Color(0xFF60A5FA);
      default:
        return const Color(0xFF4ADE80);
    }
  }

  Color _conditionBadgeBackgroundColor(MobileAssignedTask task) {
    return _conditionColor(task).withValues(alpha: 0.2);
  }

  Color _conditionBadgeBorderColor(MobileAssignedTask task) {
    return _conditionColor(task).withValues(alpha: 0.55);
  }

  String _tripLabel() {
    if (_task == null) {
      return 'No active task';
    }
    if (_task!.dispatchStatus == 'pending') {
      return 'Task ready';
    }
    if (_task!.dispatchStatus == 'active') {
      return 'Task active';
    }
    if (_task!.dispatchStatus == 'in_transit') {
      return 'In transit';
    }
    return 'Live tracking';
  }

  String _dispatchNavigationStatus(MobileAssignedTask task) {
    switch (task.dispatchStatus) {
      case 'pending':
        return 'Awaiting pickup';
      case 'active':
        return 'Loading in progress';
      case 'in_transit':
        return 'In transit';
      case 'completed':
        return 'Trip completed';
      case 'cancelled':
        return 'Task cancelled';
      default:
        return 'Task active';
    }
  }

  Color _dispatchStatusColor(MobileAssignedTask task) {
    switch (task.dispatchStatus) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'active':
        return const Color(0xFF22D3EE);
      case 'in_transit':
        return const Color(0xFF4ADE80);
      case 'completed':
        return const Color(0xFF60A5FA);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFA3A3A3);
    }
  }

  String _turnByTurnDetail(
    MobileAssignedTask task,
    TaskInstructionStepData? step,
  ) {
    if (step != null && step.detail.trim().isNotEmpty) {
      return step.detail;
    }

    switch (task.dispatchStatus) {
      case 'pending':
        return 'Proceed to the pickup point to begin the trip.';
      case 'active':
        return 'Reach the pickup point, then record initial cargo weight.';
      case 'in_transit':
        if (_routeProgressStatus == 'On planned route' ||
            _routeProgressStatus == 'Waiting for route updates') {
          return 'Continue safely to the destination.';
        }
        return _routeProgressStatus;
      case 'completed':
        return 'Delivery has been completed successfully.';
      case 'cancelled':
        return 'This task was cancelled by dispatch.';
      default:
        return 'Follow dispatch guidance.';
    }
  }

  String _weightLabel(MobileAssignedTask task) {
    final double? weightKg = task.liveCurrentWeightKg;
    if (weightKg == null) {
      return '-- kg';
    }
    return '${weightKg.toStringAsFixed(0)} kg';
  }

  String _referenceWeightLabel(MobileAssignedTask task) {
    final double? referenceKg = task.initialReferenceWeightKg;
    if (referenceKg == null) {
      return '-- kg';
    }
    return '${referenceKg.toStringAsFixed(0)} kg';
  }

  void _recenterToVehicle(MobileAssignedTask task) {
    setState(() {
      _isAutoFollow = true;
    });

    _animateCameraTo(
      _cameraTargetForNavigation(
        _vehiclePosition ?? _resolveVehiclePosition(task),
        task,
      ),
      zoom: _followZoomForTask(task),
    );
  }

  TaskInstructionStepData? _activeTaskInstruction(MobileAssignedTask task) {
    if (task.detailedInstructions.isEmpty) {
      return null;
    }

    if (_vehiclePosition == null || _routeCoordinates.length < 2) {
      return task.detailedInstructions.first;
    }

    final int nearestIndex = _findNearestRouteIndex(
      _routeCoordinates,
      _vehiclePosition!,
    );
    if (nearestIndex < 0 || _routeCoordinates.length <= 1) {
      return task.detailedInstructions.first;
    }

    final double progress = (nearestIndex / (_routeCoordinates.length - 1))
        .clamp(0, 1);
    final int stepIndex = ((task.detailedInstructions.length - 1) * progress)
        .round()
        .clamp(0, task.detailedInstructions.length - 1);
    return task.detailedInstructions[stepIndex];
  }

  int _activeLiveTurnStepIndex() {
    if (_liveTurnSteps.isEmpty) {
      return -1;
    }

    if (_vehiclePosition == null || _routeCoordinates.isEmpty) {
      return 0;
    }

    final int nearestIndex = _findNearestRouteIndex(
      _routeCoordinates,
      _vehiclePosition!,
    );
    if (nearestIndex < 0) {
      return 0;
    }

    for (int i = 0; i < _liveTurnSteps.length; i += 1) {
      if (_liveTurnSteps[i].routeIndex >= nearestIndex) {
        return i;
      }
    }

    return _liveTurnSteps.length - 1;
  }

  _RouteTurnStep? _activeLiveTurnStep() {
    final int activeIndex = _activeLiveTurnStepIndex();
    if (activeIndex < 0 || activeIndex >= _liveTurnSteps.length) {
      return null;
    }
    return _liveTurnSteps[activeIndex];
  }

  String _formatTurnDistance(double distanceMeters) {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  String _liveTurnTitle(_RouteTurnStep step) {
    if (step.instruction == 'arrive at destination') {
      return 'Arrive at destination';
    }
    return 'In ${_formatTurnDistance(step.distanceMeters)}, ${step.instruction}';
  }

  String _liveTurnDetail(_RouteTurnStep step) {
    if (step.roadName.isNotEmpty) {
      return 'onto ${step.roadName}';
    }
    return 'Follow this maneuver';
  }

  IconData _maneuverIcon(_RouteTurnStep step) {
    if (step.maneuverType == 'arrive') {
      return Icons.flag_circle_rounded;
    }
    if (step.maneuverType == 'roundabout' || step.maneuverType == 'rotary') {
      return Icons.roundabout_right_rounded;
    }

    switch (step.maneuverModifier) {
      case 'left':
        return Icons.turn_left_rounded;
      case 'right':
        return Icons.turn_right_rounded;
      case 'slight left':
        return Icons.turn_slight_left_rounded;
      case 'slight right':
        return Icons.turn_slight_right_rounded;
      case 'sharp left':
        return Icons.turn_sharp_left_rounded;
      case 'sharp right':
        return Icons.turn_sharp_right_rounded;
      case 'uturn':
        return Icons.u_turn_left_rounded;
      case 'straight':
        return Icons.straight_rounded;
      default:
        return step.maneuverType == 'depart'
            ? Icons.navigation_outlined
            : Icons.navigation_rounded;
    }
  }

  Color _maneuverColor(_RouteTurnStep step) {
    if (step.maneuverType == 'arrive') {
      return const Color(0xFF4ADE80);
    }
    if (step.maneuverType == 'roundabout' || step.maneuverType == 'rotary') {
      return const Color(0xFF22D3EE);
    }

    switch (step.maneuverModifier) {
      case 'sharp left':
      case 'sharp right':
      case 'uturn':
        return const Color(0xFFF59E0B);
      case 'slight left':
      case 'slight right':
        return const Color(0xFF60A5FA);
      case 'left':
      case 'right':
      case 'straight':
        return const Color(0xFF22D3EE);
      default:
        return const Color(0xFF67E8F9);
    }
  }

  Widget _buildTopTurnByTurnCard(MobileAssignedTask task) {
    final _RouteTurnStep? liveTurn = _activeLiveTurnStep();
    final TaskInstructionStepData? fallbackStep = _activeTaskInstruction(task);
    final String dispatchStatus = _dispatchNavigationStatus(task);
    final Color dispatchStatusColor = _dispatchStatusColor(task);
    final String vehicleConditionLabel = _conditionLabel(task);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2B22).withValues(alpha: 0.96),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        border: Border.all(color: Colors.white12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatusBadge(
                icon: Icons.assignment_turned_in_rounded,
                label: 'Task: $dispatchStatus',
                textColor: dispatchStatusColor,
                backgroundColor: dispatchStatusColor.withValues(alpha: 0.2),
                borderColor: dispatchStatusColor.withValues(alpha: 0.55),
              ),
              _StatusBadge(
                icon: Icons.local_shipping_rounded,
                label: 'Vehicle: $vehicleConditionLabel',
                textColor: _conditionColor(task),
                backgroundColor: _conditionBadgeBackgroundColor(task),
                borderColor: _conditionBadgeBorderColor(task),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color:
                      (liveTurn != null
                              ? _maneuverColor(liveTurn)
                              : const Color(0xFF22D3EE))
                          .withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: liveTurn != null
                      ? Icon(
                          _maneuverIcon(liveTurn),
                          color: _maneuverColor(liveTurn),
                          size: 18,
                        )
                      : Text(
                          '${fallbackStep?.step ?? 1}',
                          style: const TextStyle(
                            color: Color(0xFF67E8F9),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Turn-by-turn Navigation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      liveTurn != null
                          ? _liveTurnTitle(liveTurn)
                          : (fallbackStep?.title ?? dispatchStatus),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      liveTurn != null
                          ? _liveTurnDetail(liveTurn)
                          : _turnByTurnDetail(task, fallbackStep),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11.2,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Recenter map',
                    onPressed: () => _recenterToVehicle(task),
                    icon: const Icon(
                      Icons.my_location_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      minimumSize: const Size(30, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.all(5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  IconButton(
                    tooltip: 'Close turn-by-turn',
                    onPressed: () {
                      setState(() {
                        _showTopTurnByTurn = false;
                      });
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(30, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.all(5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _TopMetricChip(
                  icon: Icons.speed_rounded,
                  label: 'Speed',
                  value: '${task.liveSpeedKmh.toStringAsFixed(0)} km/h',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TopMetricChip(
                  icon: Icons.scale_rounded,
                  label: 'Weight',
                  value: _weightLabel(task),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TopMetricChip(
                  icon: Icons.balance_rounded,
                  label: 'Reference',
                  value: _referenceWeightLabel(task),
                ),
              ),
            ],
          ),
          if (!_isAutoFollow) ...<Widget>[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _recenterToVehicle(task),
              icon: const Icon(Icons.center_focus_strong_rounded, size: 16),
              label: const Text('Recenter and follow'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A7B51),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleMarker(MobileAssignedTask task) {
    final Color accent = _conditionColor(task);
    final String state = task.vehicleCurrentLoadStatus.trim().toLowerCase();
    final bool shouldPulse = state != 'normal';

    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (shouldPulse)
            ScaleTransition(
              scale: Tween<double>(begin: 1, end: 1.8).animate(
                CurvedAnimation(
                  parent: _pulseController,
                  curve: Curves.easeOut,
                ),
              ),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.6, end: 0).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeOut,
                  ),
                ),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                ),
              ),
            ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              border: Border.all(color: const Color(0xFF0F172A), width: 3),
              boxShadow: <BoxShadow>[
                BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMarker({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.8)),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          Positioned(
            bottom: 1,
            left: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF071E18).withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white12),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard(MobileAssignedTask task) {
    final List<TaskInstructionStepData> steps = task.detailedInstructions;
    final String dispatchStatus = _dispatchNavigationStatus(task);
    final Color dispatchStatusColor = _dispatchStatusColor(task);
    final String vehicleConditionLabel = _conditionLabel(task);
    final int activeLiveIndex = _activeLiveTurnStepIndex();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2B22).withValues(alpha: 0.96),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Navigation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close navigation',
                onPressed: () {
                  setState(() {
                    _showBottomNavigation = false;
                  });
                  _publishMainBottomNavVisibility();
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                style: IconButton.styleFrom(
                  minimumSize: const Size(28, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.all(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Current leg: ${_isPickupLeg(task) ? task.pickupName : task.destinationName}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _StatusBadge(
                icon: Icons.assignment_turned_in_rounded,
                label: 'Task: $dispatchStatus',
                textColor: dispatchStatusColor,
                backgroundColor: dispatchStatusColor.withValues(alpha: 0.2),
                borderColor: dispatchStatusColor.withValues(alpha: 0.55),
              ),
              _StatusBadge(
                icon: Icons.local_shipping_rounded,
                label: 'Vehicle: $vehicleConditionLabel',
                textColor: _conditionColor(task),
                backgroundColor: _conditionBadgeBackgroundColor(task),
                borderColor: _conditionBadgeBorderColor(task),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Detailed route guidance',
            style: TextStyle(color: Colors.white54, fontSize: 11.2),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: _TopMetricChip(
                  icon: Icons.speed_rounded,
                  label: 'Speed',
                  value: '${task.liveSpeedKmh.toStringAsFixed(0)} km/h',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TopMetricChip(
                  icon: Icons.scale_rounded,
                  label: 'Weight',
                  value: _weightLabel(task),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TopMetricChip(
                  icon: Icons.balance_rounded,
                  label: 'Reference',
                  value: _referenceWeightLabel(task),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 190),
            child: SingleChildScrollView(
              child: _liveTurnSteps.isNotEmpty
                  ? Column(
                      children: _liveTurnSteps
                          .asMap()
                          .entries
                          .map((entry) {
                            final int index = entry.key;
                            final _RouteTurnStep step = entry.value;
                            final bool isActive = index == activeLiveIndex;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _StepRow(
                                index: index + 1,
                                title: _liveTurnTitle(step),
                                subtitle: _liveTurnDetail(step),
                                icon: _maneuverIcon(step),
                                accent: isActive
                                    ? _maneuverColor(step)
                                    : _maneuverColor(
                                        step,
                                      ).withValues(alpha: 0.72),
                              ),
                            );
                          })
                          .toList(growable: false),
                    )
                  : steps.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Text(
                        'Turn guidance is preparing. Keep following the highlighted route.',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    )
                  : Column(
                      children: steps
                          .map(
                            (TaskInstructionStepData step) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _StepRow(
                                index: step.step,
                                title: step.title,
                                subtitle: step.detail,
                                accent: _conditionColor(task),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  double _bottomOverlayClearance(
    double bottomInset, {
    required bool isPanelOpen,
  }) {
    if (isPanelOpen) {
      return 0;
    }

    const double base = _floatingBottomNavChipClearance;
    // Add extra lift on devices with larger gesture insets so panel content does not get clipped.
    final double insetBoost = bottomInset > 20 ? 14 : 6;
    return base + insetBoost;
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;
    final double navClearance = _bottomOverlayClearance(
      bottomInset,
      isPanelOpen: _showBottomNavigation,
    );
    final double bottomDockPadding = _showBottomNavigation
        ? bottomInset
        : (bottomInset > 8 ? bottomInset : 8) + navClearance;

    final MobileAssignedTask? task = _task;
    final bool showNavigationMap =
      task != null && _canShowNavigationForTask(task);
    final bool pickupArrivedStage =
      task != null &&
      task.dispatchStatus == 'active' &&
      AppTabService.isPickupArrived(task.taskId);
    final LatLng fallbackVehiclePosition = task == null
        ? _defaultCenter
        : _resolveVehiclePosition(task);

    return Scaffold(
      backgroundColor: const Color(0xFF051E16),
      body: Stack(
        children: <Widget>[
          if (showNavigationMap)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _defaultCenter,
                initialZoom: 13.8,
                onPositionChanged: (dynamic position, bool hasGesture) {
                  final LatLng? center = position.center;
                  final double? zoom = position.zoom;
                  final double? rotation = position.rotation;

                  if (center != null) {
                    _mapCenter = center;
                  }
                  if (zoom != null) {
                    _mapZoom = zoom;
                  }
                  if (rotation != null) {
                    _mapRotationDeg = rotation;
                  }

                  if (hasGesture) {
                    setState(() {
                      _isAutoFollow = false;
                    });
                  }
                },
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const <String>['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.mobile',
                ),
                if (_routeCoordinates.length >= 2)
                  PolylineLayer(
                    polylines: <Polyline>[
                      if (_routeCoordinates.length >= 2)
                        Polyline(
                          points: _routeCoordinates,
                          strokeWidth: 6,
                          color: Colors.white24,
                        ),
                      if (_completedPath.length >= 2)
                        Polyline(
                          points: _completedPath,
                          strokeWidth: 6,
                          color: const Color(0xFF4ADE80),
                        ),
                      if (_remainingPath.length >= 2)
                        Polyline(
                          points: _remainingPath,
                          strokeWidth: 6,
                          color: const Color(0xFF22D3EE),
                        ),
                    ],
                  ),
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      point: LatLng(task.pickupLat, task.pickupLng),
                      width: 54,
                      height: 54,
                      child: _buildRouteMarker(
                        icon: Icons.warehouse_rounded,
                        color: const Color(0xFF4ADE80),
                        label: 'Pickup',
                      ),
                    ),
                    Marker(
                      point: LatLng(task.destinationLat, task.destinationLng),
                      width: 54,
                      height: 54,
                      child: _buildRouteMarker(
                        icon: Icons.flag_circle_rounded,
                        color: const Color(0xFF22D3EE),
                        label: 'Destination',
                      ),
                    ),
                    Marker(
                      point: _vehiclePosition ?? fallbackVehiclePosition,
                      width: 20,
                      height: 20,
                      child: _buildVehicleMarker(task),
                    ),
                  ],
                ),
              ],
            )
          else
            Container(color: const Color(0xFF051E16)),
          IgnorePointer(
            ignoring: true,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    const Color(0xFF051E16).withValues(alpha: 0.48),
                    Colors.transparent,
                    const Color(0xFF051E16).withValues(alpha: 0.72),
                  ],
                  stops: const <double>[0.0, 0.35, 1.0],
                ),
              ),
            ),
          ),
          if (task == null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: AppNavbar(title: 'Trips', subtitle: _tripLabel()),
              ),
            ),
          if (task == null)
            Positioned(
              left: 16,
              right: 16,
              top: 104,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2B22).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Waiting for assigned vehicle',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLoadingRoute
                          ? 'Loading route...'
                          : 'Start a task to see the live vehicle and navigation route here.',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                      ),
                    ),
                    if (_routeError != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        _routeError!,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (task != null && !showNavigationMap)
            Positioned(
              left: 16,
              right: 16,
              top: 104,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C2B22).withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      pickupArrivedStage
                          ? 'You have already arrived at the pickup point'
                          : 'Navigation map is hidden',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      task.dispatchStatus == 'pending'
                          ? 'Begin the task from Task Detail to open live navigation.'
                          : pickupArrivedStage
                          ? 'Open Task Detail to follow the loading instructions and confirm the cargo weight.'
                          : 'Complete pickup loading from Task Detail to continue navigation.',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                      ),
                    ),
                    if (pickupArrivedStage) ...<Widget>[
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () async {
                          final NavigatorState navigator = Navigator.of(context);
                          await MobileTaskService.refreshCurrentTask(
                            forceRefresh: true,
                          );
                          final MobileAssignedTask? latestTask =
                              MobileTaskService.currentTaskNotifier.value;
                          if (!mounted || latestTask == null) {
                            return;
                          }
                          AppTabService.selectTab(1);
                          await navigator.push(
                            MaterialPageRoute(
                              builder: (_) => TaskDetailScreen(
                                task: latestTask,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.assignment_turned_in_rounded),
                        label: const Text('Go to Task Detail'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1A7B51),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          if (task != null && showNavigationMap)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: Column(
                    children: <Widget>[
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
                              final Animation<Offset> slide = Tween<Offset>(
                                begin: const Offset(0, -0.06),
                                end: Offset.zero,
                              ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: slide,
                                  child: child,
                                ),
                              );
                            },
                        child: _showTopTurnByTurn
                            ? KeyedSubtree(
                                key: const ValueKey<String>('top-turn-card'),
                                child: _buildTopTurnByTurnCard(task),
                              )
                            : Align(
                                key: const ValueKey<String>('top-turn-chip'),
                                alignment: Alignment.center,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    0,
                                  ),
                                  child: FilledButton.tonalIcon(
                                    onPressed: () {
                                      setState(() {
                                        _showTopTurnByTurn = true;
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.turn_right_rounded,
                                      size: 16,
                                    ),
                                    label: const Text('Show Turn-by-turn'),
                                    style: FilledButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: const Color(
                                        0xFF0C2B22,
                                      ).withValues(alpha: 0.96),
                                      side: const BorderSide(
                                        color: Colors.white12,
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        42,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                      if (_routeError != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            _routeError!,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (task != null && showNavigationMap)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomDockPadding),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        final Animation<Offset> slide = Tween<Offset>(
                          begin: const Offset(0, 0.08),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: slide, child: child),
                        );
                      },
                  child: _showBottomNavigation
                      ? KeyedSubtree(
                          key: const ValueKey<String>('bottom-navigation-card'),
                          child: _buildInstructionCard(task),
                        )
                      : Align(
                          key: const ValueKey<String>('bottom-navigation-chip'),
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: FilledButton.tonalIcon(
                                onPressed: () {
                                  setState(() {
                                    _showBottomNavigation = true;
                                  });
                                  _publishMainBottomNavVisibility();
                                },
                                icon: const Icon(
                                  Icons.navigation_rounded,
                                  size: 18,
                                ),
                                label: const Text('Show Navigation'),
                                style: FilledButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: const Color(
                                    0xFF0C2B22,
                                  ).withValues(alpha: 0.98),
                                  side: const BorderSide(color: Colors.white12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopMetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TopMetricChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color borderColor;

  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteData {
  final List<LatLng> coordinates;
  final List<_RouteTurnStep> steps;

  const _RouteData({required this.coordinates, required this.steps});
}

class _RouteTurnStep {
  final int routeIndex;
  final double distanceMeters;
  final String maneuverType;
  final String maneuverModifier;
  final String instruction;
  final String roadName;

  const _RouteTurnStep({
    required this.routeIndex,
    required this.distanceMeters,
    required this.maneuverType,
    required this.maneuverModifier,
    required this.instruction,
    required this.roadName,
  });
}

class _StepRow extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final IconData? icon;
  final Color accent;

  const _StepRow({
    required this.index,
    required this.title,
    required this.subtitle,
    this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 16, color: accent)
                  : Text(
                      '$index',
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11.8,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
