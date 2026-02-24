import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../api/models/category.dart';

class CategoryInfoSection extends StatelessWidget {
  final Category category;
  final VoidCallback? onTap;

  const CategoryInfoSection({super.key, required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: const Color(0xFF1c1c1c),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'category.name_label',
              style: TextStyle(
                color: const Color(0xFFAAAAAA),
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                fontFamily: 'Pretendard Variable',
              ),
            ).tr(),
            SizedBox(height: 8.h),
            Text(
              category.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Pretendard Variable',
              ),
              overflow: TextOverflow.visible,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
