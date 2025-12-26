import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';

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
                  transitionBuilder:
                      (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                  child:
                      isCaptionEmpty
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
