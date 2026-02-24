import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 음성 댓글과 텍스트 댓글 입력 UI를 통합한 위젯
/// - 음성 댓글 토글 버튼과 텍스트 입력 필드, 전송 버튼을 포함
/// - 텍스트 입력 시 댓글이 임시 저장되고, 음성 댓글 버튼 클릭 시 음성 댓글 UI로 전환
/// - 댓글 입력 필드에 포커스가 생기거나 사라질 때 콜백을 통해 부모 위젯에 알림
/// - 텍스트 댓글이 생성되면 콜백을 통해 부모 위젯에 전달
///
/// UI 디자인:
/// - 배경: #161616, 테두리: #66D9D9D, 테두리 두께: 1.2, 모서리 반경: 21.5
/// - 음성 댓글 버튼: 마이크 아이콘, 크기 36x36, 왼쪽 여백 11
/// - 텍스트 입력 필드: 힌트 텍스트 "댓글 추가 ....", 폰트 크기 16, 폰트 패밀리 'Pretendard', 폰트 두께 200, 글자 간격 -1.14, 텍스트 색상 흰색
/// - 전송 버튼: 보내기 아이콘, 크기 17x17, 오른쪽 여백 11, 텍스트 입력 중에는 로딩 인디케이터로 대체
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
    const ringColor = Color(0x66D9D9D9);
    const ringWidth = 1.2;
    const pointerHeight = 8.0;

    return SizedBox(
      width: 353,
      height: 46 + pointerHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 353,
              decoration: BoxDecoration(
                color: const Color(0xff161616),
                borderRadius: BorderRadius.circular(21.5),
                border: Border.all(color: ringColor, width: ringWidth),
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
                      child: Image.asset(
                        'assets/mic_icon.png',
                        width: 36,
                        height: 36,
                      ),
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Image.asset(
                            'assets/send_icon.png',
                            width: 17,
                            height: 17,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
