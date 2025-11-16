import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../../api_firebase/controllers/auth_controller.dart';
import '../../../../api_firebase/models/category_data_model.dart';

class CategoryInfoSection extends StatelessWidget {
  final CategoryDataModel category;

  const CategoryInfoSection({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final userId =
        Provider.of<AuthController>(context, listen: false).getUserId ??
        '카테고리 이름 오류';
    return Container(
      width: double.infinity,
      height: 62.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1c1c1c),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '카테고리 이름',
            style: TextStyle(
              color: const Color(0xFFAAAAAA),
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              fontFamily: 'Pretendard Variable',
            ),
          ),
          Flexible(
            child: Text(
              category.getDisplayName(userId),
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Pretendard Variable',
              ),
              overflow: TextOverflow.visible,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
