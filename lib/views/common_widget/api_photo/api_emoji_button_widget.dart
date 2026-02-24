import 'package:flutter/material.dart';

class ApiEmojiButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onPressed;
  final double buttonExtent;
  final double emojiFontSize;
  final double previewEmojiFontSize;

  const ApiEmojiButton({
    super.key,
    required this.emoji,
    required this.onPressed,
    this.buttonExtent = 22,
    this.emojiFontSize = 22,
    this.previewEmojiFontSize = 40,
  });

  @override
  State<ApiEmojiButton> createState() => _ApiEmojiButtonState();
}

class _ApiEmojiButtonState extends State<ApiEmojiButton> {
  final LayerLink _layerLink = LayerLink();
  double _pressedScale = 1.0;
  bool _isLongPressing = false;

  void _setPressedScale(double value) {
    if (_pressedScale == value) return;
    setState(() => _pressedScale = value);
  }

  void _startLongPress() {
    _isLongPressing = true;
    _setPressedScale(widget.previewEmojiFontSize / widget.emojiFontSize);
  }

  void _endLongPress() {
    _isLongPressing = false;
    _setPressedScale(1.0);
  }

  @override
  Widget build(BuildContext context) {
    // CompositedTransformTarget: 오버레이 위치 지정을 위한 위젯
    //   -
    // Semantics: 접근성 향상을 위한 위젯
    return CompositedTransformTarget(
      link: _layerLink,
      child: Semantics(
        button: true,
        label: widget.emoji,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          onTapDown: (_) {
            if (_isLongPressing) return;
            _setPressedScale(2);
          },
          onTapUp: (_) {
            if (_isLongPressing) return;
            _setPressedScale(2);
          },
          onTapCancel: () {
            if (_isLongPressing) return;
            _setPressedScale(2);
          },
          onLongPressStart: (_) => _startLongPress(),
          onLongPressEnd: (_) => _endLongPress(),
          onLongPressCancel: _endLongPress,
          child: AnimatedScale(
            scale: _pressedScale,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Center(
              child: Text(
                widget.emoji,
                style: TextStyle(fontSize: widget.emojiFontSize),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
