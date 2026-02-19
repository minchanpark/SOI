import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// 카메라 프리뷰 로딩중일 때, 표시할 Shimmer 위젯입니다.
class CameraShimmerBox extends StatelessWidget {
  const CameraShimmerBox({
    required this.width,
    required this.height,
    required this.borderRadius,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      period: const Duration(milliseconds: 1500),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
