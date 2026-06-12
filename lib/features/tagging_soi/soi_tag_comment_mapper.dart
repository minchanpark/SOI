import 'package:tagging_core/tagging_core.dart';

import '../../api/models/comment.dart';
import 'soi_tag_entry_extensions.dart';
import 'soi_tagging_ids.dart';
import 'soi_tagging_metadata.dart';

/// SOI Comment 모델과 tagging_core 모델 사이의 변환을 전담합니다.
class SoiTagCommentMapper {
  const SoiTagCommentMapper._();

  static TagEntry fromComment(Comment comment, {required TagScopeId scopeId}) {
    final content = _contentFromComment(comment);
    return TagEntry(
      id: SoiTaggingIds.entityIdFromInt(comment.id),
      scopeId: scopeId,
      actorId: SoiTaggingIds.entityIdFromInt(comment.userId) ?? 'unknown_actor',
      parentEntryId: SoiTaggingIds.entityIdFromInt(comment.threadParentId),
      anchor: _anchorFromComment(comment),
      createdAt: comment.createdAt,
      content: content,
      metadata: _metadataFromComment(comment),
    );
  }

  static List<TagEntry> fromComments(
    List<Comment> comments, {
    required TagScopeId scopeId,
  }) {
    return comments
        .map((comment) => fromComment(comment, scopeId: scopeId))
        .toList(growable: false);
  }

  static Comment toComment(TagEntry comment) {
    return Comment(
      id: SoiTaggingIds.intFromEntityId(comment.id),
      threadParentId: SoiTaggingIds.intFromEntityId(comment.threadParentId),
      userId: comment.userId ?? SoiTaggingIds.intFromEntityId(comment.actorId),
      nickname: comment.nickname,
      replyUserName: comment.replyUserName,
      userProfileUrl: comment.userProfileUrl,
      userProfileKey: comment.userProfileKey,
      fileUrl: comment.fileUrl,
      fileKey: comment.fileKey,
      createdAt: comment.createdAt,
      replyCommentCount: comment.replyCommentCount,
      text: comment.text,
      emojiId: comment.emojiId,
      audioUrl: comment.audioUrl,
      waveformData: comment.waveformData,
      duration: comment.duration,
      locationX: comment.locationX,
      locationY: comment.locationY,
      type: comment.soiCommentType,
    );
  }

  static List<Comment> toComments(List<TagEntry> comments) {
    return comments.map(toComment).toList(growable: false);
  }

  static TagContent _contentFromComment(Comment comment) {
    switch (comment.type) {
      case CommentType.audio:
        return TagContent.audio(
          reference: comment.audioUrl,
          durationMs: comment.duration,
          metadata: <String, Object?>{
            SoiTaggingMetadata.waveformData: comment.waveformData,
          },
        );
      case CommentType.photo:
        return TagContent.image(reference: comment.fileUrl ?? comment.fileKey);
      case CommentType.video:
        return TagContent.video(reference: comment.fileUrl ?? comment.fileKey);
      case CommentType.reply:
      case CommentType.text:
        return TagContent.text(comment.text ?? '');
    }
  }

  static TagPosition? _anchorFromComment(Comment comment) {
    if (comment.locationX == null || comment.locationY == null) {
      return null;
    }
    return TagPosition(x: comment.locationX!, y: comment.locationY!);
  }

  static Map<String, Object?> _metadataFromComment(Comment comment) {
    return <String, Object?>{
      SoiTaggingMetadata.commentType: _commentTypeName(comment.type),
      SoiTaggingMetadata.userId: comment.userId,
      SoiTaggingMetadata.nickname: comment.nickname,
      SoiTaggingMetadata.replyUserName: comment.replyUserName,
      SoiTaggingMetadata.userProfileUrl: comment.userProfileUrl,
      SoiTaggingMetadata.userProfileKey: comment.userProfileKey,
      SoiTaggingMetadata.fileUrl: comment.fileUrl,
      SoiTaggingMetadata.fileKey: comment.fileKey,
      SoiTaggingMetadata.replyCommentCount: comment.replyCommentCount,
      SoiTaggingMetadata.emojiId: comment.emojiId,
      SoiTaggingMetadata.audioUrl: comment.audioUrl,
      SoiTaggingMetadata.waveformData: comment.waveformData,
      SoiTaggingMetadata.duration: comment.duration,
    };
  }

  static String _commentTypeName(CommentType type) {
    switch (type) {
      case CommentType.audio:
        return 'audio';
      case CommentType.photo:
        return 'photo';
      case CommentType.video:
        return 'video';
      case CommentType.reply:
        return 'reply';
      case CommentType.text:
        return 'text';
    }
  }
}
