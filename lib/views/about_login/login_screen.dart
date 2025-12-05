import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/user_controller.dart' as api;
import 'package:solar_icons/solar_icons.dart';
import '../../theme/theme.dart';
import 'widgets/common/continue_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final PageController _pageController = PageController();

  // REST API 서비스
  api.UserController? _apiUserController;

  // 전화번호 입력 컨트롤러
  final TextEditingController _phoneController = TextEditingController();

  // 인증번호 입력 컨트롤러
  final TextEditingController _codeController = TextEditingController();

  // 전화번호 입력 상태
  final ValueNotifier<bool> _hasPhone = ValueNotifier<bool>(false);

  // 인증번호 입력 상태
  final ValueNotifier<bool> _hasCode = ValueNotifier<bool>(false);

  String phoneNumber = '';

  // 현재 페이지 인덱스
  int currentPage = 0;

  // 로딩 상태
  bool _isSendingCode = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider에서 UserController 가져오기
    _apiUserController ??= Provider.of<api.UserController>(
      context,
      listen: false,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    _hasPhone.dispose();
    _hasCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!mounted) return Container();

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      resizeToAvoidBottomInset: false,
      body: PageView(
        controller: _pageController,
        physics: NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            currentPage = index;
          });
        },
        children: [_buildPhoneNumberPage(), _buildSmsCodePage()],
      ),
    );
  }

  // -------------------------
  // 1. 전화번호 입력 페이지
  // -------------------------
  Widget _buildPhoneNumberPage() {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        // 뒤로가기 버튼
        Positioned(
          top: 60.h,
          left: 20.w,
          child: IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
        ),

        // 입력 필드
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
                        controller: _phoneController,
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
                          _hasPhone.value = value.isNotEmpty;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 계속하기 버튼
        Positioned(
          bottom: keyboardHeight > 0 ? keyboardHeight + 20.h : 50.h,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: _hasPhone,
            builder: (context, hasPhoneValue, child) {
              return ContinueButton(
                isEnabled: hasPhoneValue && !_isSendingCode,
                text: _isSendingCode ? '전송 중...' : '계속하기',
                onPressed: () => _sendSmsCode(),
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
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        // 뒤로가기 버튼
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

        // 입력 필드
        Positioned(
          top: 0.35.sh,
          left: 0,
          right: 0,
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
                  controller: _codeController,
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
                    // 6자리 이상 입력 시 버튼 활성화
                    _hasCode.value = value.length >= 6;
                  },
                ),
              ),

              // 인증번호 다시 받기
              TextButton(
                onPressed: () => _resendSmsCode(),
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

        // 계속하기 버튼
        Positioned(
          bottom: keyboardHeight > 0 ? keyboardHeight + 20.h : 50.h,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: _hasCode,
            builder: (context, hasCodeValue, child) {
              return ContinueButton(
                isEnabled: hasCodeValue && !_isVerifying,
                text: _isVerifying ? '인증 중...' : '계속하기',
                onPressed: () => _verifyAndLogin(),
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------------
  // 전화번호 정규화
  // -------------------------
  /// "010-6784-1110" → "1067841110"
  /// "+82-10-6784-1110" → "1067841110"
  String _normalizePhoneNumber(String phone) {
    // 숫자만 추출
    String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // +82 국가번호로 시작하면 82 제거
    if (digits.startsWith('82')) {
      digits = digits.substring(2);
    }

    // 맨 앞의 0 제거 (010 → 10)
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    return digits;
  }

  // -------------------------
  // SMS 인증번호 발송
  // -------------------------
  Future<void> _sendSmsCode() async {
    if (_isSendingCode) return;

    setState(() {
      _isSendingCode = true;
    });

    // 전화번호 정규화 후 저장
    phoneNumber = _normalizePhoneNumber(_phoneController.text);

    try {
      final success = await _apiUserController!.requestSmsVerification(
        phoneNumber,
      );

      if (success) {
        debugPrint('SMS 인증번호 발송 성공');
        _goToNextPage();
      } else {
        _showErrorSnackBar('인증번호 발송에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('SMS 발송 오류: $e');
      _showErrorSnackBar('인증번호 발송 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  // -------------------------
  // SMS 인증번호 재발송
  // -------------------------
  Future<void> _resendSmsCode() async {
    try {
      final success = await _apiUserController!.requestSmsVerification(
        phoneNumber,
      );

      if (success) {
        _showSnackBar('인증번호가 재전송되었습니다.');
      } else {
        _showErrorSnackBar('인증번호 재전송에 실패했습니다.');
      }
    } catch (e) {
      debugPrint('SMS 재발송 오류: $e');
      _showErrorSnackBar('인증번호 재전송 중 오류가 발생했습니다.');
    }
  }

  // -------------------------
  // 인증 및 로그인
  // -------------------------
  Future<void> _verifyAndLogin() async {
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
    });

    final code = _codeController.text;

    try {
      // 1. SMS 코드 인증 확인
      final isValid = await _apiUserController!.verifySmsCode(
        phoneNumber,
        code,
      );

      if (!isValid) {
        _showErrorSnackBar('인증번호가 올바르지 않습니다.');
        return;
      }

      debugPrint('SMS 인증 성공');

      // 2. 로그인 시도
      debugPrint("로그인 시도: $phoneNumber");
      final user = await _apiUserController!.login(phoneNumber);

      if (user != null) {
        // 기존 회원 - 홈으로 이동
        debugPrint('로그인 성공: \${user.userId}');
        _goHomePage();
      } else {
        // 신규 회원 - 회원가입 페이지로 이동
        debugPrint('신규 회원 - 회원가입 필요');
        if (mounted) {
          Navigator.pushNamed(context, '/auth');
        }
      }
    } catch (e) {
      debugPrint('인증/로그인 오류: $e');
      _showErrorSnackBar('인증에 실패했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  // -------------------------
  // 유틸리티 메서드
  // -------------------------
  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goHomePage() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home_navigation_screen',
      (route) => false,
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}
