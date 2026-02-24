import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';

/// 공통으로 사용되는 계속하기 버튼
class ContinueButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback? onPressed;
  final String? text;

  const ContinueButton({
    super.key,
    required this.isEnabled,
    required this.onPressed,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    final buttonText = text ?? tr('common.continue', context: context);

    return Center(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26.9),
          ),
        ),
        onPressed: isEnabled ? onPressed : null,
        child: Container(
          width: 349.w,
          height: 59.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isEnabled ? Colors.white : const Color(0xff323232),
            borderRadius: BorderRadius.circular(26.9),
          ),
          child: Text(
            buttonText,
            style: TextStyle(
              color: isEnabled ? Colors.black : Colors.grey,
              fontSize: 20.sp,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
