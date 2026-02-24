import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/utils/snackbar_utils.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:soi/views/home_navigator_screen.dart';
import '../../theme/theme.dart';

/// 회원가입 완료 화면
class AuthFinalScreen extends StatefulWidget {
  final String? id;
  final String? name;
  final String? phone;
  final String? birthDate;
  final String? profileImagePath; // 프로필 이미지 경로 추가
  final bool? agreeServiceTerms;
  final bool? agreePrivacyTerms;
  final bool? agreeMarketingInfo;

  const AuthFinalScreen({
    super.key,
    this.id,
    this.name,
    this.phone,
    this.birthDate,
    this.profileImagePath,
    this.agreeServiceTerms,
    this.agreePrivacyTerms,
    this.agreeMarketingInfo,
  });

  @override
  State<AuthFinalScreen> createState() => _AuthFinalScreenState();
}

class _AuthFinalScreenState extends State<AuthFinalScreen> {
  bool _isCompleting = false;

  /// 회원가입 처리
  Future<void> _completeRegistration() async {
    if (_isCompleting) return;

    // Navigator arguments에서 사용자 정보 가져오기
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    // 생성자 파라미터 또는 arguments에서 사용자 정보 결정
    final String nickName = widget.id ?? arguments?['id'] ?? '';
    final String name = widget.name ?? arguments?['name'] ?? '';
    final String phone = widget.phone ?? arguments?['phone'] ?? '';
    final String birthDate = widget.birthDate ?? arguments?['birthDate'] ?? '';
    final String? profileImagePath =
        widget.profileImagePath ?? (arguments?['profileImagePath'] as String?);

    // 필수 데이터 확인
    if (nickName.isEmpty || name.isEmpty) {
      if (mounted) {
        SnackBarUtils.showSnackBar(context, '회원가입 정보가 올바르지 않습니다.');
      }
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    try {
      // Provider를 통해 컨트롤러 가져오기
      final apiUserController = Provider.of<UserController>(
        context,
        listen: false,
      );
      final apiMediaController = Provider.of<MediaController>(
        context,
        listen: false,
      );

      // 1. 사용자 먼저 생성 (프로필 이미지 없이)
      final createdUser = await apiUserController.createUser(
        name: name,
        nickName: nickName,
        phoneNum: phone,
        birthDate: birthDate,
      );

      if (createdUser == null) {
        debugPrint('[AuthFinalScreen] 사용자 생성 실패');
        if (mounted) {
          SnackBarUtils.showSnackBar(context, '회원가입에 실패했습니다.');
          setState(() {
            _isCompleting = false;
          });
        }
        return;
      }

      // 생성된 사용자를 현재 사용자로 설정 (Provider 상태 업데이트)
      apiUserController.setCurrentUser(createdUser);

      // 2. 프로필 이미지가 있으면 업로드 후 사용자 업데이트
      if (profileImagePath != null && profileImagePath.isNotEmpty) {
        final imageFile = File(profileImagePath);
        if (await imageFile.exists()) {
          // 파일을 MultipartFile로 변환 (서버는 'files' 필드명 기대)
          final multipartFile = await apiMediaController.fileToMultipart(
            imageFile,
            fieldName: 'files',
          );

          final profileImageKey = await apiMediaController.uploadProfileImage(
            file: multipartFile,
            userId: createdUser.id,
          );

          // 3. 프로필 이미지 키로 사용자 정보 업데이트
          if (profileImageKey != null) {
            await apiUserController.updateprofileImageUrl(
              userId: createdUser.id,
              profileImageKey: profileImageKey,
            );
          }
        } else {
          debugPrint('[AuthFinalScreen] 프로필 이미지 파일 없음: $profileImagePath');
        }
      }

      // 4. 로그인 상태 저장
      await apiUserController.saveLoginState(
        userId: createdUser.id,
        phoneNumber: phone,
      );

      if (!mounted) return;

      // 5. 온보딩 화면으로 이동 (데이터 없이 - 이미 회원가입 완료됨)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const HomePageNavigationBar(currentPageIndex: 1),
        ),
        (route) => false,
      );
    } catch (e) {
      debugPrint('[AuthFinalScreen] 회원가입 실패: $e');
      if (mounted) {
        SnackBarUtils.showSnackBar(context, '회원가입 중 오류가 발생했습니다.');
        setState(() {
          _isCompleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    tr('register.complete_title', context: context),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8),
                      fontSize: 20,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 17.9.h),
                  Text(
                    tr('register.complete_description', context: context),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8),
                      fontSize: 16,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w600,
                      height: 1.61,
                      letterSpacing: 0.32,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // "계속하기" 버튼
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom + 20.h
                  : 30.h,
              left: 22.w,
              right: 22.w,
            ),
            child: ElevatedButton(
              onPressed: _isCompleting ? null : _completeRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffffffff),
                disabledBackgroundColor: const Color(0xff888888),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26.90),
                ),
              ),
              child: Container(
                width: 349.w,
                height: 59.h,
                alignment: Alignment.center,
                child: _isCompleting
                    ? SizedBox(
                        width: 24.w,
                        height: 24.w,
                        child: const CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        tr('common.continue', context: context),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20.sp,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
