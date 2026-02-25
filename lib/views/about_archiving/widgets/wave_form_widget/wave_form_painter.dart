import 'package:flutter/material.dart';
import 'dart:math';

// 파형을 그리는 커스텀 페인터
class WaveformPainter extends CustomPainter {
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

  WaveformPainter({
    required this.waveformData,
    required this.color,
    required this.activeColor,
    required this.progress,
    this.barThickness = 3.0,
    this.barSpacing = 7.0,
    this.maxBarHeightFactor = 0.5,
    this.amplitudeScale = 1.0,
    this.minBarHeight = 0.0,
    this.strokeCap = StrokeCap.round,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final effectiveSpacing = barSpacing <= 0 ? 1.0 : barSpacing;
    final barCount = max(1, (size.width / effectiveSpacing).floor());
    final effectiveHeightFactor = maxBarHeightFactor.clamp(0.0, 1.0);
    final effectiveAmplitudeScale = amplitudeScale <= 0 ? 1.0 : amplitudeScale;
    final effectiveMinBarHeight = minBarHeight < 0 ? 0.0 : minBarHeight;

    final paint = Paint()
      ..strokeWidth = barThickness
      ..strokeCap = strokeCap;

    // 바의 샘플링된 데이터
    final sampledData = _stretchData(waveformData, barCount);

    final centerY = size.height / 2;

    // 파형의 최대 바의 높이는 전체적으로 조절하는 부분
    final maxBarHeight = size.height * effectiveHeightFactor;

    for (int i = 0; i < barCount; i++) {
      final x = i * effectiveSpacing;
      if (x >= size.width) break;

      // 파형 높이 계산 (0.0 ~ 1.0 범위의 데이터를 바 높이로 변환)
      final normalizedHeight = (sampledData[i] * effectiveAmplitudeScale).clamp(
        0.0,
        1.0,
      );
      var barHeight = max(
        effectiveMinBarHeight,
        normalizedHeight * maxBarHeight,
      );
      barHeight = barHeight.clamp(0.0, maxBarHeight);

      // 진행 상태에 따라 색상 결정
      final isActive = progress > 0 && (i / barCount) <= progress;
      paint.color = isActive ? activeColor : color;

      // 파형 바 그리기 (중앙에서 위아래로)
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  // 파형 데이터를 지정된 개수로 늘려서 전체 너비를 채움
  List<double> _stretchData(List<double> data, int targetCount) {
    if (data.isEmpty) return List.filled(targetCount, 0.0);
    if (data.length >= targetCount) {
      // 데이터가 충분히 많으면 샘플링
      return _sampleData(data, targetCount);
    }

    // 데이터가 부족하면 보간(interpolation)으로 늘림
    final stretchedData = <double>[];
    final ratio = (data.length - 1) / (targetCount - 1);

    for (int i = 0; i < targetCount; i++) {
      final index = i * ratio;
      final lowerIndex = index.floor();
      final upperIndex = (lowerIndex + 1).clamp(0, data.length - 1);
      final fraction = index - lowerIndex;

      // 선형 보간
      final interpolatedValue =
          data[lowerIndex] * (1 - fraction) + data[upperIndex] * fraction;
      stretchedData.add(interpolatedValue);
    }

    return stretchedData;
  }

  // 파형 데이터를 지정된 개수로 샘플링
  List<double> _sampleData(List<double> data, int targetCount) {
    if (data.length <= targetCount) return data;

    final step = data.length / targetCount;
    final sampledData = <double>[];

    for (int i = 0; i < targetCount; i++) {
      final startIndex = (i * step).floor();
      final endIndex = ((i + 1) * step).floor().clamp(0, data.length);

      // 구간 내 RMS(Root Mean Square) 사용 (더 실제적인 음성 레벨)
      double sum = 0.0;
      int count = 0;

      // 제곱값의 합
      for (int j = startIndex; j < endIndex; j++) {
        sum += data[j] * data[j];
        count++;
      }
      double rmsValue = count > 0 ? sqrt(sum / count) : 0.0;
      sampledData.add(rmsValue);
    }

    return sampledData;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! WaveformPainter ||
        oldDelegate.waveformData != waveformData ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.barThickness != barThickness ||
        oldDelegate.barSpacing != barSpacing ||
        oldDelegate.maxBarHeightFactor != maxBarHeightFactor ||
        oldDelegate.amplitudeScale != amplitudeScale ||
        oldDelegate.minBarHeight != minBarHeight ||
        oldDelegate.strokeCap != strokeCap;
  }
}
