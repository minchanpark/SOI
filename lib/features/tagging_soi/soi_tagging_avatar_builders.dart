import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tagging_core/tagging_core.dart';
import 'package:tagging_flutter/tagging_flutter.dart';

import '../../api/controller/user_controller.dart';
import '../../views/common_widget/user/current_user_image_builder.dart';
import 'soi_tag_entry_extensions.dart';
import 'soi_tagging_ids.dart';
import 'soi_tagging_metadata.dart';

/// SOI의 현재 사용자 selector를 tagging_flutter avatar builder 계약으로 연결합니다.
class SoiTaggingAvatarBuilders {
  const SoiTaggingAvatarBuilders._();

  static Widget buildComposerAvatar(
    BuildContext context,
    TagSaveRequest request,
    double size,
  ) {
    final fallbackSource = request.metadata[SoiTaggingMetadata.profileImageSource];
    final normalizedSource = fallbackSource is String ? fallbackSource.trim() : null;
    final fallbackImageUrl = _isAbsoluteUrl(normalizedSource)
        ? normalizedSource
        : null;
    final fallbackImageKey = fallbackImageUrl == null ? normalizedSource : null;
    return CurrentUserImageBuilder(
      imageKind: CurrentUserImageKind.profile,
      targetUserId: SoiTaggingIds.intFromEntityId(request.actorId),
      fallbackImageUrl: fallbackImageUrl,
      fallbackImageKey: fallbackImageKey,
      builder: (context, imageUrl, cacheKey) {
        return TagCircleAvatar(
          imageUrl: imageUrl,
          size: size,
          cacheKey: cacheKey,
        );
      },
    );
  }

  static Widget buildCommentAvatar(
    BuildContext context,
    TagEntry comment,
    double size,
    bool isSelected,
  ) {
    return CurrentUserImageBuilder(
      imageKind: CurrentUserImageKind.profile,
      targetUserId: comment.userId,
      targetUserHandle: comment.nickname,
      fallbackImageUrl: comment.userProfileUrl,
      fallbackImageKey: comment.userProfileKey,
      builder: (context, imageUrl, cacheKey) {
        final avatarIdentity =
            comment.id ?? comment.userId ?? comment.nickname ?? 'anonymous';
        return TagCircleAvatar(
          key: ValueKey<String>('avatar_$avatarIdentity'),
          imageUrl: imageUrl,
          size: size,
          showBorder: isSelected,
          borderColor: Colors.white,
          cacheKey: cacheKey,
        );
      },
    );
  }

  static Widget buildPendingMarkerAvatar(
    BuildContext context,
    TagPendingMarker marker,
    double size,
    double? progress,
  ) {
    final currentUserId = context.read<UserController?>()?.currentUserId;

    return CurrentUserImageBuilder(
      imageKind: CurrentUserImageKind.profile,
      targetUserId: currentUserId,
      builder: (context, imageUrl, cacheKey) {
        return TagPendingProgressAvatar(
          imageUrl: imageUrl,
          cacheKey: cacheKey,
          size: size,
          progress: progress,
          opacity: 0.85,
          tagPadding: TagProfileTagSpec.padding,
          tagBackgroundColor: const Color(0xFF595959),
        );
      },
    );
  }

  static String? _normalize(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static bool _isAbsoluteUrl(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) {
      return false;
    }

    final uri = Uri.tryParse(normalized);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }
}
