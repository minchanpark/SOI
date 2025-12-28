import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:soi/views/about_onboarding/onboarding_main_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/theme.dart';

/// 회원가입 완료 화면
class AuthFinalScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Navigator arguments에서 사용자 정보 가져오기
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    // 생성자 파라미터 또는 arguments에서 사용자 정보 결정
    final String finalId = id ?? arguments?['id'] ?? '';
    final String finalName = name ?? arguments?['name'] ?? '';
    final String finalPhone = phone ?? arguments?['phone'] ?? '';
    final String finalBirthDate = birthDate ?? arguments?['birthDate'] ?? '';
    final String? finalProfileImagePath =
        profileImagePath ?? (arguments?['profileImagePath'] as String?);
    final bool finalAgreeServiceTerms =
        agreeServiceTerms ?? arguments?['agreeServiceTerms'] ?? false;
    final bool finalAgreePrivacyTerms =
        agreePrivacyTerms ?? arguments?['agreePrivacyTerms'] ?? false;
    final bool finalAgreeMarketingInfo =
        agreeMarketingInfo ?? arguments?['agreeMarketingInfo'] ?? false;
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
          // 버튼을 하단에 고정 위치
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom + 20.h
                  : 30.h,
              left: 22.w,
              right: 22.w,
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OnboardingMainScreen(
                      id: finalId,
                      name: finalName,
                      phone: finalPhone,
                      birthDate: finalBirthDate,
                      profileImagePath: finalProfileImagePath,
                      agreeServiceTerms: finalAgreeServiceTerms,
                      agreePrivacyTerms: finalAgreePrivacyTerms,
                      agreeMarketingInfo: finalAgreeMarketingInfo,
                    ),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xffffffff),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26.90),
                ),
              ),
              child: Container(
                width: 349.w,
                height: 59.h,
                alignment: Alignment.center,
                child: Text(
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
