import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class CameraAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CameraAppBar({super.key});

  @override
  Size get preferredSize => Size.fromHeight(70.h);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leadingWidth: 90.w,
      centerTitle: true,
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
    );
  }
}
