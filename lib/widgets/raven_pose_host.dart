import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_motion.dart';
import 'raven_mascot.dart';

/// Mixin for stateful widgets that display the raven mascot.
/// Manages pose timing, reduced motion compliance, disposal, and deduplication keys.
mixin RavenPoseHost<T extends StatefulWidget> on State<T> {
  RavenState _resting = RavenState.idle;
  RavenState _pose = RavenState.idle;
  Timer? _poseTimer;
  final Set<String> _firedKeys = <String>{};

  /// Set the resting pose to which the mascot returns when idle.
  set ravenResting(RavenState p) {
    if (_resting == p) return;
    setState(() {
      _resting = p;
      if (_poseTimer == null || !_poseTimer!.isActive) {
        _pose = p;
      }
    });
  }

  /// Current active pose for passing to [RavenMascot].
  RavenState get ravenPose => _pose;

  /// Play [pose] once per distinct [onceKey], then return to resting state.
  void playRavenPose(RavenState pose, {required String onceKey, Duration? hold}) {
    // 1. Deduplicate by key first so bookkeeping is identical in all modes
    if (_firedKeys.contains(onceKey)) return;
    _firedKeys.add(onceKey);

    // 2. Skip motion entirely under reduced motion
    if (AppMotion.reduce(context)) return;

    // 3. Post-frame callback allows calling straight from build() without setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _poseTimer?.cancel();
      setState(() {
        _pose = pose;
      });

      final duration = hold ?? _defaultHold(pose);
      _poseTimer = Timer(duration, () {
        if (mounted) {
          setState(() {
            _pose = _resting;
          });
        }
      });
    });
  }

  Duration _defaultHold(RavenState pose) {
    switch (pose) {
      case RavenState.peck:
        return AppMotion.fast; // 180ms
      case RavenState.alert:
      case RavenState.startle:
      case RavenState.caw:
        return AppMotion.standard; // 300ms
      case RavenState.preen:
      case RavenState.bow:
        return AppMotion.emphasis; // 600ms
      case RavenState.flap:
        return const Duration(milliseconds: 660);
      default:
        return AppMotion.standard;
    }
  }

  @override
  void dispose() {
    _poseTimer?.cancel();
    super.dispose();
  }
}
