import 'package:flutter/widgets.dart';

/// 첫 번째 줄에만 말줄임표를 적용하는 텍스트 위젯
/// 단일 책임: 첫 번째 줄에 말줄임표 적용 및 나머지 텍스트 표시
class FirstLineEllipsisText extends StatelessWidget {
  const FirstLineEllipsisText({
    super.key,
    required this.text,
    required this.style,
  });

  static const String _ellipsis = '...';

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth.isInfinite || maxWidth <= 0) {
          return Text(text, style: style);
        }

        final direction = Directionality.of(context);
        final needsCollapse = _needsCollapse(text, style, direction, maxWidth);

        if (!needsCollapse) {
          return Text(text, style: style);
        }

        final lineBreakIndex = _firstLineBreakIndex(text);
        final firstLineCandidate = lineBreakIndex == null
            ? text
            : text.substring(0, lineBreakIndex);

        final visibleFirstLine = _fitFirstLine(
          firstLineCandidate,
          style,
          direction,
          maxWidth,
        );

        final consumedInFirstLine = visibleFirstLine.length;
        var remainingStart = consumedInFirstLine;

        if (lineBreakIndex != null &&
            consumedInFirstLine >= firstLineCandidate.length) {
          remainingStart = _skipLineBreak(text, lineBreakIndex);
        }

        if (remainingStart >= text.length) {
          return Text(text, style: style);
        }

        var remainingText = text.substring(remainingStart);
        if (remainingText.startsWith('\r\n')) {
          remainingText = remainingText.substring(2);
        } else if (remainingText.startsWith('\n') ||
            remainingText.startsWith('\r')) {
          remainingText = remainingText.substring(1);
        }

        if (remainingText.isEmpty && consumedInFirstLine >= text.length) {
          return Text(text, style: style);
        }

        final firstLineWithEllipsis = StringBuffer(visibleFirstLine)
          ..write(_ellipsis);

        final clipHeight = _computeFirstLineHeight(
          '$visibleFirstLine$_ellipsis',
          style,
          direction,
          maxWidth,
        );

        return ClipRect(
          child: SizedBox(
            height: clipHeight,
            child: RichText(
              text: TextSpan(
                style: style,
                children: [
                  TextSpan(text: firstLineWithEllipsis.toString()),
                  if (remainingText.isNotEmpty)
                    TextSpan(text: '\n$remainingText'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static bool _needsCollapse(
    String value,
    TextStyle style,
    TextDirection direction,
    double maxWidth,
  ) {
    if (_hasLineBreak(value)) {
      return true;
    }

    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      maxLines: 1,
      textDirection: direction,
    )..layout(maxWidth: maxWidth);

    return painter.didExceedMaxLines;
  }

  static bool _hasLineBreak(String value) {
    return value.contains('\n') || value.contains('\r');
  }

  static int? _firstLineBreakIndex(String value) {
    final nIndex = value.indexOf('\n');
    final rIndex = value.indexOf('\r');

    if (nIndex == -1 && rIndex == -1) {
      return null;
    }

    if (nIndex == -1) {
      return rIndex;
    }

    if (rIndex == -1) {
      return nIndex;
    }

    return nIndex < rIndex ? nIndex : rIndex;
  }

  static int _skipLineBreak(String value, int index) {
    if (index + 1 < value.length &&
        value[index] == '\r' &&
        value[index + 1] == '\n') {
      return index + 2;
    }

    return index + 1;
  }

  static String _fitFirstLine(
    String candidate,
    TextStyle style,
    TextDirection direction,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: candidate, style: style),
      maxLines: 1,
      textDirection: direction,
    )..layout(maxWidth: maxWidth);

    if (!painter.didExceedMaxLines) {
      final withEllipsis = TextPainter(
        text: TextSpan(text: '$candidate$_ellipsis', style: style),
        maxLines: 1,
        textDirection: direction,
      )..layout(maxWidth: maxWidth);

      if (!withEllipsis.didExceedMaxLines) {
        return candidate;
      }
    }

    var low = 0;
    var high = candidate.length;
    var best = 0;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final testText = candidate.substring(0, mid);

      final testPainter = TextPainter(
        text: TextSpan(text: '$testText$_ellipsis', style: style),
        maxLines: 1,
        textDirection: direction,
      )..layout(maxWidth: maxWidth);

      if (!testPainter.didExceedMaxLines) {
        best = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return candidate.substring(0, best);
  }

  static double _computeFirstLineHeight(
    String line,
    TextStyle style,
    TextDirection direction,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: line, style: style),
      maxLines: 1,
      textDirection: direction,
    )..layout(maxWidth: maxWidth);

    final metrics = painter.computeLineMetrics();
    if (metrics.isEmpty) {
      return painter.height;
    }

    return metrics.first.height;
  }
}
