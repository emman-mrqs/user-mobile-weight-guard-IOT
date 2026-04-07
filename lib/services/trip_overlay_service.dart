import 'package:flutter/material.dart';

class TripOverlayService {
  static final ValueNotifier<bool> hideMainBottomNavNotifier =
      ValueNotifier<bool>(false);

  static void setMainBottomNavHidden(bool hidden) {
    if (hideMainBottomNavNotifier.value == hidden) {
      return;
    }
    hideMainBottomNavNotifier.value = hidden;
  }
}
