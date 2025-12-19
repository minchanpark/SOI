import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/views/about_login/widgets/pages/agreement_page.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'auth_final_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  final PageController _pageController = PageController();

  // 자동 인증을 위한 Timer
  Timer? _autoVerifyTimer;

  // 사용자가 존재하는지 여부 및 상태 관리
  bool userExists = false;
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

  // userController만 사용하여서 UI에서 직접 접근
  late UserController _userController;
  bool _isControllerInitialized = false;

  @override
  void initState() {
    super.initState();
    // 컨트롤러 및 상태 초기화
    nameController = TextEditingController();
    monthController = TextEditingController();
    dayController = TextEditingController();
    yearController = TextEditingController();
    phoneController = TextEditingController();
    smsController = TextEditingController();
    idController = TextEditingController();
    pageReady = List.generate(8, (_) => ValueNotifier<bool>(false));

    pageReady[6].value = true;

    // ID 컨트롤러 리스너 추가
    idController.addListener(() {
      if (!_isControllerInitialized) return; // Provider 초기화 전이면 무시
      if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
      debounceTimer = Timer(const Duration(milliseconds: 300), () async {
        final id = idController.text.trim();
        if (id.isNotEmpty) {
          try {
            final result = await _userController.checknickNameAvailable(id);
            if (result == true) {
              setState(() {
                idErrorMessage = '사용 가능한 아이디입니다.';
              });
            } else {
              setState(() {
                idErrorMessage = '이미 사용 중인 아이디입니다.';
              });
            }
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isControllerInitialized) {
      _userController = Provider.of<UserController>(context, listen: false);
      _isControllerInitialized = true;
    }
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
                    // 서버 API 형식에 맞게 YYYY.MM.DD 형식으로 저장
                    final month = (selectedMonth ?? '').padLeft(2, '0');
                    final day = (selectedDay ?? '').padLeft(2, '0');
                    birthDate = "${selectedYear ?? ''}.$month.$day";

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
                  pageReady[3].value = value.length == 5;

                  // 인증 완료 후, 사용자가 인증번호를 변경하면 상태 초기화
                  if (isVerified) {
                    setState(() {
                      isVerified = false;
                    });
                  }
                },
                onResendPressed: () async {
                  String formattedPhone = phoneNumber;
                  if (phoneNumber.startsWith('0')) {
                    formattedPhone = '+82${phoneNumber.substring(1)}';
                  } else if (!phoneNumber.startsWith('+')) {
                    formattedPhone = '+82$phoneNumber';
                  }

                  try {
                    await _userController
                        .requestSmsVerification(formattedPhone)
                        .onError((error, stackTrace) {
                          throw Exception('SMS 재전송 실패: $error');
                        });
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('인증번호 재전송 중 오류가 발생했습니다.')),
                    );
                    debugPrint('재전송 예외: $e');
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

                    // 이미지 선택은 선택사항이므로 항상 true
                    pageReady[6].value = true;
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
          Positioned(
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

                              // 전화번호 형식을 국제 형식으로 변환 (+82)
                              String formattedPhone = phoneNumber;
                              if (phoneNumber.startsWith('0')) {
                                formattedPhone =
                                    '+82${phoneNumber.substring(1)}';
                              } else if (!phoneNumber.startsWith('+')) {
                                formattedPhone = '+82$phoneNumber';
                              }

                              try {
                                bool isSuccess = await _userController
                                    .requestSmsVerification(formattedPhone);
                                if (isSuccess) {
                                  _pageController.nextPage(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                } else {
                                  Fluttertoast.showToast(
                                    msg: 'SMS 발송에 실패했습니다. 다시 시도해주세요.',
                                    backgroundColor: Colors.red,
                                    textColor: Colors.white,
                                  );
                                }
                              } catch (e) {
                                Fluttertoast.showToast(
                                  msg: 'SMS 발송 중 오류가 발생했습니다.',
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                );
                                debugPrint('SMS 발송 예외: $e');
                              }
                              break;
                            case 3: // 인증코드
                              smsCode = smsController.text;

                              // 버튼 클릭시 인증 확인 수행
                              if (smsCode.length == 5) {
                                await _performManualVerification(smsCode);
                              }
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

  Future<void> _performManualVerification(String code) async {
    if (isCheckingUser) return;

    setState(() {
      isCheckingUser = true;
    });

    smsCode = code;

    try {
      final isSuccess = await _userController.verifySmsCode(
        phoneNumber.startsWith('0')
            ? '+82${phoneNumber.substring(1)}'
            : (phoneNumber.startsWith('+') ? phoneNumber : '+82$phoneNumber'),
        smsCode,
      );
      if (!mounted) return;
      if (isSuccess) {
        setState(() {
          isCheckingUser = false;
          isVerified = true;
        });

        Fluttertoast.showToast(
          msg: '인증이 완료되었습니다.',
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );

        FocusScope.of(context).unfocus();
        _pageController.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        setState(() {
          isCheckingUser = false;
          isVerified = false;
        });
        Fluttertoast.showToast(
          msg: '인증번호가 올바르지 않습니다.',
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isCheckingUser = false;
        isVerified = false;
      });

      final errorMessage = e.toString().replaceFirst('Exception: ', '').trim();
      Fluttertoast.showToast(
        msg: errorMessage.isNotEmpty ? errorMessage : '인증 확인 중 오류가 발생했습니다.',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      debugPrint('인증 확인 중 예외: $e');
    }
  }

  // 전체 동의 상태 업데이트 함수
  void _updateAgreeAllStatus() {
    agreeAll = agreeServiceTerms && agreePrivacyTerms && agreeMarketingInfo;
  }

  void _navigateToAuthFinal() {
    // 회원가입 데이터를 AuthFinalScreen으로 전달
    // 실제 회원가입은 onboarding 완료 후 수행
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AuthFinalScreen(
          id: id,
          name: name,
          phone: phoneNumber,
          birthDate: birthDate,
          profileImagePath: profileImagePath,
          agreeServiceTerms: agreeServiceTerms,
          agreePrivacyTerms: agreePrivacyTerms,
          agreeMarketingInfo: agreeMarketingInfo,
        ),
      ),
    );
  }
}
