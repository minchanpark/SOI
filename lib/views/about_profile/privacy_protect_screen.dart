import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../api_firebase/controllers/auth_controller.dart';
import '../../api_firebase/models/auth_model.dart';

class PrivacyProtectScreen extends StatefulWidget {
  const PrivacyProtectScreen({super.key});

  @override
  State<PrivacyProtectScreen> createState() => _PrivacyProtectScreenState();
}

class _PrivacyProtectScreenState extends State<PrivacyProtectScreen> {
  bool _isContactSyncEnabled = false;
  AuthModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final authController = context.read<AuthController>();
      final userId = authController.getUserId;
      if (userId != null) {
        final userInfo = await authController.getUserInfo(userId);
        setState(() {
          _currentUser = userInfo;
        });
      }
    } catch (e) {
      // 에러 처리
    }
  }

  void _showDeactivateBottomSheet(BuildContext context) {
    final isDeactivated = _currentUser?.isDeactivated ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          width: double.infinity,

          decoration: BoxDecoration(
            color: Color(0xFF2C2C2E),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25.3),
              topRight: Radius.circular(25.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상단 핸들
              SizedBox(height: 7.h),
              Container(
                width: 56.w,
                height: 3.h,
                decoration: ShapeDecoration(
                  color: const Color(0xFFCBCBCB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.80),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              // 제목
              Text(
                isDeactivated ? '계정 활성화' : '계정 비활성화',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 19.78,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16.h),
              // 설명 텍스트
              Text(
                isDeactivated
                    ? '계정을 활성화하면, 사용자가 올린 게시물이\n다시 공개됩니다.'
                    : '계정을 비활성화하면, 사용자가 올린 게시물은\n자동으로 비공개 처리됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 14.sp,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w400,
                  height: 1.51,
                ),
              ),
              SizedBox(height: 40.h),
              // 비활성화/활성화 버튼
              SizedBox(
                width: 344.w,
                height: 38,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    try {
                      final authController = context.read<AuthController>();
                      if (isDeactivated) {
                        await authController.activateAccount();
                      } else {
                        await authController.deactivateAccount();
                      }
                      // 사용자 데이터 다시 로드
                      await _loadUserData();
                    } catch (e) {
                      throw Exception('계정 상태 변경 중 오류 발생: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    overlayColor: Color(0xffffffff).withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                  child: Text(
                    isDeactivated ? '활성화' : '비활성화',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 17.78,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              // 취소 버튼
              SizedBox(
                width: 344.w,
                height: 38,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    overlayColor: Color(0xffffffff).withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                  child: Text(
                    '취소',
                    style: TextStyle(
                      color: const Color(0xFFCBCBCB),
                      fontSize: 17.78.sp,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        );
      },
    );
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
            ElevatedButton(
              onPressed: () {
                _showDeactivateBottomSheet(context);
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
                      child: Image.asset(
                        "assets/unactive_icon.png",
                        width: 26.w,
                        height: 26.h,
                      ),
                    ),
                    SizedBox(width: 25.w),
                    Text(
                      _currentUser?.isDeactivated == true
                          ? '계정 활성화'
                          : '계정 비활성화',
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
