import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 통일된 스타일의 스낵바를 표시하는 유틸리티 클래스
class SnackBarUtils {
  /// 표준 스낵바를 표시합니다.
  ///
  /// - 배경색: #5a5a5a (회색)
  /// - 크기: 532x87 (화면 크기에 따라 조절)
  /// - 모서리: 15 라운드
  /// - 위치: 하단에서 떨어진 floating 스타일
  /// - 텍스트: 중앙 정렬
  static void showSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 1),
  }) {
    // 기존 스낵바가 있으면 제거
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF5a5a5a),
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.r),
        ),
        margin: EdgeInsets.only(bottom: 50.h, left: 24.w, right: 24.w),
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
        elevation: 6,
      ),
    );
  }
}
