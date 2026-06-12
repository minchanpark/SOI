import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// SOI 댓글 입력 진입점에서 카메라, 텍스트, 마이크 액션을 한 줄로 노출합니다.
class SoiTagBaseBarWidget extends StatelessWidget {
  const SoiTagBaseBarWidget({
    super.key,
    required this.onCenterTap,
    required this.placeholderText,
    required this.cameraIcon,
    required this.micIcon,
    this.onCameraPressed,
    this.onMicPressed,
  });

  final VoidCallback onCenterTap;
  final String placeholderText;
  final Widget cameraIcon;
  final Widget micIcon;
  final VoidCallback? onCameraPressed;
  final VoidCallback? onMicPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 353,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1c),
        borderRadius: BorderRadius.circular(52),
      ),
      child: Row(
        children: [
          IconButton(onPressed: onCameraPressed, icon: cameraIcon),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCenterTap,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  placeholderText,
                  style: TextStyle(
                    color: const Color(0xFFF8F8F8),
                    fontSize: 16.sp,
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w200,
                    letterSpacing: -1.14,
                  ),
                ),
              ),
            ),
          ),
          IconButton(onPressed: onMicPressed, icon: micIcon),
        ],
      ),
    );
  }
}
