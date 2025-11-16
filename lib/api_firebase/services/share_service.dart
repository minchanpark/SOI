import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// 공유 관련 기능을 담당하는 서비스
class ShareService {
  /// 단순 링크 공유
  Future<void> shareLink(
    String link, {
    String? message,
    required BuildContext originContext,
  }) async {
    final uri = Uri.tryParse(link);
    final shareParams = _buildParams(uri, link, message);

    try {
      final renderObject = originContext.findRenderObject();
      Rect? shareOrigin;

      if (renderObject is RenderBox && renderObject.hasSize) {
        final offset = renderObject.localToGlobal(Offset.zero);
        shareOrigin = offset & renderObject.size;
      } else {
        final size = MediaQuery.sizeOf(originContext);
        if (size.width > 0 && size.height > 0) {
          shareOrigin = Offset.zero & size;
        }
      }

      await SharePlus.instance.share(
        ShareParams(text: shareParams, sharePositionOrigin: shareOrigin),
      );
    } on Exception catch (e) {
      debugPrint('Error sharing link: $e');
      return;
    }
  }

  String _buildParams(Uri? uri, String link, String? message) {
    if (message != null && message.trim().isNotEmpty) {
      final text =
          message.contains(link) ? message : '${message.trim()}\n$link';
      return text;
    }

    if (uri != null) {
      return uri.toString();
    }
    return link;
  }
}
