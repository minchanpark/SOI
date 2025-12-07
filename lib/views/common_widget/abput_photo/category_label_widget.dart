import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 카테고리 이름 라벨 위젯
/// 단일 책임: 카테고리 이름 표시 및 탭 처리
class CategoryLabelWidget extends StatelessWidget {
  final String categoryName;
  final VoidCallback onTap;

  const CategoryLabelWidget({
    super.key,
    required this.categoryName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: IntrinsicWidth(
        child: Container(
          height: (24.3).h,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(left: 15.w, right: 15.w, bottom: 2.h),
              child: Text(
                categoryName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: "Pretendard",
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
