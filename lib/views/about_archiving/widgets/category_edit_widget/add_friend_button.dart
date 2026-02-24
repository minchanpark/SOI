import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';

class AddFriendButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AddFriendButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 62.h,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1c1c1c),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/person_add.png',
              width: 24.w,
              height: 24.h,
              color: Colors.white,
            ),
            SizedBox(width: 12.w),
            Text(
              'category.members.add_friend_action',
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
}
