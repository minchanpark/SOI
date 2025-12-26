import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/category_controller.dart'
    as api_category;
import 'package:soi/api/controller/user_controller.dart';
import '../../../api/models/category.dart';

class ExitButton extends StatelessWidget {
  final Category category;

  const ExitButton({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 62.h,
      child: ElevatedButton(
        onPressed: () => _showExitBottomSheet(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1c1c1c),
          foregroundColor: Color(0xffff0000),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/log_out.png', width: 24.w, height: 24.h),
            SizedBox(width: 12.w),
            Text(
              'category.leave.button',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Pretendard Variable',
              ),
            ).tr(),
          ],
        ),
      ),
    );
  }

  // 카테고리 나가기 확인 바텀시트 표시
  void _showExitBottomSheet(BuildContext context) {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: Color(0xff323232),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'category.leave.title',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Pretendard Variable',
                ),
              ).tr(),
              SizedBox(height: 12.h),
              Text(
                'category.leave.confirm',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFCCCCCC),
                  fontSize: 14.sp,
                  fontFamily: 'Pretendard Variable',
                ),
              ).tr(),
              SizedBox(height: 24.h),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();

                        final categoryController = context
                            .read<api_category.CategoryController>();
                        final userController =
                            context.read<UserController>();
                        final currentUser = userController.currentUser;

                        if (currentUser == null) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                tr(
                                  'common.user_info_unavailable',
                                  context: context,
                                ),
                              ),
                              backgroundColor: const Color(0xFFcccccc),
                            ),
                          );
                          return;
                        }

                        final success = await categoryController.leaveCategory(
                          userId: currentUser.id,
                          categoryId: category.id,
                        );

                        if (success) {
                          navigator.popUntil((route) => route.isFirst);
                        } else {
                          final message =
                              categoryController.errorMessage ??
                              tr('category.leave.failed', context: context);
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(message),
                              backgroundColor: const Color(0xFFcccccc),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(19),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'category.leave.button',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Pretendard Variable',
                        ),
                      ).tr(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff323232),
                        foregroundColor: Colors.white,
                        overlayColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(19),
                        ),
                      ),
                      child: Text(
                        'common.cancel',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFFcccccc),
                          fontFamily: 'Pretendard Variable',
                        ),
                      ).tr(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
