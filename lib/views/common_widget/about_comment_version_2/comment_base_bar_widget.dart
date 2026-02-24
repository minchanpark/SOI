import 'package:flutter/material.dart';

class CommentBaseBarWidget extends StatelessWidget {
  final VoidCallback onCenterTap;
  final VoidCallback? onCameraPressed;
  final VoidCallback? onMicPressed;

  const CommentBaseBarWidget({
    super.key,
    required this.onCenterTap,
    this.onCameraPressed,
    this.onMicPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 353,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xff161616),
        borderRadius: BorderRadius.circular(21.5),
        border: Border.all(color: const Color(0x66D9D9D9), width: 1.2),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onCameraPressed,
            icon: Image.asset('assets/camera.png', width: 22, height: 22),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCenterTap,
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '댓글 추가...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onMicPressed,
            icon: Image.asset('assets/mic_icon.png', width: 30, height: 30),
          ),
        ],
      ),
    );
  }
}
