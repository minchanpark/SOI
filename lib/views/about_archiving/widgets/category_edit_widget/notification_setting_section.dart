import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationSettingSection extends StatefulWidget {
  const NotificationSettingSection({super.key});

  @override
  State<NotificationSettingSection> createState() =>
      _NotificationSettingSectionState();
}

class _NotificationSettingSectionState
    extends State<NotificationSettingSection> {
  bool _isNotificationEnabled = true;
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
              '알림설정',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                fontFamily: 'Pretendard Variable',
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isNotificationEnabled = !_isNotificationEnabled;
              });
            },
            child: _notificationSwitch(_isNotificationEnabled),
          ),
        ],
      ),
    );
  }
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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xff000000),
        ),
      ),
    ),
  );
}
