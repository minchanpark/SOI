import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/theme.dart';

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
                    '회원가입이 완료되었습니다. ',
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
                    '이제부터 SOI의 모든 기능을 자유롭게 \n이용하실 수 있습니다.',
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
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/onboarding',
                  (route) => false,
                  arguments: {
                    'id': finalId,
                    'name': finalName,
                    'phone': finalPhone,
                    'birthDate': finalBirthDate,
                    'profileImagePath': finalProfileImagePath,
                    'agreeServiceTerms': finalAgreeServiceTerms,
                    'agreePrivacyTerms': finalAgreePrivacyTerms,
                    'agreeMarketingInfo': finalAgreeMarketingInfo,
                  },
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
                  '계속하기',
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
