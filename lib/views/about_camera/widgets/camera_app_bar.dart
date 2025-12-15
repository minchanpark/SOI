import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/notification_controller.dart';

class CameraAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CameraAppBar({
    required this.onContactsTap,
    required this.onNotificationsTap,
    super.key,
  });

  final VoidCallback onContactsTap;
  final VoidCallback onNotificationsTap;

  @override
  Size get preferredSize => Size.fromHeight(70.h);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leadingWidth: 90.w,
      title: Column(
        children: [
          Text(
            'SOI',
            style: TextStyle(
              color: const Color(0xfff9f9f9),
              fontSize: 20.sp,
              fontFamily: GoogleFonts.inter().fontFamily,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 30.h),
        ],
      ),
      backgroundColor: Colors.black,
      toolbarHeight: 70.h,
      leading: Row(
        children: [
          SizedBox(width: 32.w),
          IconButton(
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: onContactsTap,
            icon: Container(
              width: 35,
              height: 35,
              decoration: const BoxDecoration(
                color: Color(0xff1c1c1c),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people, color: Colors.white, size: 25.sp),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 32.w),
          child: Center(
            child: Consumer<NotificationController>(
              builder: (context, _, child) {
                return IconButton(
                  onPressed: onNotificationsTap,
                  icon: Container(
                    width: 35,
                    height: 35,
                    padding: EdgeInsets.only(bottom: 3.h),
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xff1c1c1c),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: Image.asset(
                        "assets/notification.png",
                        width: 25.sp,
                        height: 25.sp,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
