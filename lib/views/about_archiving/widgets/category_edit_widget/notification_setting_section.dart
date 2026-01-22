import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../api/controller/category_controller.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../utils/snackbar_utils.dart';

/// 카테고리 알림 설정 섹션
///
/// 카테고리에 대한 알림 on/off를 토글합니다.
/// API: POST /category/set/alert
///
/// 알림 상태는 로컬(SharedPreferences)에 저장되어 앱 재시작 후에도 유지됩니다.
class NotificationSettingSection extends StatefulWidget {
  final int categoryId;

  const NotificationSettingSection({super.key, required this.categoryId});

  @override
  State<NotificationSettingSection> createState() =>
      _NotificationSettingSectionState();
}

class _NotificationSettingSectionState
    extends State<NotificationSettingSection> {
  bool _isNotificationEnabled = true; // 기본값: 알림 활성화
  bool _isLoading = false;
  bool _isInitialized = false;

  /// SharedPreferences 키 생성
  String get _prefKey => 'category_alert_${widget.categoryId}';

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  @override
  void didUpdateWidget(NotificationSettingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      _loadSavedState();
    }
  }

  /// SharedPreferences에서 저장된 알림 상태 로드
  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getBool(_prefKey);

    if (mounted) {
      setState(() {
        // 저장된 값이 있으면 사용, 없으면 기본값 true (알림 활성화)
        _isNotificationEnabled = savedValue ?? true;
        _isInitialized = true;
      });
    }
  }

  /// SharedPreferences에 알림 상태 저장
  Future<void> _saveState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
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

    // 클라이언트에서 먼저 상태 반전 (서버도 토글 방식이므로 동기화됨)
    final newState = !_isNotificationEnabled;

    setState(() => _isLoading = true);

    try {
      // API 호출 (서버에서 토글됨)
      await categoryController.setCategoryAlert(
        categoryId: widget.categoryId,
        userId: currentUser.id,
      );

      // 새 상태를 로컬에 저장
      await _saveState(newState);

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
    SnackBarUtils.showSnackBar(
      context,
      message,
      duration: const Duration(seconds: 2),
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
            onTap: (_isLoading || !_isInitialized) ? null : _toggleNotification,
            child: (_isLoading || !_isInitialized)
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
