import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../api/controller/user_controller.dart';
import '../../api/models/user.dart';

class PrivacyProtectScreen extends StatefulWidget {
  const PrivacyProtectScreen({super.key});

  @override
  State<PrivacyProtectScreen> createState() => _PrivacyProtectScreenState();
}

class _PrivacyProtectScreenState extends State<PrivacyProtectScreen> {
  bool _isContactSyncEnabled = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userController = context.read<UserController>();
      final user = userController.currentUser;
      if (user != null) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      debugPrint('사용자 데이터 로드 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '개인정보 보호',
              style: TextStyle(
                color: Color(0xFFF8F8F8),
                fontSize: 20.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          children: [
            SizedBox(height: 29.h),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/blocked_friends');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1C1C1E),
                overlayColor: Color(0xffffffff).withValues(alpha: 0.1),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: SizedBox(
                width: 358.w,
                height: 62,
                child: Row(
                  children: [
                    SizedBox(width: 16.w),
                    SizedBox(
                      width: 32,
                      child: Icon(
                        Icons.block_flipped,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 25.w),
                    Text(
                      '차단된 사용자',
                      style: TextStyle(
                        color: const Color(0xFFF8F8F8),
                        fontSize: 17.sp,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 13.h),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isContactSyncEnabled = !_isContactSyncEnabled;
                });
              },
              child: Container(
                width: 358.w,
                height: 62,
                decoration: BoxDecoration(
                  color: Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 16.w),
                    SizedBox(
                      width: 32,
                      child: Image.asset(
                        "assets/contact.png",
                        width: 27.w,
                        height: 27.h,
                      ),
                    ),
                    SizedBox(width: 25.w),
                    Text(
                      '연락처 동기화',
                      style: TextStyle(
                        color: const Color(0xFFF8F8F8),
                        fontSize: 17.sp,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Spacer(),
                    _profileSwitch(_isContactSyncEnabled),
                    SizedBox(width: 16.w),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileSwitch(bool isEnabled) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 50.w,
      height: 26.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13.r),
        color: isEnabled ? const Color(0xffffffff) : const Color(0xff5a5a5a),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: isEnabled ? Alignment.centerRight : Alignment.centerLeft,
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
}
