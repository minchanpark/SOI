import 'package:flutter/material.dart';

import 'wave_form_painter.dart';

/// 커스텀 파형 위젯
class CustomWaveformWidget extends StatelessWidget {
  final List<double> waveformData;
  final Color color;
  final Color activeColor;
  final double progress;
  final double barThickness;
  final double barSpacing;
  final double maxBarHeightFactor;
  final double amplitudeScale;
  final double minBarHeight;
  final StrokeCap strokeCap;

  const CustomWaveformWidget({
    super.key,
    required this.waveformData,
    required this.activeColor,
    this.progress = 0.0,
    this.barThickness = 3.0,
    this.barSpacing = 7.0,
    this.maxBarHeightFactor = 0.5,
    this.amplitudeScale = 1.0,
    this.minBarHeight = 0.0,
    this.strokeCap = StrokeCap.round,
    required this.color, // 0.0 ~ 1.0
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: WaveformPainter(
        waveformData: waveformData,
        color: color,
        activeColor: activeColor,
        progress: progress,
        barThickness: barThickness,
        barSpacing: barSpacing,
        maxBarHeightFactor: maxBarHeightFactor,
        amplitudeScale: amplitudeScale,
        minBarHeight: minBarHeight,
        strokeCap: strokeCap,
      ),
      size: Size.infinite,
    );
  }
}
