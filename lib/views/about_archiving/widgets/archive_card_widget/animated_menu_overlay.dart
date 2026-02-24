import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 애니메이션이 적용된 메뉴 오버레이 위젯
/// Scale + Fade 애니메이션으로 부드럽게 나타나는 팝업 메뉴
/// 화면 하단 경계를 자동으로 감지하여 메뉴 위치 조정
class AnimatedMenuOverlay extends StatelessWidget {
  final Animation<double> scaleAnimation;
  final Animation<double> fadeAnimation;
  final Offset buttonPosition;
  final Size buttonSize;
  final Widget menuWidget;
  final VoidCallback onDismiss;

  /// 메뉴 너비 (기본값: 151.w)
  final double menuWidth;

  /// 메뉴 높이 (하단 경계 체크용)
  final double menuHeight;

  /// 메뉴와 버튼 사이 간격
  final double menuOffset;

  /// 화면 경계 여백
  final double screenPadding;

  /// 하단 네비게이션 바 높이 (SafeArea 포함)
  final double bottomNavHeight;

  const AnimatedMenuOverlay({
    super.key,
    required this.scaleAnimation,
    required this.fadeAnimation,
    required this.buttonPosition,
    required this.buttonSize,
    required this.menuWidget,
    required this.onDismiss,
    this.menuWidth = 151,
    this.menuHeight = 115,
    this.menuOffset = 8,
    this.screenPadding = 8,
    this.bottomNavHeight = 100,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final actualMenuWidth = menuWidth.w;
    final actualMenuHeight = menuHeight.h;

    // 메뉴가 버튼 아래에 표시될 경우의 bottom 위치
    final menuBottomIfBelow =
        buttonPosition.dy + buttonSize.height + menuOffset + actualMenuHeight;

    // 하단 경계 체크: 네비게이션 바를 가리는지 확인
    final bottomBoundary = screenHeight - bottomNavHeight;
    final shouldShowAbove = menuBottomIfBelow > bottomBoundary;

    // 메뉴 위치 계산
    double left = buttonPosition.dx + buttonSize.width - actualMenuWidth;
    double top;

    if (shouldShowAbove) {
      // 버튼 위쪽에 메뉴 표시
      top = buttonPosition.dy - actualMenuHeight - menuOffset;
    } else {
      // 버튼 아래쪽에 메뉴 표시 (기본)
      top = buttonPosition.dy + buttonSize.height + menuOffset;
    }

    // 화면 왼쪽 경계 체크
    if (left < screenPadding) {
      left = screenPadding;
    }
    // 화면 오른쪽 경계 체크
    if (left + actualMenuWidth > screenWidth - screenPadding) {
      left = screenWidth - actualMenuWidth - screenPadding;
    }

    // 애니메이션 정렬: 위쪽 표시면 bottomRight, 아래쪽 표시면 topRight
    final alignment = shouldShowAbove
        ? Alignment.bottomRight
        : Alignment.topRight;

    return Stack(
      children: [
        // 배경 터치 시 메뉴 닫기
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        // 애니메이션이 적용된 메뉴
        Positioned(
          left: left,
          top: top,
          child: AnimatedBuilder(
            animation: scaleAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: fadeAnimation.value,
                child: Transform.scale(
                  scale: scaleAnimation.value,
                  alignment: alignment,
                  child: child,
                ),
              );
            },
            child: menuWidget,
          ),
        ),
      ],
    );
  }
}
