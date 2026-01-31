import 'package:flutter/material.dart';

const double kTagPadding = 4.0;
const double kTagPointerHeight = 8.0;
const double kTagPointerWidth = 16.0;
const double kTagPointerOverlap = 2.0;

class TagBubble extends StatelessWidget {
  const TagBubble({
    super.key,
    required this.child,
    required this.contentSize,
    this.backgroundColor = const Color(0xFF000000),
    this.padding = kTagPadding,
    this.pointerHeight = kTagPointerHeight,
    this.pointerWidth = kTagPointerWidth,
    this.pointerOverlap = kTagPointerOverlap,
  });

  final Widget child;
  final double contentSize;
  final Color backgroundColor;
  final double padding;
  final double pointerHeight;
  final double pointerWidth;
  final double pointerOverlap;

  static double diameterForContent({
    required double contentSize,
    double padding = kTagPadding,
  }) {
    return contentSize + (padding * 2);
  }

  static double totalHeightForContent({
    required double contentSize,
    double padding = kTagPadding,
    double pointerHeight = kTagPointerHeight,
    double pointerOverlap = kTagPointerOverlap,
  }) {
    return diameterForContent(contentSize: contentSize, padding: padding) +
        pointerHeight -
        pointerOverlap;
  }

  static Offset pointerTipOffset({
    required double contentSize,
    double padding = kTagPadding,
    double pointerHeight = kTagPointerHeight,
    double pointerOverlap = kTagPointerOverlap,
  }) {
    final diameter = diameterForContent(
      contentSize: contentSize,
      padding: padding,
    );
    return Offset(diameter / 2, diameter + pointerHeight - pointerOverlap);
  }

  @override
  Widget build(BuildContext context) {
    final diameter = diameterForContent(
      contentSize: contentSize,
      padding: padding,
    );
    final totalHeight = totalHeightForContent(
      contentSize: contentSize,
      padding: padding,
      pointerHeight: pointerHeight,
      pointerOverlap: pointerOverlap,
    );

    return SizedBox(
      width: diameter,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: child,
          ),
          Positioned(
            top: diameter - pointerOverlap,
            child: SizedBox(
              width: pointerWidth,
              height: pointerHeight,
              child: CustomPaint(
                painter: _TagPointerPainter(color: backgroundColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPointerPainter extends CustomPainter {
  const _TagPointerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TagPointerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
