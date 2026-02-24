import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import '../common/page_title.dart';
import '../common/custom_text_field.dart';
import '../common/validation_message.dart';

/// 아이디 입력 페이지 위젯
class IdInputPage extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final Function(String)? onSubmitted;
  final String? errorMessage;
  final bool? isAvailable;
  final double screenHeight;
  final PageController? pageController;

  const IdInputPage({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onSubmitted,
    this.errorMessage,
    this.isAvailable,
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
                    PageTitle(title: tr('register.id_title', context: context)),
                    SizedBox(height: 24),
                    CustomTextField(
                      controller: controller,
                      hintText: tr('register.id_hint', context: context),
                      keyboardType: TextInputType.text,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                    ),
                    SizedBox(height: 11.h),
                    // 아이디 중복 체크 결과 메시지
                    (errorMessage != null)
                        ? ValidationMessage(
                            message: errorMessage!,
                            isSuccess: isAvailable == true,
                          )
                        : SizedBox(height: 20),
                    SizedBox(height: 130.h),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 뒤로 가기 버튼을 마지막에 배치하여 터치 이벤트가 차단되지 않도록 함
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
      ],
    );
  }
}
