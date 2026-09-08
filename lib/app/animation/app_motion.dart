import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const Duration routeDuration = Duration(milliseconds: 330);

  static const Duration routeReverseDuration = Duration(milliseconds: 270);

  static const Duration loginEntranceDuration = Duration(milliseconds: 780);

  static const Curve standardCurve = Curves.easeOutCubic;

  static const Curve emphasizedCurve = Curves.easeOutQuart;
}
