import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// SOI 댓글 입력창은 텍스트 편집과 제출 로딩만 담당해 상위가 draft 생성에 집중하게 합니다.
class SoiTagTextInputWidget extends StatefulWidget {
  const SoiTagTextInputWidget({
    super.key,
    required this.onSubmitText,
    this.onFocusChanged,
    this.onEditingCancelled,
    this.hintText = '',
    this.initialText = '',
    this.autoFocus = true,
  });

  final Future<void> Function(String text) onSubmitText;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback? onEditingCancelled;
  final String hintText;
  final String initialText;
  final bool autoFocus;

  @override
  State<SoiTagTextInputWidget> createState() => _SoiTagTextInputWidgetState();
}

/// 입력 상태와 제출 진행 상태를 한 곳에서 관리해 SOI 상위 레이어를 단순화합니다.
class _SoiTagTextInputWidgetState extends State<SoiTagTextInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialText;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
    if (!_focusNode.hasFocus && _controller.text.trim().isEmpty) {
      widget.onEditingCancelled?.call();
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    var succeeded = false;
    try {
      await widget.onSubmitText(text);
      succeeded = true;
    } catch (_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    } finally {
      if (mounted && succeeded) {
        _controller.clear();
        FocusScope.of(context).unfocus();
      }
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 354,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xff161616),
        borderRadius: BorderRadius.circular(21.5),
        border: Border.all(color: const Color(0x66D9D9D9), width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autoFocus,
              minLines: 1,
              maxLines: 4,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              onSubmitted: (_) => _submit(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w300,
                letterSpacing: -0.6,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 16.sp,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w200,
                  letterSpacing: -1.14,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.send_rounded, color: Colors.white, size: 17),
          ),
        ],
      ),
    );
  }
}
