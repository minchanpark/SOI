import 'dart:ui';

import 'package:flutter/material.dart';

/// 눌림 효과가 있는 컨테이너 위젯
class PressableContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final Color color;

  // press effects
  final double pressedScale;
  final double shadowBlur;
  final double shadowBlurPressed;
  final Offset shadowOffset;
  final Offset shadowOffsetPressed;
  final Duration pressDownDuration;
  final Duration releaseDuration;

  const PressableContainer({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.color = const Color(0xFF111111),
    this.pressedScale = 0.9,
    this.shadowBlur = 18,
    this.shadowBlurPressed = 8,
    this.shadowOffset = const Offset(0, 10),
    this.shadowOffsetPressed = const Offset(0, 4),
    this.pressDownDuration = Duration.zero, // press down 효과가 바로 나타남
    this.releaseDuration = const Duration(milliseconds: 90),
  });

  @override
  State<PressableContainer> createState() => _PressableContainerState();
}

class _PressableContainerState extends State<PressableContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 1,
      value: 0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press() {
    if (widget.pressDownDuration == Duration.zero) {
      _controller.value = 1;
      return;
    }

    _controller.animateTo(
      1,
      duration: widget.pressDownDuration,
      curve: Curves.easeOut,
    );
  }

  void _release() {
    _controller.animateTo(
      0,
      duration: widget.releaseDuration,
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _press(),
      onTapUp: (_) => _release(),
      onTapCancel: () => _release(),
      onTap: widget.onTap,
      onLongPressStart: (_) => _press(),
      onLongPressEnd: (_) => _release(),
      onLongPressCancel: () => _release(),
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final scale = lerpDouble(1.0, widget.pressedScale, t) ?? 1.0;
          final blur =
              lerpDouble(widget.shadowBlur, widget.shadowBlurPressed, t) ??
              widget.shadowBlur;
          final offset =
              Offset.lerp(widget.shadowOffset, widget.shadowOffsetPressed, t) ??
              widget.shadowOffset;

          return Transform.scale(
            scale: scale,
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: widget.borderRadius,
                boxShadow: [
                  BoxShadow(
                    blurRadius: blur,
                    offset: offset,
                    color: const Color(0x40000000),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
