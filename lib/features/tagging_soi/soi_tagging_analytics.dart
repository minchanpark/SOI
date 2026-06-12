import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:tagging_core/tagging_core.dart';

import '../../utils/analytics_service.dart';

/// 태그 저장 통계를 SOI 이벤트 스키마에 맞춰 전송합니다.
class SoiTaggingAnalytics {
  const SoiTaggingAnalytics._();

  static Future<void> trackCommentTagSaved(
    BuildContext context, {
    required int postId,
    required int categoryId,
    required String surface,
    required String tagContentType,
    required int existingTagCountBefore,
    required TagEntry comment,
  }) async {
    try {
      final analytics = context.read<AnalyticsService>();
      final properties = <String, dynamic>{
        'post_id': postId,
        'category_id': categoryId,
        'surface': surface,
        'tag_content_type': tagContentType,
        'existing_tag_count_before': existingTagCountBefore,
        'existing_tag_count_after': existingTagCountBefore + 1,
      };

      if (comment.id != null) {
        properties['comment_id'] = comment.id;
      }

      await analytics.track('comment_tag_saved', properties: properties);
      if (kDebugMode) {
        analytics.flush();
      }
    } catch (error) {
      debugPrint('Mixpanel comment_tag_saved tracking failed: $error');
    }
  }
}
