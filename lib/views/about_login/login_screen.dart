import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:provider/provider.dart';
import '../../api_firebase/controllers/auth_controller.dart';
import '../../theme/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final PageController _pageController = PageController();
  late AuthController _authController;

  String phoneNumber = '';
  String smsCode = '';

  // 현재 페이지 인덱스
  int currentPage = 0;

  // 사용자가 존재하는지 여부 및 상태 관리
  bool userExists = false;
  bool isVerified = false;
  bool isCheckingUser = false;

  // 인증번호 입력 상태를 관리하는 ValueNotifier
  final ValueNotifier<bool> hasCode = ValueNotifier<bool>(false);

  // 인증번호 입력 컨트롤러
  final TextEditingController controller = TextEditingController();

  // 자동 인증을 위한 Timer
  Timer? _autoVerifyTimer;

  @override
  void initState() {
    super.initState();
    // Provider에서 AuthController를 가져오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _authController = Provider.of<AuthController>(context, listen: false);
      });
    });
    // debugPrint('AuthController 초기화 완료');
  }

  @override
  void dispose() {
    _pageController.dispose();
    hasCode.dispose();
    controller.dispose();
    _autoVerifyTimer?.cancel(); // Timer 정리
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Provider에서 AuthViewModel을 가져옴
    if (!mounted) return Container(); // 안전 검사

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      resizeToAvoidBottomInset: false, // 키보드가 올라와도 화면 크기 변경 안함

      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(), // 스와이프로 페이지 전환 비활성화
        onPageChanged: (index) {
          setState(() {
            currentPage = index;
          });
        },
        children: [
          // 1. 전화번호 입력 페이지
          _buildPhoneNumberPage(),
          // 2. 인증번호 입력 페이지
          _buildSmsCodePage(),
        ],
      ),
    );
  }

  // -------------------------
  // 1. 전화번호 입력 페이지
  // -------------------------
  Widget _buildPhoneNumberPage() {
    final controller = TextEditingController();
    // 전화번호 입력 여부를 확인하는 상태 변수
    final ValueNotifier<bool> hasPhone = ValueNotifier<bool>(false);

    // 키보드 높이는 버튼 위치에만 사용
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        Positioned(
          top: 60.h,
          left: 20.w,
          child: IconButton(
            onPressed: () {
              Navigator.of(context).maybePop();
            },
            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
        ),
        // 입력 필드들을 화면 중앙에 고정
        Positioned(
          top: 0.35.sh,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                'SOI 접속을 위해 전화번호를 입력해주세요.',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 18,
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              Container(
                width: 239.w,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(0xff323232),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(width: 17.w),
                    Icon(
                      SolarIconsOutline.phone,
                      color: const Color(0xffC0C0C0),
                      size: 24.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.phone,
                        textAlign: TextAlign.start,
                        cursorHeight: 16.h,
                        cursorColor: const Color(0xFFF8F8F8),
                        style: TextStyle(
                          color: const Color(0xFFF8F8F8),
                          fontSize: 16,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.08,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: '전화번호',
                          hintStyle: TextStyle(
                            color: const Color(0xFFC0C0C0),
                            fontSize: 16.sp,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w400,
                          ),
                          contentPadding: EdgeInsets.only(
                            left: 15.w,
                            bottom: 5.h,
                          ),
                        ),
                        onChanged: (value) {
                          // 전화번호 입력 여부에 따라 버튼 표시 상태 변경
                          hasPhone.value = value.isNotEmpty;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 버튼을 하단에 위치 (키보드 높이에 따라 조정)
        Positioned(
          bottom: keyboardHeight > 0 ? keyboardHeight + 20.h : 50.h,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: hasPhone,
            builder: (context, hasPhoneValue, child) {
              return Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xffffffff),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26.9),
                    ),
                  ),
                  onPressed: () {
                    // 전화번호 저장
                    phoneNumber = controller.text;
                    // 인증번호 받기 로직 실행
                    _authController.verifyPhoneNumber(
                      phoneNumber,
                      (verificationId, resendToken) {
                        // 성공적으로 인증번호 전송되면 다음 페이지로
                        _goToNextPage();
                      },
                      (verificationId) {
                        // 타임아웃 등 처리
                      },
                    );
                  },
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
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------------
  // 2. 인증번호 입력 페이지
  // -------------------------
  Widget _buildSmsCodePage() {
    final ValueNotifier<bool> hasCode = ValueNotifier<bool>(false);
    final controller = TextEditingController();

    return Stack(
      children: [
        Positioned(
          top: 60.h,
          left: 20.w,
          child: IconButton(
            onPressed: () {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '인증번호를 입력해주세요.',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 18,
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              Container(
                width: 239.w,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(0xff323232),
                  borderRadius: BorderRadius.circular(16.5),
                ),
                padding: EdgeInsets.only(bottom: 7.h),
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  cursorColor: const Color(0xFFF8F8F8),
                  style: TextStyle(
                    color: const Color(0xFFF8F8F8),
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.08,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: '인증번호',
                    hintStyle: TextStyle(
                      color: const Color(0xFFCBCBCB),
                      fontSize: 16,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  onChanged: (value) {
                    // 인증번호 입력 여부에 따라 상태 변경
                    hasCode.value = value.isNotEmpty;

                    // 인증 완료 후, 사용자가 인증번호를 변경하면 상태 초기화
                    if (isVerified) {
                      setState(() {
                        isVerified = false;
                      });
                    }

                    // 기존 타이머 취소
                    _autoVerifyTimer?.cancel();

                    // 인증번호가 입력되면 2초 후 자동 인증 시작
                    if (value.isNotEmpty && value.length >= 6) {
                      _autoVerifyTimer = Timer(Duration(seconds: 2), () {
                        _performAutoVerification(value);
                      });
                    }
                  },
                ),
              ),

              // Updated the TextButton to use a custom underline implementation
              TextButton(
                onPressed: () {
                  // 인증번호 재전송 로직
                  _authController.verifyPhoneNumber(phoneNumber, (
                    verificationId,
                    resendToken,
                  ) {
                    // 재전송 성공 시 처리
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('인증번호가 재전송되었습니다.')));
                  }, (verificationId) {});
                },
                child: RichText(
                  text: TextSpan(
                    text: '인증번호 다시 받기',
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8),
                      fontSize: 12,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w500,

                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 자동 인증 수행 함수
  void _performAutoVerification(String code) async {
    if (isCheckingUser) return; // 이미 인증 중이면 중복 실행 방지

    setState(() {
      isCheckingUser = true;
    });

    // SMS 코드 저장
    smsCode = code;

    try {
      // SMS 코드로 로그인 시도
      await _authController.signInWithSmsCode(smsCode, () async {
        // 인증 성공 후, 사용자 정보 확인
        final currentUser = _authController.currentUser;

        if (currentUser != null) {
          // 사용자 정보가 Firestore에 있는지 확인 (기존 사용자인지 확인)
          final userInfo = await _authController.getUserInfo(currentUser.uid);
          final userExists = userInfo != null;

          setState(() {
            isCheckingUser = false;
            isVerified = true;
            this.userExists = userExists;
          });

          if (userExists) {
            // ✅ 기존 사용자: 완전한 로그인 상태 저장
            await _authController.saveLoginState(
              userId: currentUser.uid,
              phoneNumber: phoneNumber,
            );

            // 홈 화면으로 이동
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home_navigation_screen',
              (route) => false,
            );
          } else {
            // 새로운 사용자: 회원가입 진행 상태만 저장 (signInWithSmsCodeAndSave 사용)
            _authController.signInWithSmsCodeAndSave(smsCode, phoneNumber, () {
              // UI 업데이트를 위해 setState 호출
              setState(() {});
            });
          }
        }
      });
    } catch (e) {
      setState(() {
        isCheckingUser = false;
      });
      // 에러 처리
      debugPrint('로그인 오류: $e');
    }
  }

  // -------------------------
  // 다음 페이지로 이동
  // -------------------------
  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
