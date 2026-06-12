import 'package:tagging_core/tagging_core.dart';

import '../../api/models/comment.dart';
import 'soi_tagging_metadata.dart';

typedef TagComment = TagEntry;

/// SOI 화면이 core 엔트리를 기존 댓글 모델처럼 읽을 수 있게 metadata 해석을 제공합니다.
extension SoiTagEntryX on TagEntry {
  int? get userId => _intMetadata(SoiTaggingMetadata.userId);

  String? get nickname => _stringMetadata(SoiTaggingMetadata.nickname);

  String? get replyUserName =>
      _stringMetadata(SoiTaggingMetadata.replyUserName);

  String? get userProfileUrl =>
      _stringMetadata(SoiTaggingMetadata.userProfileUrl);

  String? get userProfileKey =>
      _stringMetadata(SoiTaggingMetadata.userProfileKey);

  String? get fileUrl => _stringMetadata(SoiTaggingMetadata.fileUrl);

  String? get fileKey {
    final stored = _stringMetadata(SoiTaggingMetadata.fileKey);
    if ((stored ?? '').trim().isNotEmpty) {
      return stored;
    }

    final reference = content.reference?.trim();
    if (reference == null || reference.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(reference);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return null;
    }
    return reference;
  }

  int? get replyCommentCount =>
      _intMetadata(SoiTaggingMetadata.replyCommentCount);

  String? get text => content.text;

  int? get emojiId => _intMetadata(SoiTaggingMetadata.emojiId);

  String? get audioUrl => _stringMetadata(SoiTaggingMetadata.audioUrl);

  String? get waveformData =>
      _stringMetadata(SoiTaggingMetadata.waveformData);

  int? get duration => _intMetadata(SoiTaggingMetadata.duration);

  double? get locationX => anchor?.x;

  double? get locationY => anchor?.y;

  String? get threadParentId => parentEntryId;

  CommentType get soiCommentType {
    final raw = _stringMetadata(SoiTaggingMetadata.commentType);
    switch (raw) {
      case 'audio':
        return CommentType.audio;
      case 'photo':
        return CommentType.photo;
      case 'video':
        return CommentType.video;
      case 'reply':
        return CommentType.reply;
      case 'text':
      default:
        return content.isAudio
            ? CommentType.audio
            : content.isImage
            ? CommentType.photo
            : content.isVideo
            ? CommentType.video
            : CommentType.text;
    }
  }

  bool get hasMediaAttachment {
    final reference = content.reference?.trim() ?? '';
    if (reference.isNotEmpty) {
      return true;
    }
    return (fileUrl ?? '').trim().isNotEmpty || (fileKey ?? '').trim().isNotEmpty;
  }

  String? _stringMetadata(String key) {
    final value = metadata[key];
    if (value is String) {
      final normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    }
    return null;
  }

  int? _intMetadata(String key) {
    final value = metadata[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}

/// SOI 화면이 core draft를 기존 입력 흐름에 맞게 읽도록 보조 getter를 제공합니다.
extension SoiTagDraftX on TagDraft {
  bool get isTextComment => content.isText;

  bool get isAudioComment => content.isAudio;

  bool get isImageComment => content.isImage;

  bool get isVideoComment => content.isVideo;

  String? get text => content.text;

  String? get audioPath => content.isAudio ? content.reference : null;

  String? get mediaPath =>
      content.isImage || content.isVideo ? content.reference : null;

  List<double>? get waveformData => content.waveformSamples;

  int? get durationMs => content.durationMs;

  String get recorderUserId => actorId;

  String? get profileImageSource {
    final value = metadata[SoiTaggingMetadata.profileImageSource];
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

/// 태그 드래프트에 필요한 최소 작성자 식별 정보만 묶어 전달합니다.
class TagAuthor {
  const TagAuthor({required this.id, this.handle, this.profileImageSource});

  final TagEntityId id;
  final String? handle;
  final String? profileImageSource;
}
