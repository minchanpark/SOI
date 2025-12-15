import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../api_firebase/controllers/auth_controller.dart';

/// 사용자 이름 표시 위젯 - AuthController의 getUserInfo를 통해 실제 name 필드 조회
/// 단일 책임: 사용자 이름 표시
class UserDisplayName extends StatelessWidget {
  final String userId;
  const UserDisplayName({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthController>(
      builder: (context, authController, _) {
        return FutureBuilder<String>(
          future: _getUserDisplayId(authController, userId),
          builder: (context, snapshot) {
            final displayName = snapshot.data ?? userId; // fallback to userId
            return Text(
              displayName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
                letterSpacing: -0.40,
              ),
            );
          },
        );
      },
    );
  }

  /// AuthController를 통해 실제 사용자 name 조회
  Future<String> _getUserDisplayId(
    AuthController authController,
    String userId,
  ) async {
    try {
      final userId = await authController.getUserID();

      return userId; // 최종 fallback
    } catch (e) {
      return userId; // 에러 시 userId 그대로 반환
    }
  }
}
