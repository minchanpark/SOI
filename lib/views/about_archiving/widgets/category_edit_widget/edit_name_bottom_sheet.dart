import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../../../../api/controller/category_controller.dart' as api_category;
import '../../../../api/controller/user_controller.dart';
import '../../../../api/models/category.dart';
import '../../../../utils/snackbar_utils.dart';

/// 카테고리 이름 수정 바텀시트 위젯
///
/// 카테고리 이름을 수정할 수 있는 입력 필드와
/// 확인/취소 버튼을 제공합니다.
///
/// Parameters:
/// - [category]: 수정할 카테고리 정보
/// - [onSuccess]: 수정 성공 시 호출되는 콜백 함수
class EditNameBottomSheet extends StatefulWidget {
  final Category category;
  final Function(String) onSuccess;

  const EditNameBottomSheet({
    super.key,
    required this.category,
    required this.onSuccess,
  });

  @override
  State<EditNameBottomSheet> createState() => _EditNameBottomSheetState();
}

class _EditNameBottomSheetState extends State<EditNameBottomSheet> {
  late TextEditingController _editController;
  late ValueNotifier<bool> _hasTextChanged;
  late String _originalName;

  @override
  void initState() {
    super.initState();
    _originalName = widget.category.name;
    _editController = TextEditingController(text: _originalName);
    _hasTextChanged = ValueNotifier<bool>(false);
    _editController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _editController.removeListener(_onTextChanged);
    _editController.dispose();
    _hasTextChanged.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasChanged = _editController.text.trim() != _originalName.trim();
    if (_hasTextChanged.value != hasChanged) {
      _hasTextChanged.value = hasChanged;
    }
  }

  Future<void> _handleConfirm() async {
    final trimmedText = _editController.text.trim();

    if (trimmedText.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        tr('archive.edit_name_required', context: context),
      );
      return;
    }

    try {
      final userController = context.read<UserController>();
      final categoryController = context
          .read<api_category.CategoryController>();

      final userId = userController.currentUser?.id;
      if (userId == null) {
        SnackBarUtils.showSnackBar(
          context,
          tr('common.login_required', context: context),
        );
        return;
      }

      final success = await categoryController.updateCustomName(
        categoryId: widget.category.id,
        userId: userId,
        name: trimmedText,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (success) {
        widget.onSuccess(tr('archive.edit_name_success', context: context));
      } else {
        widget.onSuccess(
          categoryController.errorMessage ??
              tr('archive.edit_name_error', context: context),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess(tr('archive.edit_name_error', context: context));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1c1c1c),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들바
              Container(
                margin: EdgeInsets.only(top: 12.w),
                width: 56.w,
                height: 3.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFcccccc),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 9.h),
              Text(
                'archive.menu.edit_name',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 18.sp,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w700,
                ),
              ).tr(),
              Divider(color: const Color(0xFF5A5A5A)),

              // TextField
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                child: TextField(
                  controller: _editController,
                  autofocus: true,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Pretendard Variable',
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2a2a2a),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF5A5A5A)),
                    ),
                  ),
                ),
              ),

              // 버튼
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                child: Row(
                  children: [
                    // 취소 버튼
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 48.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2a2a2a),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'common.cancel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Pretendard Variable',
                            ),
                          ).tr(),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    // 확인 버튼
                    Expanded(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _hasTextChanged,
                        builder: (context, hasChanged, child) {
                          return GestureDetector(
                            onTap: hasChanged ? _handleConfirm : null,
                            child: Container(
                              height: 48.h,
                              decoration: BoxDecoration(
                                color: hasChanged
                                    ? const Color(0xFFffffff)
                                    : const Color(0xFF5a5a5a),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'common.confirm',
                                style: TextStyle(
                                  color: hasChanged
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Pretendard Variable',
                                ),
                              ).tr(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }
}
