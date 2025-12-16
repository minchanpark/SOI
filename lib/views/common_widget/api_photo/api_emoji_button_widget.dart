import 'package:flutter/material.dart';

class ApiEmojiButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onPressed;
  final double buttonExtent;
  final double emojiFontSize;
  final double previewEmojiFontSize;
  final Offset previewOffset;

  const ApiEmojiButton({
    super.key,
    required this.emoji,
    required this.onPressed,
    this.buttonExtent = 22,
    this.emojiFontSize = 22,
    this.previewEmojiFontSize = 40,
    this.previewOffset = const Offset(0, -48),
  });

  @override
  State<ApiEmojiButton> createState() => _ApiEmojiButtonState();
}

class _ApiEmojiButtonState extends State<ApiEmojiButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _previewEntry;
  double _pressedScale = 1.0;
  bool _isLongPressing = false;

  @override
  void dispose() {
    _removePreview();
    super.dispose();
  }

  @override
  void deactivate() {
    _removePreview();
    super.deactivate();
  }

  void _showPreview() {
    if (_previewEntry != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _previewEntry = OverlayEntry(
      builder: (context) {
        return IgnorePointer(
          ignoring: true,
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  offset: widget.previewOffset,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.9, end: 1.0),
                    duration: const Duration(milliseconds: 140),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Transform.scale(scale: value, child: child);
                    },
                    child: Text(
                      widget.emoji,
                      style: TextStyle(
                        fontSize: widget.previewEmojiFontSize,
                        shadows: const [
                          Shadow(
                            blurRadius: 12,
                            color: Colors.black54,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    overlay.insert(_previewEntry!);
  }

  void _removePreview() {
    _previewEntry?.remove();
    _previewEntry = null;
  }

  void _setPressedScale(double value) {
    if (_pressedScale == value) return;
    setState(() => _pressedScale = value);
  }

  void _startLongPress() {
    _isLongPressing = true;
    _setPressedScale(widget.previewEmojiFontSize / widget.emojiFontSize);
    debugPrint('[ApiEmojiButton] 이모지 프리뷰 표시: ${widget.emoji}');
    _showPreview();
  }

  void _endLongPress() {
    _isLongPressing = false;
    _setPressedScale(1.0);
    _removePreview();
  }

  @override
  Widget build(BuildContext context) {
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
            _setPressedScale(1.12);
          },
          onTapUp: (_) {
            if (_isLongPressing) return;
            _setPressedScale(1.0);
          },
          onTapCancel: () {
            if (_isLongPressing) return;
            _setPressedScale(1.0);
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
