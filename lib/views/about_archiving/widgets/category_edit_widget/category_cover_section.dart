import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../api_firebase/models/category_data_model.dart';

class CategoryCoverSection extends StatelessWidget {
  final CategoryDataModel category;
  final VoidCallback onTap;

  const CategoryCoverSection({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 173.h,
        decoration: BoxDecoration(
          // 기존 색상을 유지하면서 이미지를 배경으로 추가
          color: const Color(0xFF5A5A5A),
          borderRadius: BorderRadius.circular(8),
          image:
              category.categoryPhotoUrl != null &&
                  category.categoryPhotoUrl!.isNotEmpty
              ? DecorationImage(
                  image: CachedNetworkImageProvider(category.categoryPhotoUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        // child는 Container로 감싸서 opacity 적용
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, color: Colors.white, size: 51.sp),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '표지사진 수정',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Pretendard Variable',
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Image.asset('assets/edit.png', width: 18.w, height: 18.h),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
