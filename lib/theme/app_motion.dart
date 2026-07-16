import 'package:flutter/material.dart';

class AppMotion {
  static const fast     = Duration(milliseconds: 180); // presses, stamps
  static const standard = Duration(milliseconds: 300); // fades, state swaps
  static const scene    = Duration(milliseconds: 450); // route transition
  static const emphasis = Duration(milliseconds: 600); // title settle, flips
  static const deal     = Duration(milliseconds: 1250); // U3 interstitial total
  static const ceremonyStep = Duration(milliseconds: 900); // U6 per-honor cadence
  
  static bool reduce(BuildContext c) => MediaQuery.of(c).accessibleNavigation;
}
