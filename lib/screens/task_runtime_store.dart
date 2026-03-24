import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class TaskRuntimeController extends ChangeNotifier {
  TaskRuntimeController({required this.maxKg}) {
    _initialReferenceWeightKg = 900 + (_random.nextDouble() * 250);
    _latestWeightKg = _initialReferenceWeightKg;
    _startedAt = DateTime.now();
  }

  final int maxKg;
  final Random _random = Random();

  Timer? _timer;
  bool _isScaleConnected = true;
  late DateTime _startedAt;
  late double _initialReferenceWeightKg;
  late double _latestWeightKg;

  bool get isScaleConnected => _isScaleConnected;
  DateTime get startedAt => _startedAt;
  double get initialReferenceWeightKg => _initialReferenceWeightKg;
  double get latestWeightKg => _latestWeightKg;

  double get utilization => (_latestWeightKg / maxKg).clamp(0, 1);

  String get loadStatus {
    if (_latestWeightKg > maxKg) {
      return 'Overload';
    }
    return 'Normal';
  }

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isScaleConnected) {
        return;
      }
      final double drift = (_random.nextDouble() * 60) - 30;
      _latestWeightKg = max(0, _latestWeightKg + drift);
      notifyListeners();
    });
  }

  void setConnected(bool value) {
    _isScaleConnected = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class TaskRuntimeStore {
  static final Map<String, TaskRuntimeController> _controllers = <String, TaskRuntimeController>{};

  static TaskRuntimeController forTask({required String taskId, required int maxKg}) {
    return _controllers.putIfAbsent(
      taskId,
      () => TaskRuntimeController(maxKg: maxKg),
    );
  }

  static TaskRuntimeController? existing(String taskId) => _controllers[taskId];

  static void clearTask(String taskId) {
    _controllers.remove(taskId)?.dispose();
  }
}
