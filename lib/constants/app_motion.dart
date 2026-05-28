import 'package:flutter/material.dart';

/// Shared motion scale used across the app so animation timing feels cohesive.
class AppMotion {
  static const Curve standardCurve = Curves.fastOutSlowIn;
  static const Curve emphasizedCurve = Curves.easeInOutCubicEmphasized;

  static const Duration quick = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 360);
  static const Duration emphasized = Duration(milliseconds: 520);

  static const Duration routeForward = Duration(milliseconds: 360);
  static const Duration routeReverse = Duration(milliseconds: 260);

  static const Duration layoutHold = Duration(milliseconds: 1100);
  static const Duration layoutApplyDelay = Duration(milliseconds: 140);
  static const Duration layoutFitDelay = Duration(milliseconds: 220);
}
