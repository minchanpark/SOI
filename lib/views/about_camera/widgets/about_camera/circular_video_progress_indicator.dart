import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 비디오 녹화용 원형 Progress Indicator
///
/// 중앙에 작은 원(innerSize)이 있고, 그 주변을 gap만큼 떨어진
/// 위치에서 원형 progress bar가 채워집니다.
///
/// - 채워진 부분: white
/// - 채워지지 않은 부분: white.withValues(alpha: 0.44)
class CircularVideoProgressIndicator extends StatelessWidget {
  /// Progress 진행률 (0.0 ~ 1.0)
  final double progress;

  /// 중앙 원의 크기 (지름)
  final double innerSize;

  /// 중앙 원과 progress bar 사이의 간격
  final double gap;

  /// Progress bar의 선 두께
  final double strokeWidth;

  const CircularVideoProgressIndicator({
    super.key,
    required this.progress,
    this.innerSize = 40.42,
    this.gap = 15.29,
    this.strokeWidth = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    // Progress 원의 반지름 계산
    final double progressRadius = (innerSize / 2) + gap;
    // 전체 위젯 크기 (지름 + stroke width 여유)
    final double totalSize = (progressRadius * 2) + (strokeWidth * 2);

    return SizedBox(
      width: totalSize,
      height: totalSize,
      child: CustomPaint(
        painter: _CircularVideoProgressPainter(
          progress: progress.clamp(0.0, 1.0),
          innerSize: innerSize,
          gap: gap,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _CircularVideoProgressPainter extends CustomPainter {
  final double progress;
  final double innerSize;
  final double gap;
  final double strokeWidth;

  _CircularVideoProgressPainter({
    required this.progress,
    required this.innerSize,
    required this.gap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final progressRadius = (innerSize / 2) + gap;

    // 1. 중앙 원 그리기 (40.42 × 40.42)
    final innerCirclePaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

    canvas.drawCircle(center, innerSize / 2, innerCirclePaint);

    // 2. Progress bar 배경 (채워지지 않은 부분) 그리기
    final backgroundPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.44)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, progressRadius, backgroundPaint);

    // 3. Progress bar 전경 (채워진 부분) 그리기
    if (progress > 0) {
      final progressPaint =
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round;

      // -90도(12시 방향)에서 시작하여 시계방향으로 그리기
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: progressRadius),
        -math.pi / 2, // 시작 각도 (12시 방향)
        sweepAngle, // 어느 방향으로 그릴 지 결정 --> 시계방향으로
        false,
        progressPaint, // 채워진 호 그리기
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularVideoProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.innerSize != innerSize ||
        oldDelegate.gap != gap ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
