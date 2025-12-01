import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../common/page_title.dart';
import '../common/custom_text_field.dart';
import '../common/validation_message.dart';

/// 아이디 입력 페이지 위젯
class IdInputPage extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final Function(String)? onSubmitted;
  final String? errorMessage;
  final double screenHeight;
  final PageController? pageController;

  const IdInputPage({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onSubmitted,
    this.errorMessage,
    required this.screenHeight,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    // 키보드 높이 계산
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final verticalOffset = keyboardHeight > 0 ? -30.0 : 0.0; // 키보드가 올라올 때 위로 이동

    return Stack(
      children: [
        Positioned(
          top: 60.h,
          left: 20.w,
          child: IconButton(
            onPressed: () {
              pageController?.previousPage(
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(minHeight: screenHeight),
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(0, verticalOffset),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const PageTitle(title: '사용하실 아이디를 입력해주세요.'),
                    SizedBox(height: 24),
                    CustomTextField(
                      controller: controller,
                      hintText: '아이디 입력',
                      keyboardType: TextInputType.text,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                    ),
                    SizedBox(height: 11.h),
                    // 아이디 중복 체크 결과 메시지
                    (errorMessage != null)
                        ? ValidationMessage(
                            message: errorMessage!,
                            isSuccess: errorMessage == '사용 가능한 아이디입니다.',
                          )
                        : SizedBox(height: 20),
                    SizedBox(height: 130.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
