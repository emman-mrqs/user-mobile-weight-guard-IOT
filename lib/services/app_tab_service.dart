import 'package:flutter/material.dart';

class AppTabService {
  static final ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> tripNavigationRevealNotifier =
      ValueNotifier<int>(0);
  static final ValueNotifier<Set<String>> pickupArrivedTaskIdsNotifier =
      ValueNotifier<Set<String>>(<String>{});

  static void selectTab(int index) {
    currentIndexNotifier.value = index;
  }

  static void revealTripNavigation() {
    tripNavigationRevealNotifier.value += 1;
  }

  static bool isPickupArrived(String taskId) {
    return pickupArrivedTaskIdsNotifier.value.contains(taskId);
  }

  static void markPickupArrived(String taskId) {
    final Set<String> next = Set<String>.from(
      pickupArrivedTaskIdsNotifier.value,
    )..add(taskId);
    pickupArrivedTaskIdsNotifier.value = next;
  }

  static void clearPickupArrived(String taskId) {
    final Set<String> current = pickupArrivedTaskIdsNotifier.value;
    if (!current.contains(taskId)) {
      return;
    }

    final Set<String> next = Set<String>.from(current)..remove(taskId);
    pickupArrivedTaskIdsNotifier.value = next;
  }
}