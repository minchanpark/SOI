import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:soi/views/about_login/widgets/pages/agreement_page.dart';
import '../../api_firebase/controllers/auth_controller.dart';
import 'auth_final_screen.dart';
import 'widgets/common/continue_button.dart';
import 'widgets/pages/friend_add_and_share_page.dart';
import 'widgets/pages/name_input_page.dart';
import 'widgets/pages/birth_date_page.dart';
import 'widgets/pages/phone_input_page.dart';
import 'widgets/pages/select_profile_image_page.dart';
import 'widgets/pages/sms_code_page.dart';
import 'widgets/pages/id_input_page.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // 페이지 컨트롤러
  final PageController _pageController = PageController();

  // AuthController 인스턴스 late로 선언하고 나중에 초기화
  late final AuthController _authController;

  // 자동 인증을 위한 Timer
  Timer? _autoVerifyTimer;

  // 인증 상태 관리
  bool isVerified = false;
  bool isCheckingUser = false;

  // 입력 데이터
  String phoneNumber = '';
  String smsCode = '';
  String name = '';
  String birthDate = '';
  String id = '';
  String? profileImagePath;

  // 현재 페이지 인덱스
  int currentPage = 0;

  // 드롭다운에서 선택된 값
  String? selectedYear;
  String? selectedMonth;
  String? selectedDay;

  // 페이지별 입력 완료 여부
  late List<ValueNotifier<bool>> pageReady;

  // 공통 컨트롤러
  late TextEditingController nameController;
  late TextEditingController monthController;
  late TextEditingController dayController;
  late TextEditingController yearController;
  late TextEditingController phoneController;
  late TextEditingController smsController;
  late TextEditingController idController;

  // 중복 아이디 체크를 위한 변수
  String? idErrorMessage;
  Timer? debounceTimer;

  // 약관 동의 상태 변수들
  bool agreeAll = false;
  bool agreeServiceTerms = false;
  bool agreePrivacyTerms = false;
  bool agreeMarketingInfo = false;

  @override
  void initState() {
    super.initState();

    // AuthController 인스턴스 가져오기
    _authController = Provider.of<AuthController>(context, listen: false);

    // 컨트롤러 및 상태 초기화
    nameController = TextEditingController();
    monthController = TextEditingController();
    dayController = TextEditingController();
    yearController = TextEditingController();
    phoneController = TextEditingController();
    smsController = TextEditingController();
    idController = TextEditingController();
    pageReady = List.generate(8, (_) => ValueNotifier<bool>(false));

    // ID 컨트롤러 리스너 추가
    idController.addListener(() {
      if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 300), () async {
        final id = idController.text.trim();
        if (id.isNotEmpty) {
          try {
            final isAvailable = await _authController.checkIdDuplicate(id);
            setState(() {
              idErrorMessage = isAvailable
                  ? '사용 가능한 아이디입니다.'
                  : '이미 사용 중인 아이디입니다.';
            });
          } catch (e) {
            setState(() {
              idErrorMessage = '중복 확인 중 오류가 발생했습니다.';
            });
          }
        } else {
          setState(() {
            idErrorMessage = null;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    // Dispose controllers and notifiers
    nameController.dispose();
    monthController.dispose();
    dayController.dispose();
    yearController.dispose();
    phoneController.dispose();
    smsController.dispose();
    idController.dispose();
    for (var notifier in pageReady) {
      notifier.dispose();
    }
    _autoVerifyTimer?.cancel();
    debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 화면 크기 정보
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,

      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                currentPage = index;
                if (index == 7) {
                  pageReady[7].value = true;
                }
              });
            },
            children: [
              // 1. 이름 입력 페이지
              NameInputPage(
                controller: nameController,
                onChanged: (value) {
                  pageReady[0].value = value.isNotEmpty;
                },
              ),
              // 2. 생년월일 입력 페이지
              BirthDatePage(
                monthController: monthController,
                dayController: dayController,
                yearController: yearController,
                pageController: _pageController,
                onChanged: () {
                  setState(() {
                    selectedMonth = monthController.text;
                    selectedDay = dayController.text;
                    selectedYear = yearController.text;
                    birthDate =
                        "${selectedYear ?? ''}년 ${selectedMonth ?? ''}월 ${selectedDay ?? ''}일";

                    // 모든 필드가 채워졌는지 확인
                    bool isComplete =
                        monthController.text.isNotEmpty &&
                        dayController.text.isNotEmpty &&
                        yearController.text.isNotEmpty;
                    pageReady[1].value = isComplete;
                  });
                },
              ),
              // 3. 전화번호 입력 페이지
              PhoneInputPage(
                controller: phoneController,
                onChanged: (value) {
                  pageReady[2].value = value.isNotEmpty;
                },
                pageController: _pageController,
              ),
              // 인증번호 입력 페이지
              SmsCodePage(
                controller: smsController,
                onChanged: (value) {
                  // 인증번호 입력 여부에 따라 상태 변경
                  pageReady[3].value = value.isNotEmpty;

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
                onResendPressed: () async {
                  if (phoneNumber.isEmpty) {
                    Fluttertoast.showToast(
                      msg: '전화번호를 먼저 입력해주세요.',
                      backgroundColor: Colors.red,
                      textColor: Colors.white,
                    );
                    return;
                  }
                  try {
                    await _authController.verifyPhoneNumber(phoneNumber, (
                      verificationId,
                      resendToken,
                    ) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('인증번호가 재전송되었습니다.')),
                      );
                    }, (verificationId) {});
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('인증번호 재전송에 실패했습니다.')),
                    );
                  }
                },
                pageController: _pageController,
              ),
              // 4. 아이디 입력 페이지
              IdInputPage(
                controller: idController,
                screenHeight: screenHeight,
                errorMessage: idErrorMessage,
                onChanged: (value) {
                  pageReady[4].value = value.isNotEmpty;
                },
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    id = value;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AuthFinalScreen(
                          id: id,
                          name: name,
                          phone: phoneNumber,
                          birthDate: birthDate,
                        ),
                      ),
                    );
                  }
                },
                pageController: _pageController,
              ),
              // 5. 약관동의 페이지
              AgreementPage(
                name: name,
                agreeAll: agreeAll,
                agreeServiceTerms: agreeServiceTerms,
                agreePrivacyTerms: agreePrivacyTerms,
                agreeMarketingInfo: agreeMarketingInfo,
                onToggleAll: (bool value) {
                  setState(() {
                    agreeAll = value;
                    // 전체 동의 시 모든 개별 항목도 함께 변경
                    agreeServiceTerms = value;
                    agreePrivacyTerms = value;
                    agreeMarketingInfo = value;
                    // 약관 페이지 준비 상태 업데이트 (필수 약관이 모두 체크되었는지 확인)
                    pageReady[5].value = agreeServiceTerms && agreePrivacyTerms;
                  });
                },
                onToggleServiceTerms: (bool value) {
                  setState(() {
                    agreeServiceTerms = value;
                    // 개별 항목 변경 시 전체 동의 상태 업데이트
                    _updateAgreeAllStatus();
                    pageReady[5].value = agreeServiceTerms && agreePrivacyTerms;
                  });
                },
                onTogglePrivacyTerms: (bool value) {
                  setState(() {
                    agreePrivacyTerms = value;
                    // 개별 항목 변경 시 전체 동의 상태 업데이트
                    _updateAgreeAllStatus();
                    pageReady[5].value = agreeServiceTerms && agreePrivacyTerms;
                  });
                },
                onToggleMarketingInfo: (bool value) {
                  setState(() {
                    agreeMarketingInfo = value;
                    // 개별 항목 변경 시 전체 동의 상태 업데이트
                    _updateAgreeAllStatus();
                  });
                },
                pageController: _pageController,
              ),
              // 6. 프로필 이미지 선택 페이지
              SelectProfileImagePage(
                onImageSelected: (String? imagePath) {
                  setState(() {
                    profileImagePath = imagePath;
                    pageReady[6].value = true; // 이미지 선택은 선택사항이므로 항상 true
                  });
                },
                pageController: _pageController,
                onSkip: _navigateToAuthFinal,
              ),
              // 7. 친구 추가 및 공유 페이지
              FriendAddAndSharePage(
                pageController: _pageController,
                onSkip: _navigateToAuthFinal,
              ),
            ],
          ),

          // 공통 Continue 버튼
          (currentPage == 3)
              ? SizedBox()
              : Positioned(
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0
                      ? MediaQuery.of(context).viewInsets.bottom + 20.h
                      : 30.h,
                  left: 0,
                  right: 0,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: pageReady[currentPage],
                    builder: (context, ready, child) {
                      final bool isEnabled =
                          ready &&
                          (currentPage != 4 ||
                              idErrorMessage == null ||
                              idErrorMessage == '사용 가능한 아이디입니다.');

                      return ContinueButton(
                        isEnabled: isEnabled,
                        onPressed: isEnabled
                            ? () async {
                                FocusScope.of(context).unfocus();
                                switch (currentPage) {
                                  case 0: // 이름
                                    name = nameController.text;
                                    _pageController.nextPage(
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                    break;
                                  case 1: // 생년월일
                                    _pageController.nextPage(
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                    break;
                                  case 2: // 전화번호
                                    phoneNumber = phoneController.text;
                                    if (phoneNumber.isEmpty) {
                                      Fluttertoast.showToast(
                                        msg: '전화번호를 입력해주세요.',
                                        backgroundColor: Colors.red,
                                        textColor: Colors.white,
                                      );
                                      break;
                                    }
                                    try {
                                      await _authController.verifyPhoneNumber(
                                        phoneNumber,
                                        (verificationId, resendToken) {
                                          _pageController.nextPage(
                                            duration: Duration(
                                              milliseconds: 300,
                                            ),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                        (verificationId) {},
                                      );
                                    } catch (e) {
                                      Fluttertoast.showToast(
                                        msg: 'SMS 발송에 실패했습니다.',
                                        backgroundColor: Colors.red,
                                        textColor: Colors.white,
                                      );
                                    }
                                    break;
                                  case 3: // 인증코드
                                    smsCode = smsController.text;
                                    _performAutoVerification(smsCode);
                                    break;
                                  case 4: // 아이디
                                    id = idController.text;
                                    // ID 저장 후 다음 페이지로 이동
                                    _pageController.nextPage(
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                    break;
                                  case 5: // 약관동의
                                    _pageController.nextPage(
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                    break;
                                  // 여기서 프로필 설정 페이지로 넘어가야함
                                  case 6:
                                    _pageController.nextPage(
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                    break;
                                  case 7:
                                    _navigateToAuthFinal();
                                    break;
                                }
                              }
                            : null,
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  // 자동 인증 수행 함수
  void _performAutoVerification(String code) async {
    if (isCheckingUser) return;
    if (phoneNumber.isEmpty) {
      Fluttertoast.showToast(
        msg: '전화번호를 먼저 입력해주세요.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      isCheckingUser = true;
    });

    smsCode = code;

    try {
      await _authController.signInWithSmsCode(code, () async {
        setState(() {
          isCheckingUser = false;
          isVerified = true;
        });

        FocusScope.of(context).unfocus();
        _pageController.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });

      await _authController.signInWithSmsCodeAndSave(code, phoneNumber, () {});
    } catch (e) {
      setState(() {
        isCheckingUser = false;
        isVerified = false;
      });

      Fluttertoast.showToast(
        msg: '인증에 실패했습니다. 다시 시도해주세요.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  // 전체 동의 상태 업데이트 함수
  void _updateAgreeAllStatus() {
    agreeAll = agreeServiceTerms && agreePrivacyTerms && agreeMarketingInfo;
  }

  void _navigateToAuthFinal() async {
    final currentUser = _authController.currentUser;
    if (currentUser == null) {
      Fluttertoast.showToast(
        msg: '인증을 먼저 완료해주세요.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    try {
      await _authController.createUserInFirestore(
        currentUser,
        id,
        name,
        phoneNumber,
        birthDate,
      );

      if (profileImagePath != null && profileImagePath!.isNotEmpty) {
        try {
          await _authController.uploadProfileImageFromPath(profileImagePath!);
        } catch (e) {
          debugPrint('프로필 이미지 업로드 실패: $e');
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AuthFinalScreen(
            id: id,
            name: name,
            phone: phoneNumber,
            birthDate: birthDate,
            profileImagePath: profileImagePath,
          ),
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: '회원가입 처리 중 오류가 발생했습니다.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }
}
