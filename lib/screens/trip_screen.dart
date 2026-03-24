import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/widget/navbar.dart';

enum TripPhase { before, during, after }

enum IncidentType { cargoLoss, overload }

class TelemetrySample {
  final LatLng position;
  final double weightKg;
  final int routeIndex;
  final DateTime timestamp;
  final bool reachedDestination;

  const TelemetrySample({
    required this.position,
    required this.weightKg,
    required this.routeIndex,
    required this.timestamp,
    required this.reachedDestination,
  });
}

class TripIncident {
  final int id;
  final IncidentType type;
  final LatLng location;
  final DateTime time;
  final double beforeKg;
  final double afterKg;

  const TripIncident({
    required this.id,
    required this.type,
    required this.location,
    required this.time,
    required this.beforeKg,
    required this.afterKg,
  });
}

class TimelineEntry {
  final DateTime time;
  final LatLng location;
  final double beforeKg;
  final double afterKg;
  final int? incidentId;

  const TimelineEntry({
    required this.time,
    required this.location,
    required this.beforeKg,
    required this.afterKg,
    this.incidentId,
  });
}

class TripScreen extends StatefulWidget {
  const TripScreen({super.key});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  static const LatLng _warehouse = LatLng(10.3090, 123.8930);
  static const LatLng _checkpoint1 = LatLng(10.3148, 123.9032);
  static const LatLng _checkpoint2 = LatLng(10.3237, 123.9209);
  static const LatLng _destination = LatLng(10.3342, 123.9411);

  static const List<String> _routeDirections = <String>[
    'Start at warehouse pickup zone.',
    'Proceed via M.C. Briones Road.',
    'Pass A.S. Fortuna checkpoint corridor.',
    'Approach destination unloading gate.',
  ];

  late final List<LatLng> _plannedRoute;
  late final List<LatLng> _denseRoute;

  final List<LatLng> _trackedPath = <LatLng>[];
  final List<TripIncident> _incidents = <TripIncident>[];
  final List<TimelineEntry> _timeline = <TimelineEntry>[];

  TripPhase _tripPhase = TripPhase.before;

  late LatLng _vehiclePosition;
  double _vehicleHeadingRad = 0;
  double _mapZoom = 13.8;
  LatLng _mapCenter = _warehouse;

  double _currentWeightKg = 4300;
  double _lastWeightKg = 4300;

  bool _isAutoFollow = true;
  bool _showLayoverInfo = true;

  int _routeInstructionIndex = 0;
  int _telemetryCursor = 0;
  int _incidentSeed = 1;
  int? _highlightIncidentId;

  StreamSubscription<TelemetrySample>? _telemetrySubscription;
  AnimationController? _vehicleMoveController;
  AnimationController? _cameraMoveController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _plannedRoute = <LatLng>[
      _warehouse,
      _checkpoint1,
      _checkpoint2,
      _destination,
    ];

    _denseRoute = _densifyRoute(_plannedRoute, pointsPerSegment: 16);
    _vehiclePosition = _plannedRoute.first;
    _trackedPath.add(_vehiclePosition);

    _timeline.add(
      TimelineEntry(
        time: DateTime.now(),
        location: _vehiclePosition,
        beforeKg: _currentWeightKg,
        afterKg: _currentWeightKg,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )
      ..addListener(() {
        if (_highlightIncidentId != null && mounted) {
          setState(() {});
        }
      })
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _telemetrySubscription?.cancel();
    _vehicleMoveController?.dispose();
    _cameraMoveController?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  List<LatLng> _densifyRoute(List<LatLng> route, {int pointsPerSegment = 14}) {
    if (route.length < 2) {
      return route;
    }

    final List<LatLng> dense = <LatLng>[];
    for (int i = 0; i < route.length - 1; i++) {
      final LatLng a = route[i];
      final LatLng b = route[i + 1];
      for (int j = 0; j < pointsPerSegment; j++) {
        final double t = j / pointsPerSegment;
        dense.add(_lerpLatLng(a, b, t));
      }
    }
    dense.add(route.last);
    return dense;
  }

  void _startTripMonitoring() {
    if (_tripPhase == TripPhase.during) {
      return;
    }

    setState(() {
      _tripPhase = TripPhase.during;
      _isAutoFollow = true;
      _routeInstructionIndex = 0;
      _telemetryCursor = 0;
      _incidents.clear();
      _timeline.clear();
      _trackedPath
        ..clear()
        ..add(_plannedRoute.first);
      _vehiclePosition = _plannedRoute.first;
      _currentWeightKg = 4300;
      _lastWeightKg = 4300;
      _highlightIncidentId = null;
    });

    _timeline.add(
      TimelineEntry(
        time: DateTime.now(),
        location: _vehiclePosition,
        beforeKg: _currentWeightKg,
        afterKg: _currentWeightKg,
      ),
    );

    _animateCameraTo(_vehiclePosition, zoom: 16.1, duration: const Duration(milliseconds: 550));

    _telemetrySubscription?.cancel();
    _telemetrySubscription = Stream<TelemetrySample>.periodic(
      const Duration(seconds: 2),
      (_) => _nextTelemetrySample(),
    ).listen(_onTelemetryReceived);
  }

  void _endTripMonitoring() {
    _telemetrySubscription?.cancel();

    setState(() {
      _tripPhase = TripPhase.after;
      _isAutoFollow = false;
      _highlightIncidentId = null;
    });

    _animateCameraTo(_routeCenter, zoom: 12.9, duration: const Duration(milliseconds: 700));
  }

  TelemetrySample _nextTelemetrySample() {
    final int nextIndex = (_telemetryCursor + 3).clamp(0, _denseRoute.length - 1);
    _telemetryCursor = nextIndex;

    final double progress = _denseRoute.length <= 1 ? 1 : nextIndex / (_denseRoute.length - 1);

    double weight = 4280 + (math.sin(progress * 8) * 35);

    // Deterministic anomaly windows to simulate IoT incident events.
    if (progress > 0.23 && progress < 0.29) {
      weight += 300;
    }
    if (progress > 0.58 && progress < 0.64) {
      weight -= 210;
    }

    final bool reachedDestination = nextIndex >= _denseRoute.length - 1;

    return TelemetrySample(
      position: _denseRoute[nextIndex],
      weightKg: weight,
      routeIndex: nextIndex,
      timestamp: DateTime.now(),
      reachedDestination: reachedDestination,
    );
  }

  void _onTelemetryReceived(TelemetrySample sample) {
    if (!mounted || _tripPhase != TripPhase.during) {
      return;
    }

    _animateVehicleTo(sample.position);

    final double before = _currentWeightKg;
    final double after = sample.weightKg;
    _lastWeightKg = before;
    _currentWeightKg = after;

    _routeInstructionIndex = _directionIndexForProgress(sample.routeIndex);

    int? incidentId;

    final bool overloadDetected = after > 4500 && before <= 4500;
    final bool cargoLossDetected = (before - after) >= 120;

    if (overloadDetected) {
      incidentId = _createIncident(
        type: IncidentType.overload,
        location: sample.position,
        time: sample.timestamp,
        beforeKg: before,
        afterKg: after,
      );
    } else if (cargoLossDetected) {
      incidentId = _createIncident(
        type: IncidentType.cargoLoss,
        location: sample.position,
        time: sample.timestamp,
        beforeKg: before,
        afterKg: after,
      );
    }

    _timeline.add(
      TimelineEntry(
        time: sample.timestamp,
        location: sample.position,
        beforeKg: before,
        afterKg: after,
        incidentId: incidentId,
      ),
    );

    if (_timeline.length > 18) {
      _timeline.removeAt(0);
    }

    if (_isAutoFollow) {
      _animateCameraTo(sample.position, zoom: 16.1);
    }

    if (sample.reachedDestination) {
      _endTripMonitoring();
    }

    setState(() {});
  }

  int _createIncident({
    required IncidentType type,
    required LatLng location,
    required DateTime time,
    required double beforeKg,
    required double afterKg,
  }) {
    final int newId = _incidentSeed++;
    final TripIncident incident = TripIncident(
      id: newId,
      type: type,
      location: location,
      time: time,
      beforeKg: beforeKg,
      afterKg: afterKg,
    );

    _incidents.add(incident);
    _highlightIncidentId = newId;

    if (_incidents.length > 30) {
      _incidents.removeAt(0);
    }

    final String eventLabel = type == IncidentType.cargoLoss ? 'Cargo Loss' : 'Overload';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$eventLabel detected at ${_formatTime(time)}'),
        duration: const Duration(seconds: 2),
      ),
    );

    Future<void>.delayed(const Duration(seconds: 4), () {
      if (!mounted) {
        return;
      }
      if (_highlightIncidentId == newId) {
        setState(() {
          _highlightIncidentId = null;
        });
      }
    });

    return newId;
  }

  void _animateVehicleTo(LatLng target) {
    _vehicleMoveController?.dispose();

    final LatLng start = _vehiclePosition;
    final double startHeading = _vehicleHeadingRad;
    final double endHeading = _bearingRadians(start, target);

    final AnimationController controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _vehicleMoveController = controller;

    controller.addListener(() {
      final double t = Curves.easeInOutCubic.transform(controller.value);
      final LatLng nextPosition = _lerpLatLng(start, target, t);

      setState(() {
        _vehiclePosition = nextPosition;
        _vehicleHeadingRad = _lerpAngle(startHeading, endHeading, t);
      });
    });

    controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        if (_trackedPath.isEmpty || _trackedPath.last != target) {
          _trackedPath.add(target);
          if (_trackedPath.length > 400) {
            _trackedPath.removeAt(0);
          }
        }
      }
    });

    controller.forward();
  }

  void _animateCameraTo(
    LatLng target, {
    double? zoom,
    Duration duration = const Duration(milliseconds: 420),
  }) {
    _cameraMoveController?.dispose();

    final LatLng from = _mapCenter;
    final double fromZoom = _mapZoom;
    final double toZoom = zoom ?? _mapZoom;

    final AnimationController controller = AnimationController(
      vsync: this,
      duration: duration,
    );
    _cameraMoveController = controller;

    controller.addListener(() {
      final double t = Curves.easeInOut.transform(controller.value);
      final LatLng nextCenter = _lerpLatLng(from, target, t);
      final double nextZoom = _lerpDouble(fromZoom, toZoom, t);
      _mapController.move(nextCenter, nextZoom);
    });

    controller.forward();
  }

  void _recenterAndResumeFollow() {
    setState(() {
      _isAutoFollow = true;
    });
    _animateCameraTo(_vehiclePosition, zoom: 16.1, duration: const Duration(milliseconds: 500));
  }

  void _showIncidentSheet(TripIncident incident) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0C2B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        final Color accent = incident.type == IncidentType.cargoLoss ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
        final String title = incident.type == IncidentType.cargoLoss ? 'Cargo Loss Event' : 'Overload Event';

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text('Time: ${_formatTime(incident.time)}', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text(
                'Weight: ${incident.beforeKg.toStringAsFixed(0)} kg -> ${incident.afterKg.toStringAsFixed(0)} kg',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                'Coordinates: ${incident.location.latitude.toStringAsFixed(5)}, ${incident.location.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        );
      },
    );
  }

  void _focusTimelineEntry(TimelineEntry entry) {
    _animateCameraTo(entry.location, zoom: 16.6, duration: const Duration(milliseconds: 520));

    setState(() {
      _highlightIncidentId = entry.incidentId;
      _isAutoFollow = false;
    });

    if (entry.incidentId != null) {
      final int index = _incidents.indexWhere((TripIncident i) => i.id == entry.incidentId);
      final TripIncident? incident = index >= 0 ? _incidents[index] : null;
      if (incident != null) {
        _showIncidentSheet(incident);
      }
    }
  }

  int _directionIndexForProgress(int routeIndex) {
    if (_denseRoute.length <= 1) {
      return 0;
    }
    final double progress = routeIndex / (_denseRoute.length - 1);
    if (progress < 0.25) {
      return 0;
    }
    if (progress < 0.5) {
      return 1;
    }
    if (progress < 0.75) {
      return 2;
    }
    return 3;
  }

  String get _tripStateLabel {
    switch (_tripPhase) {
      case TripPhase.before:
        return 'Trip Ready';
      case TripPhase.during:
        return 'Trip Active - Monitoring';
      case TripPhase.after:
        return 'Trip Completed';
    }
  }

  String get _cargoStatus {
    if (_currentWeightKg > 4500) {
      return 'Overload';
    }
    if ((_lastWeightKg - _currentWeightKg) >= 120) {
      return 'Cargo Loss';
    }
    return 'Normal';
  }

  Color get _cargoStatusColor {
    switch (_cargoStatus) {
      case 'Overload':
        return const Color(0xFFF59E0B);
      case 'Cargo Loss':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF4ADE80);
    }
  }

  LatLng get _routeCenter {
    double minLat = _plannedRoute.first.latitude;
    double maxLat = _plannedRoute.first.latitude;
    double minLng = _plannedRoute.first.longitude;
    double maxLng = _plannedRoute.first.longitude;

    for (final LatLng p in _plannedRoute) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF051E16),
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _warehouse,
              initialZoom: 13.8,
              onPositionChanged: (dynamic position, bool hasGesture) {
                final LatLng? center = position.center as LatLng?;
                final double? zoom = position.zoom as double?;

                if (center != null) {
                  _mapCenter = center;
                }
                if (zoom != null) {
                  _mapZoom = zoom;
                }

                if (hasGesture && _tripPhase == TripPhase.during && _isAutoFollow) {
                  setState(() {
                    _isAutoFollow = false;
                  });
                }
              },
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mobile',
              ),
              PolylineLayer(
                polylines: <Polyline>[
                  Polyline(
                    points: _plannedRoute,
                    strokeWidth: 5,
                    color: Colors.white24,
                  ),
                  if (_trackedPath.length >= 2)
                    Polyline(
                      points: _trackedPath,
                      strokeWidth: 6,
                      color: const Color(0xFF4ADE80),
                    ),
                ],
              ),
              MarkerLayer(
                markers: <Marker>[
                  Marker(
                    point: _warehouse,
                    width: 40,
                    height: 40,
                    child: const _MapPin(
                      icon: Icons.warehouse_rounded,
                      color: Color(0xFF60A5FA),
                    ),
                  ),
                  Marker(
                    point: _destination,
                    width: 40,
                    height: 40,
                    child: const _MapPin(
                      icon: Icons.flag_circle_rounded,
                      color: Color(0xFF22D3EE),
                    ),
                  ),
                  Marker(
                    point: _vehiclePosition,
                    width: 52,
                    height: 52,
                    child: Transform.rotate(
                      angle: _vehicleHeadingRad,
                      child: const _MapPin(
                        icon: Icons.local_shipping_rounded,
                        color: Color(0xFF4ADE80),
                        highlighted: true,
                      ),
                    ),
                  ),
                  ..._incidents.map(
                    (TripIncident incident) {
                      final bool isLoss = incident.type == IncidentType.cargoLoss;
                      final Color incidentColor = isLoss ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
                      final bool highlighted = _highlightIncidentId == incident.id;
                      final double pulse = 1 + (_pulseController.value * 0.18);

                      return Marker(
                        point: incident.location,
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () {
                            _animateCameraTo(incident.location, zoom: 16.6, duration: const Duration(milliseconds: 500));
                            setState(() {
                              _highlightIncidentId = incident.id;
                              _isAutoFollow = false;
                            });
                            _showIncidentSheet(incident);
                          },
                          child: Transform.scale(
                            scale: highlighted ? pulse : 1,
                            child: _MapPin(
                              icon: Icons.warning_amber_rounded,
                              color: incidentColor,
                              highlighted: highlighted,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AppNavbar(
                title: 'Trips',
                subtitle: _tripStateLabel,
                notificationCount: _incidents.length,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 104,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: !_showLayoverInfo
                  ? const SizedBox.shrink()
                  : Container(
                      key: const ValueKey<String>('route_overlay'),
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C2B22).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Route By Route',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _routeDirections[_routeInstructionIndex],
                            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          if (_tripPhase == TripPhase.during && !_isAutoFollow)
            Positioned(
              right: 16,
              bottom: _showLayoverInfo ? 352 + bottomInset : 126 + bottomInset,
              child: FloatingActionButton.small(
                onPressed: _recenterAndResumeFollow,
                backgroundColor: const Color(0xFF0C2B22),
                foregroundColor: const Color(0xFF4ADE80),
                child: const Icon(Icons.my_location_rounded),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 90 + bottomInset,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: !_showLayoverInfo
                  ? const SizedBox.shrink()
                  : Container(
                      key: const ValueKey<String>('active_trip_overlay'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C2B22).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white12),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              const Text(
                                'Active Trip',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: (_tripPhase == TripPhase.during ? const Color(0xFF1A7B51) : Colors.white)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _tripStateLabel,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Pickup: ${_warehouse.latitude.toStringAsFixed(4)}, ${_warehouse.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12.4),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Destination: ${_destination.latitude.toStringAsFixed(4)}, ${_destination.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12.4),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Vehicle: ${_vehiclePosition.latitude.toStringAsFixed(5)}, ${_vehiclePosition.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(color: Colors.white60, fontSize: 11.8),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF08241B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    '${_currentWeightKg.toStringAsFixed(0)} kg',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _cargoStatusColor.withValues(alpha: 0.17),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _cargoStatus,
                                    style: TextStyle(
                                      color: _cargoStatusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: _TimelineCard(
                                  title: 'Weight Timeline',
                                  rows: _timeline
                                      .reversed
                                      .take(4)
                                      .map(
                                        (TimelineEntry entry) =>
                                            '${_formatTime(entry.time)}  ${entry.beforeKg.toStringAsFixed(0)} -> ${entry.afterKg.toStringAsFixed(0)} kg',
                                      )
                                      .toList(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _TimelineCard(
                                  title: 'Pick / Drop Timeline',
                                  rows: <String>[
                                    'Pickup ${_formatTime(_timeline.first.time)}',
                                    'Checkpoint ${_formatTime(DateTime.now())}',
                                    _tripPhase == TripPhase.after ? 'Dropoff Completed' : 'Dropoff Pending',
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Trip Replay Events',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 78,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _timeline.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (BuildContext context, int index) {
                                final TimelineEntry entry = _timeline[_timeline.length - 1 - index];
                                final bool isIncident = entry.incidentId != null;
                                return GestureDetector(
                                  onTap: () => _focusTimelineEntry(entry),
                                  child: Container(
                                    width: 136,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isIncident
                                          ? const Color(0xFFEF4444).withValues(alpha: 0.16)
                                          : Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isIncident ? const Color(0xFFEF4444).withValues(alpha: 0.6) : Colors.white10,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          _formatTime(entry.time),
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${entry.afterKg.toStringAsFixed(0)} kg',
                                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isIncident ? 'Incident Location' : 'Telemetry Point',
                                          style: TextStyle(
                                            color: isIncident ? const Color(0xFFEF4444) : Colors.white54,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (_tripPhase == TripPhase.before) {
                                      _startTripMonitoring();
                                      return;
                                    }
                                    if (_tripPhase == TripPhase.after) {
                                      _startTripMonitoring();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF08241B),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                    _tripPhase == TripPhase.during ? 'Monitoring Live' : (_tripPhase == TripPhase.after ? 'Replay Trip' : 'Start Trip'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _tripPhase == TripPhase.during ? _endTripMonitoring : _recenterAndResumeFollow,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A7B51),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(_tripPhase == TripPhase.during ? 'End Trip' : 'Recenter'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 34 + bottomInset,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showLayoverInfo = !_showLayoverInfo;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0C2B22).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        _showLayoverInfo ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: const Color(0xFF4ADE80),
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _showLayoverInfo ? 'Hide Info' : 'Show Info',
                        style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + ((b.latitude - a.latitude) * t),
      a.longitude + ((b.longitude - a.longitude) * t),
    );
  }

  double _lerpDouble(double a, double b, double t) {
    return a + ((b - a) * t);
  }

  double _bearingRadians(LatLng from, LatLng to) {
    return math.atan2(to.longitude - from.longitude, to.latitude - from.latitude);
  }

  double _lerpAngle(double a, double b, double t) {
    double diff = b - a;
    while (diff > math.pi) {
      diff -= 2 * math.pi;
    }
    while (diff < -math.pi) {
      diff += 2 * math.pi;
    }
    return a + (diff * t);
  }

  String _formatTime(DateTime value) {
    final String hh = value.hour.toString().padLeft(2, '0');
    final String mm = value.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _MapPin extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool highlighted;

  const _MapPin({required this.icon, required this.color, this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFF1A7B51) : const Color(0xFF0C2B22),
        shape: BoxShape.circle,
        border: Border.all(color: highlighted ? const Color(0xFF86EFAC) : Colors.white24),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final String title;
  final List<String> rows;

  const _TimelineCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF08241B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 11.4, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ...rows.take(4).map(
                (String row) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    row,
                    style: const TextStyle(color: Colors.white60, fontSize: 10.6),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
