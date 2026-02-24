import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// shimmer는 한 번만 보여주고, 로딩이 계속되면 기본 아이콘을 보여줍니다.
///
/// 네트워크가 느리거나 요청이 hang 되는 경우 shimmer가 무한히 도는 UX를 방지합니다.
/// 이미지가 실제로 로드되면 CachedNetworkImage가 이 placeholder를 자동으로 대체합니다.
class ShimmerOnceThenFallbackIcon extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final int? shimmerCycles; //  Shimmer가 몇번 돌 지
  final Duration? fallbackDelay;

  const ShimmerOnceThenFallbackIcon({
    super.key,
    required this.width,
    required this.height,
    required this.borderRadius,
    this.shimmerCycles,
    this.fallbackDelay,
  });

  @override
  State<ShimmerOnceThenFallbackIcon> createState() =>
      _ShimmerOnceThenFallbackIconState();
}

class _ShimmerOnceThenFallbackIconState
    extends State<ShimmerOnceThenFallbackIcon> {
  static const Duration _fallbackDelay = Duration(milliseconds: 600);

  static const Duration _shimmerPeriod = Duration(milliseconds: 1500);
  Timer? _timer;
  bool _showFallback = false;

  @override
  void initState() {
    super.initState();
    final cycles = widget.shimmerCycles;
    final delay = (cycles != null && cycles > 0)
        ? Duration(milliseconds: _shimmerPeriod.inMilliseconds * cycles)
        : (widget.fallbackDelay ?? _fallbackDelay);
    _timer = Timer(delay, () {
      if (!mounted) return;
      setState(() => _showFallback = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showFallback) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFCACACA).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: const Icon(Icons.image, color: Color(0xff5a5a5a), size: 32),
      );
    }

    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      period: _shimmerPeriod,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}
