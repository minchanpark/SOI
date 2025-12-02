import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../api/controller/api_user_controller.dart';
import '../../theme/theme.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with TickerProviderStateMixin {
  bool _isCheckingAutoLogin = true;
  bool _homeNavigationScheduled = false;

  // 애니메이션 컨트롤러들
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _buttonController;

  // 애니메이션들
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _buttonOpacity;
  late Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkAutoLogin();
  }

  /// 애니메이션 초기화
  void _initializeAnimations() {
    // 애니메이션 컨트롤러 생성
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _textController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // 애니메이션 정의
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );
    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
        );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    _buttonOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
    _buttonSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _buttonController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  /// 순차적 애니메이션 시작
  void _startAnimations() async {
    // 500ms 대기 후 로고 애니메이션
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) _logoController.forward();

    // 로고 애니메이션 완료 후 텍스트 애니메이션
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) _textController.forward();

    // 텍스트 애니메이션 완료 후 버튼 애니메이션
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) _buttonController.forward();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  /// 자동 로그인 체크
  Future<void> _checkAutoLogin() async {
    try {
      final userController = Provider.of<ApiUserController>(
        context,
        listen: false,
      );
      final canAutoLogin = await userController.tryAutoLogin();

      if (mounted) {
        if (canAutoLogin) {
          await _navigateToHome();
        } else {
          setState(() {
            _isCheckingAutoLogin = false;
          });
          // 애니메이션 시작
          _startAnimations();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingAutoLogin = false;
        });
        // 애니메이션 시작
        _startAnimations();
      }
    }
  }

  Future<void> _navigateToHome() async {
    if (!mounted || _homeNavigationScheduled) {
      return;
    }

    _homeNavigationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.pushReplacementNamed(context, '/home_navigation_screen');
    });
  }

  @override
  Widget build(BuildContext context) {
    // 자동 로그인 체크 중일 때 로딩 화면 표시
    if (_isCheckingAutoLogin) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        body: Center(
          child: AnimatedBuilder(
            animation: _logoController,
            builder: (context, child) {
              return SlideTransition(
                position: _logoSlide,
                child: FadeTransition(
                  opacity: _logoOpacity,
                  child: Image.asset(
                    'assets/SOI_logo.png',
                    width: 126.w,
                    height: 88.h,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(height: 170.h),
              // 로고 애니메이션
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _logoSlide,
                    child: FadeTransition(
                      opacity: _logoOpacity,
                      child: Image.asset(
                        'assets/SOI_logo.png',
                        width: 126.w,
                        height: 88.h,
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 38.h),
              // 텍스트 애니메이션
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textOpacity,
                      child: _buildSubText(),
                    ),
                  );
                },
              ),
              SizedBox(height: 257.h),
              // 버튼 애니메이션
              AnimatedBuilder(
                animation: _buttonController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _buttonSlide,
                    child: FadeTransition(
                      opacity: _buttonOpacity,
                      child: _buildButtons(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubText() {
    return Text(
      'SOI에 오신걸 환영합니다!',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: const Color(0xFFF8F8F8),
        fontSize: 20,
        fontFamily: 'Pretendard Variable',
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/auth');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xffffffff),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17.8),
            ),
          ),
          child: Container(
            width: 239.w,
            height: 59.h,
            alignment: Alignment.center,
            child: Text(
              '회원가입',
              style: TextStyle(
                color: Colors.black,
                fontSize: 22.sp,
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        SizedBox(height: 19.w),
        ElevatedButton(
          onPressed: () {
            // 로그인 기록 체크 후 분기 처리
            Navigator.pushNamed(context, '/login');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xff171717),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17.8),
            ),
          ),
          child: Container(
            width: 239.w,
            height: 59.h,
            alignment: Alignment.center,
            child: Text(
              '로그인',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22.sp,
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
