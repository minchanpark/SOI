import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../api/controller/category_controller.dart';
import '../../../../api/controller/user_controller.dart';

/// 카테고리 알림 설정 섹션
///
/// 카테고리에 대한 알림 on/off를 토글합니다.
/// API: POST /category/set/alert
class NotificationSettingSection extends StatefulWidget {
  final int categoryId;
  final bool initialValue;

  const NotificationSettingSection({
    super.key,
    required this.categoryId,
    this.initialValue = true,
  });

  @override
  State<NotificationSettingSection> createState() =>
      _NotificationSettingSectionState();
}

class _NotificationSettingSectionState
    extends State<NotificationSettingSection> {
  late bool _isNotificationEnabled;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isNotificationEnabled = widget.initialValue;
  }

  @override
  void didUpdateWidget(NotificationSettingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _isNotificationEnabled = widget.initialValue;
    }
  }

  Future<void> _toggleNotification() async {
    if (_isLoading) return;

    final userController = context.read<UserController>();
    final categoryController = context.read<CategoryController>();
    final currentUser = userController.currentUser;

    if (currentUser == null) {
      _showSnackBar(tr('common.login_required'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newState = await categoryController.setCategoryAlert(
        categoryId: widget.categoryId,
        userId: currentUser.id,
      );

      if (mounted) {
        setState(() {
          _isNotificationEnabled = newState;
          _isLoading = false;
        });

        _showSnackBar(
          newState
              ? tr('category.notification.enabled')
              : tr('category.notification.disabled'),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(tr('category.notification.error'));
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF5a5a5a),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 62.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1c1c1c),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'category.notification.title',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                fontFamily: 'Pretendard Variable',
              ),
            ).tr(),
          ),
          GestureDetector(
            onTap: _isLoading ? null : _toggleNotification,
            child: _isLoading
                ? SizedBox(
                    width: 50.w,
                    height: 26.h,
                    child: Center(
                      child: SizedBox(
                        width: 20.w,
                        height: 20.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : _notificationSwitch(_isNotificationEnabled),
          ),
        ],
      ),
    );
  }

  Widget _notificationSwitch(bool isNotificationEnabled) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 50.w,
      height: 26.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13.r),
        color: isNotificationEnabled
            ? const Color(0xffffffff)
            : const Color(0xff5a5a5a),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: isNotificationEnabled
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          width: 22.w,
          height: 22.h,
          margin: EdgeInsets.symmetric(horizontal: 2.w),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xff000000),
          ),
        ),
      ),
    );
  }
}
