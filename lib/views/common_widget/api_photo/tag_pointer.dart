import 'package:flutter/material.dart';

const double kTagPadding = 4.0;
const double kTagPointerHeight = 27.0;
const double kTagPointerOverlap = 2.0;

class TagBubble extends StatelessWidget {
  const TagBubble({
    super.key,
    required this.child,
    required this.contentSize,
    this.backgroundColor = const Color(0xFF959595),
    this.padding = kTagPadding,
    this.pointerHeight = kTagPointerHeight,
    this.pointerOverlap = kTagPointerOverlap,
  });

  final Widget child;
  final double contentSize;
  final Color backgroundColor;
  final double padding;
  final double pointerHeight;
  final double pointerOverlap;

  /// 콘텐츠 크기에 따른 태그 전체 너비 계산 메서드
  static double diameterForContent({
    required double contentSize,
    double padding = kTagPadding,
  }) {
    return contentSize + (padding * 2);
  }

  /// 콘텐츠 크기에 따른 태그 전체 높이 계산 메서드
  static double totalHeightForContent({
    required double contentSize,
    double padding = kTagPadding,
    double pointerHeight = kTagPointerHeight,
    double pointerOverlap = kTagPointerOverlap,
  }) {
    return diameterForContent(contentSize: contentSize, padding: padding) +
        pointerHeight -
        pointerOverlap;
  }

  /// 콘텐츠 크기에 따른 태그 포인터 위치 계산 메서드
  static Offset pointerTipOffset({
    required double contentSize,
    double padding = kTagPadding,
    double pointerHeight = kTagPointerHeight,
    double pointerOverlap = kTagPointerOverlap,
  }) {
    // 태그의 원형 부분의 중심에서 포인터의 끝까지의 오프셋 계산
    final diameter = diameterForContent(
      contentSize: contentSize,
      padding: padding,
    );
    return Offset(diameter / 2, diameter + pointerHeight - pointerOverlap);
  }

  @override
  Widget build(BuildContext context) {
    final diameter = diameterForContent(
      contentSize: contentSize,
      padding: padding,
    );
    final totalHeight = totalHeightForContent(
      contentSize: contentSize,
      padding: padding,
      pointerHeight: pointerHeight,
      pointerOverlap: pointerOverlap,
    );

    return SizedBox(
      width: diameter,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ],
      ),
    );
  }
}
