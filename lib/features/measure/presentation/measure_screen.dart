import 'package:flutter/material.dart';

import 'measurement_session_screen.dart';

/// 互換のため `MeasureScreen` は残しつつ、実体は `MeasurementSessionScreen` に委譲する。
class MeasureScreen extends StatelessWidget {
  const MeasureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MeasurementSessionScreen();
  }
}

