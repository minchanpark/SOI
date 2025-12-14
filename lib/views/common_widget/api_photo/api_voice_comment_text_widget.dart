import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// API 기반 텍스트 댓글 입력 위젯
///
/// Firebase 버전의 VoiceCommentTextWidget과 동일한 디자인을 유지하면서
/// int 타입의 postId를 사용합니다.
class ApiVoiceCommentTextWidget extends StatefulWidget {
  final int postId;
  final Function(int) onToggleVoiceComment;
  final Function(bool)? onFocusChanged;
  final Function(String)? onTextCommentCreated;

  const ApiVoiceCommentTextWidget({
    super.key,
    required this.postId,
    required this.onToggleVoiceComment,
    this.onFocusChanged,
    this.onTextCommentCreated,
  });

  @override
  State<ApiVoiceCommentTextWidget> createState() =>
      _ApiVoiceCommentTextWidgetState();
}

class _ApiVoiceCommentTextWidgetState extends State<ApiVoiceCommentTextWidget> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
  }

  Future<void> _sendTextComment() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      _textController.clear();
      FocusScope.of(context).unfocus();
      widget.onTextCommentCreated?.call(text);
      debugPrint('✅ 텍스트 댓글 임시 저장 완료');
    } catch (e) {
      debugPrint('❌ 텍스트 댓글 처리 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 353,
      decoration: BoxDecoration(
        color: const Color(0xff161616),
        borderRadius: BorderRadius.circular(21.5),
        border: Border.all(color: const Color(0x66D9D9D9), width: 1),
        // 3D: 댓글 입력 태그가 떠 보이도록(아래 그림자 + 위쪽 하이라이트)
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            offset: const Offset(0, 10),
            blurRadius: 18,
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            offset: const Offset(0, -2),
            blurRadius: 6,
            spreadRadius: -2,
          ),
        ],
      ),
      // 3D: 상단 하이라이트/하단 음영 오버레이(기존 색 유지)
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21.5),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      padding: EdgeInsets.only(left: 11.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: InkWell(
              onTap: () => widget.onToggleVoiceComment(widget.postId),
              child: Image.asset('assets/mic_icon.png', width: 36, height: 36),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                onTapOutside: (event) {
                  FocusScope.of(context).unfocus();
                },
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintText: '댓글 추가 ....',
                  hintStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w200,
                    letterSpacing: -1.14,
                  ),
                ),
                cursorColor: Colors.white,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w200,
                  letterSpacing: -1.14,
                ),
                textAlignVertical: TextAlignVertical.center,
              ),
            ),
          ),
          IconButton(
            onPressed: _isSending ? null : _sendTextComment,
            icon: _isSending
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Image.asset('assets/send_icon.png', width: 17, height: 17),
          ),
        ],
      ),
    );
  }
}
