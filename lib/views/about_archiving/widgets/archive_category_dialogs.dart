import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../api_firebase/models/category_data_model.dart';
import '../../../api/models/category.dart' as api;

// 카테고리 관련 다이얼로그들을 관리합니다.
// 팝업 메뉴에서 호출되는 다이얼로그들을 포함합니다.
class ArchiveCategoryDialogs {
  /// 카테고리 나가기 확인 바텀시트 (피그마 디자인) - Firebase 버전
  static void showLeaveCategoryBottomSheet(
    BuildContext context,
    CategoryDataModel category, {
    required VoidCallback onConfirm,
  }) {
    _showLeaveCategoryBottomSheetInternal(context, onConfirm: onConfirm);
  }

  /// 카테고리 나가기 확인 바텀시트 - REST API 버전
  static void showLeaveCategoryBottomSheetApi(
    BuildContext context,
    api.Category category, {
    required VoidCallback onConfirm,
  }) {
    _showLeaveCategoryBottomSheetInternal(context, onConfirm: onConfirm);
  }

  /// 내부 구현 - 공통 바텀시트 UI
  static void _showLeaveCategoryBottomSheetInternal(
    BuildContext context, {
    required VoidCallback onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
          decoration: BoxDecoration(
            color: const Color(0xFF323232),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14.22),
              topRight: Radius.circular(14.22),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 제목
              Text(
                '카테고리 나가기',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                  fontSize: (19.78).sp,
                  color: Color(0xFFF9F9F9),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Text(
                '카테고리를 나가면, 해당 카테고리에 저장된 사진은 더 이상 확인할 수 없으며 복구가 불가능합니다.',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: (15.78).sp,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                  height: 1.66,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.h),

              // 버튼들
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 나가기 버튼
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF9F9F9),
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      overlayColor: Colors.white.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                    child: SizedBox(
                      width: 344,
                      height: 38,
                      child: Center(
                        child: Text(
                          '나가기',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                            fontSize: (17.8).sp,
                            color: Color(0xFF000000),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 취소 버튼
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      overlayColor: Colors.white.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                    child: SizedBox(
                      width: 344,
                      height: 38,
                      child: Center(
                        child: Text(
                          '취소',
                          style: TextStyle(
                            fontFamily: 'Pretendard Variable',
                            fontWeight: FontWeight.w500,
                            fontSize: (17.8).sp,
                            color: Color(0xFFCCCCCC),
                          ),
                        ),
                      ),
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
