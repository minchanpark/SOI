import 'package:flutter/material.dart';

class CommentTextInputWidget extends StatefulWidget {
  final Future<void> Function(String text) onSubmitText;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback? onEditingCancelled;
  final String hintText;
  final bool autoFocus;

  const CommentTextInputWidget({
    super.key,
    required this.onSubmitText,
    this.onFocusChanged,
    this.onEditingCancelled,
    this.hintText = '댓글 추가...',
    this.autoFocus = true,
  });

  @override
  State<CommentTextInputWidget> createState() => _CommentTextInputWidgetState();
}

class _CommentTextInputWidgetState extends State<CommentTextInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
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

    try {
      await widget.onSubmitText(text);
      if (!mounted) {
        return;
      }
      _controller.clear();
      FocusScope.of(context).unfocus();
    } finally {
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
      width: 353,
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
                hintStyle: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w300,
                  letterSpacing: -0.6,
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
                : Image.asset('assets/send_icon.png', width: 17, height: 17),
          ),
        ],
      ),
    );
  }
}
