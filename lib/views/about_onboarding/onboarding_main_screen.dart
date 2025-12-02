import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/api_media_controller.dart';
import 'package:soi/api/controller/api_user_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../api_firebase/controllers/auth_controller.dart';

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

  final ApiUserController _apiUserController = ApiUserController();
  final ApiMediaController _apiMediaController = ApiMediaController();

  String? profileImageKey;

  final List<_OnboardingContent> _contents = const [
    _OnboardingContent(
      message: '카메라로 지금 이 순간을 포착하고,\n감정을 담을 준비를 해요.',
      image: 'assets/onboarding1.png',
    ),
    _OnboardingContent(
      message: '찍은 사진 위에 음성을 녹음해 기록하고,\n원하는 카테고리로 바로 보낼 수 있어요.',
      image: 'assets/onboarding2.png',
    ),
    _OnboardingContent(
      message: '전체, 공유 기록, 나의 기록을 볼 수 있고,\n카테고리 안에 모아둘 수 있어요.',
      image: 'assets/onboarding3.png',
    ),
    _OnboardingContent(
      message: '친구들의 기록을 들어보세요.\n친구들의 사진과 목소리를 하나씩 감상해요.',
      image: 'assets/onboarding4.png',
    ),
    _OnboardingContent(
      message: '친구들의 재밌는 음성 댓글을 듣고\n직접 음성 댓글을 남겨보세요!',
      image: 'assets/onboarding5.png',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoadedArguments) {
      _registrationData =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _hasLoadedArguments = true;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _apiUserController.dispose();
    super.dispose();
  }

  /// 계속하기나 건너뛰기 버튼 눌렀을 때 호출
  /// 가입정보를 서버에 저장함.
  Future<void> _completeOnboarding() async {
    if (_isCompleting) return;

    final registration = _registrationData;
    final authController = Provider.of<AuthController>(context, listen: false);
    final user = authController.currentUser;

    if (registration == null || user == null) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home_navigation_screen',
        (route) => false,
      );
      return;
    }

    final String id = (registration['id'] as String?) ?? '';
    final String name = (registration['name'] as String?) ?? '';
    final String phone = (registration['phone'] as String?) ?? '';
    final String birthDate = (registration['birthDate'] as String?) ?? '';
    final MultipartFile profileImagePath = registration['profileImagePath'];

    setState(() {
      _isCompleting = true;
    });

    try {
      profileImageKey = await _apiMediaController.uploadProfileImage(
        file: profileImagePath,
        userId: _apiUserController.currentUser!.id,
      );

      await _apiUserController.createUser(
        name: name,
        userId: id,
        phoneNum: phone,
        birthDate: birthDate,
        profileImageKey: profileImageKey,
      );

      await _apiUserController.saveLoginState(
        userId: _apiUserController.currentUser!.id,
        phoneNumber: phone,
      );
    } catch (e) {
      debugPrint('Failed to finalize onboarding: $e');
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
        actions: [
          (_currentPage == 4)
              ? SizedBox()
              : Padding(
                  padding: EdgeInsets.only(top: 20.h),
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      '건너뛰기 >',
                      style: TextStyle(
                        color: const Color(0xFFCBCBCB),
                        fontSize: 16.sp,
                        fontFamily: GoogleFonts.inter().fontFamily,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
        ],
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
                    content.message,
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
          (_currentPage == 4)
              ? Positioned(
                  bottom: 40.h,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26.9),
                      ),
                    ),
                    onPressed: _completeOnboarding,
                    child: Container(
                      width: 349.w,
                      height: 59.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26.9),
                      ),
                      child: Text(
                        "계속하기",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20.sp,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
              : SizedBox(),
        ],
      ),
    );
  }
}

class _OnboardingContent {
  final String message;
  final String image;

  const _OnboardingContent({required this.message, required this.image});
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
