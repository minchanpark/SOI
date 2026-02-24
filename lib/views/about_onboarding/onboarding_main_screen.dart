import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/controller/user_controller.dart';

/// 온보딩 메인 스크린
/// 온보딩 화면들을 페이지 뷰로 보여주고,
/// 마지막에 가입 완료 후 홈 화면으로 이동합니다.
class OnboardingMainScreen extends StatefulWidget {
  final String? id;
  final String? name;
  final String? phone;
  final String? birthDate;
  final String? profileImagePath;
  final bool? agreeServiceTerms;
  final bool? agreePrivacyTerms;
  final bool? agreeMarketingInfo;

  const OnboardingMainScreen({
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
  State<OnboardingMainScreen> createState() => _OnboardingMainScreenState();
}

class _OnboardingMainScreenState extends State<OnboardingMainScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Map<String, dynamic>? _registrationData;
  bool _hasLoadedArguments = false;
  bool _isCompleting = false;

  // Provider를 통해 가져올 컨트롤러 (late 초기화)
  late UserController _apiUserController;
  late MediaController _apiMediaController;

  String? profileImageKey;

  static const List<_OnboardingContent> _contents = [
    _OnboardingContent(
      messageKey: 'onboarding.message_1',
      image: 'assets/onboarding1.png',
    ),
    _OnboardingContent(
      messageKey: 'onboarding.message_2',
      image: 'assets/onboarding2.png',
    ),
    _OnboardingContent(
      messageKey: 'onboarding.message_3',
      image: 'assets/onboarding3.png',
    ),
    _OnboardingContent(
      messageKey: 'onboarding.message_4',
      image: 'assets/onboarding4.png',
    ),
    _OnboardingContent(
      messageKey: 'onboarding.message_5',
      image: 'assets/onboarding5.png',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Provider를 통해 전역 UserController 가져오기
    _apiUserController = Provider.of<UserController>(context, listen: false);
    _apiMediaController = Provider.of<MediaController>(context, listen: false);

    if (!_hasLoadedArguments) {
      // 1. 먼저 ModalRoute arguments에서 데이터 확인
      _registrationData =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      // 2. arguments가 없으면 생성자 파라미터에서 데이터 구성
      if (_registrationData == null && widget.id != null) {
        _registrationData = {
          'nickName': widget.id,
          'name': widget.name,
          'phone': widget.phone,
          'birthDate': widget.birthDate,
          'profileImagePath': widget.profileImagePath,
          'agreeServiceTerms': widget.agreeServiceTerms,
          'agreePrivacyTerms': widget.agreePrivacyTerms,
          'agreeMarketingInfo': widget.agreeMarketingInfo,
        };
        debugPrint(
          '[OnboardingMainScreen] 생성자 파라미터에서 데이터 로드: $_registrationData',
        );
      }

      _hasLoadedArguments = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    // _apiUserController는 Provider가 관리하므로 dispose하지 않음
    super.dispose();
  }

  /// 계속하기나 건너뛰기 버튼 눌렀을 때 호출
  /// 가입정보를 서버에 저장함.
  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;

    final registration = _registrationData;

    // registration 데이터가 없으면 홈으로 이동 (이미 가입된 사용자일 수 있음)
    if (registration == null) {
      debugPrint('[OnboardingMainScreen] 회원가입 데이터 없음, 홈 화면으로 이동');
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home_navigation_screen',
        (route) => false,
      );
      return;
    }

    final String nickName = (registration['nickName'] as String?) ?? '';
    final String name = (registration['name'] as String?) ?? '';
    final String phone = (registration['phone'] as String?) ?? '';
    final String birthDate = (registration['birthDate'] as String?) ?? '';
    final String? profileImagePath =
        registration['profileImagePath'] as String?;

    // 필수 데이터 확인
    if (nickName.isEmpty || name.isEmpty) {
      debugPrint(
        '[OnboardingMainScreen] 필수 데이터 누락: nickName=$nickName, name=$name, phone=$phone',
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home_navigation_screen',
        (route) => false,
      );
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    debugPrint(
      '[OnboardingMainScreen] 회원가입 시작: nickName=$nickName, name=$name, phone=$phone',
    );

    try {
      // 1. 사용자 먼저 생성 (프로필 이미지 없이)
      final createdUser = await _apiUserController.createUser(
        name: name,
        nickName: nickName,
        phoneNum: phone,
        birthDate: birthDate,
      );

      if (createdUser == null) {
        debugPrint('[OnboardingMainScreen] 사용자 생성 실패');
        setState(() {
          _isCompleting = false;
        });
        return;
      }

      debugPrint('[OnboardingMainScreen] 사용자 생성 성공: userId=${createdUser.id}');

      // 생성된 사용자를 현재 사용자로 설정 (Provider 상태 업데이트)
      _apiUserController.setCurrentUser(createdUser);

      // 2. 프로필 이미지가 있으면 업로드 후 사용자 업데이트
      if (profileImagePath != null && profileImagePath.isNotEmpty) {
        final imageFile = File(profileImagePath);
        if (await imageFile.exists()) {
          debugPrint(
            '[OnboardingMainScreen] 프로필 이미지 업로드 시작: $profileImagePath',
          );

          // 파일을 MultipartFile로 변환 (서버는 'files' 필드명 기대)
          final multipartFile = await _apiMediaController.fileToMultipart(
            imageFile,
            fieldName: 'files',
          );

          profileImageKey = await _apiMediaController.uploadProfileImage(
            file: multipartFile,
            userId: createdUser.id,
          );

          // 3. 프로필 이미지 키로 사용자 정보 업데이트
          if (profileImageKey != null) {
            await _apiUserController.updateprofileImageUrl(
              userId: createdUser.id,
              profileImageKey: profileImageKey!,
            );
            debugPrint(
              '[OnboardingMainScreen] 프로필 이미지 업데이트 완료: $profileImageKey',
            );
          }
        } else {
          debugPrint('[OnboardingMainScreen] 프로필 이미지 파일 없음: $profileImagePath');
        }
      }

      // 4. 로그인 상태 저장
      await _apiUserController.saveLoginState(
        userId: createdUser.id,
        phoneNumber: phone,
      );

      debugPrint('[OnboardingMainScreen] 회원가입 완료, 홈 화면으로 이동');
    } catch (e) {
      debugPrint('[OnboardingMainScreen] 회원가입 실패: $e');
      setState(() {
        _isCompleting = false;
      });
      return;
    }

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home_navigation_screen',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'SOI',
          style: TextStyle(
            color: const Color(0xFFF8F8F8),
            fontSize: 20.sp,
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [],
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _contents.length,
            itemBuilder: (context, index) {
              final content = _contents[index];
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tr(content.messageKey, context: context),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 29.h),
                  Image.asset(content.image, width: 203.w, height: 400.w),
                  SizedBox(height: 80.h),
                ],
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 150.h,
            child: _PageIndicator(
              pageCount: _contents.length,
              currentIndex: _currentPage,
            ),
          ),
          Positioned(
            bottom: 40.h,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26.9),
                ),
              ),
              onPressed: () {
                if (_currentPage == _contents.length - 1) {
                  _completeOnboarding();
                } else {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: Container(
                width: 349.w,
                height: 59.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26.9),
                ),
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

class _OnboardingContent {
  final String messageKey;
  final String image;

  const _OnboardingContent({required this.messageKey, required this.image});
}

class _PageIndicator extends StatelessWidget {
  final int pageCount;
  final int currentIndex;

  const _PageIndicator({required this.pageCount, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final bool isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: EdgeInsets.symmetric(horizontal: 6.w),
          width: isActive ? 16.w : 8.w,
          height: 8.w,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white24,
            borderRadius: BorderRadius.circular(8.r),
          ),
        );
      }),
    );
  }
}
