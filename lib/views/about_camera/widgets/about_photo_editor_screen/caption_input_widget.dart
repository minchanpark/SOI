import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';

/// 캡션 입력 위젯
/// 사진이나 비디오에 대한 설명을 입력할 수 있는 텍스트 필드와,
/// 캡션이 비어있을 때 음성 입력 버튼을 표시하는 위젯입니다.
/// PhotoEditorScreenView에서 사용됩니다.
///
/// Parameters:
/// - [controller]: 텍스트 필드의 입력을 제어하는 TextEditingController입니다.
/// - [isCaptionEmpty]: 캡션이 비어있는지 여부를 나타내는 불리언 값입니다.
/// - [onMicTap]: 음성 입력 버튼이 탭될 때 호출되는 콜백 함수입니다.
/// - [isKeyboardVisible]: 키보드가 보이는지 여부를 나타내는 불리언 값입니다.
/// - [keyboardHeight]: 키보드의 높이를 나타내는 double 값입니다.
/// - [focusNode]: 텍스트 필드의 포커스를 제어하는 FocusNode입니다.
class CaptionInputWidget extends StatelessWidget {
  final TextEditingController controller;
  final bool isCaptionEmpty;
  final VoidCallback onMicTap;
  final bool isKeyboardVisible;
  final double keyboardHeight;
  final FocusNode focusNode;

  const CaptionInputWidget({
    super.key,
    required this.controller,
    required this.isCaptionEmpty,
    required this.onMicTap,
    required this.isKeyboardVisible,
    required this.keyboardHeight,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: SizedBox(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF373737).withOpacity(0.66),
            borderRadius: BorderRadius.circular(21.5),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 19, vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    maxLines: null,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.50,
                    ),
                    cursorColor: Colors.white,
                    textInputAction: TextInputAction.newline,
                    onTapOutside: (event) {
                      FocusScope.of(context).unfocus();
                    },
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: tr('camera.caption_hint', context: context),
                      hintStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w200,
                        letterSpacing: -1.14,
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: isCaptionEmpty
                      ? Row(
                          key: const ValueKey('mic_button'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 12),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: onMicTap,
                                borderRadius: BorderRadius.circular(18),
                                child: Image.asset(
                                  'assets/mic_icon.png',
                                  width: 36,
                                  height: 36,
                                ),
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          key: const ValueKey('mic_placeholder'),
                          width: 0,
                          height: 36,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
