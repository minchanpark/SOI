import '../../../api/models/comment.dart';

enum CommentDraftKind { text, audio, image, video }

/// 댓글 저장에 필요한 공통 payload.
/// 1차에서는 text만 실제 저장하고 나머지는 인터페이스만 유지합니다.
class CommentSavePayload {
  final int postId;
  final int userId;
  final CommentDraftKind kind;

  final String? text;
  final String? audioPath;
  final List<double>? waveformData;
  final int? duration;
  final String? fileKey;
  final String? localFilePath;

  final int? parentId;
  final int? replyUserId;
  final String? profileImageUrlKey;

  final double? locationX;
  final double? locationY;

  const CommentSavePayload({
    required this.postId,
    required this.userId,
    required this.kind,
    this.text,
    this.audioPath,
    this.waveformData,
    this.duration,
    this.fileKey,
    this.localFilePath,
    this.parentId,
    this.replyUserId,
    this.profileImageUrlKey,
    this.locationX,
    this.locationY,
  });

  bool get isSupportedInV1 => kind == CommentDraftKind.text;

  CommentType get commentType {
    switch (kind) {
      case CommentDraftKind.text:
        return CommentType.text;
      case CommentDraftKind.audio:
        return CommentType.audio;
      case CommentDraftKind.image:
      case CommentDraftKind.video:
        // 서버 enum 제약상 video도 PHOTO 경로로 매핑
        return CommentType.photo;
    }
  }

  String? validateForSave() {
    if (postId <= 0) {
      return '유효하지 않은 postId';
    }
    if (userId <= 0) {
      return '유효하지 않은 userId';
    }

    switch (kind) {
      case CommentDraftKind.text:
        if ((text ?? '').trim().isEmpty) {
          return '텍스트 댓글 내용이 비어 있습니다.';
        }
        return null;
      case CommentDraftKind.audio:
        if ((audioPath ?? '').trim().isEmpty) {
          return '오디오 경로가 없습니다.';
        }
        return null;
      case CommentDraftKind.image:
      case CommentDraftKind.video:
        final hasFileKey = (fileKey ?? '').trim().isNotEmpty;
        final hasLocalPath = (localFilePath ?? '').trim().isNotEmpty;
        if (!hasFileKey && !hasLocalPath) {
          return '파일 정보가 없습니다.';
        }
        return null;
    }
  }

  CommentSavePayload copyWithLocation({
    required double locationX,
    required double locationY,
  }) {
    return CommentSavePayload(
      postId: postId,
      userId: userId,
      kind: kind,
      text: text,
      audioPath: audioPath,
      waveformData: waveformData,
      duration: duration,
      fileKey: fileKey,
      localFilePath: localFilePath,
      parentId: parentId,
      replyUserId: replyUserId,
      profileImageUrlKey: profileImageUrlKey,
      locationX: locationX,
      locationY: locationY,
    );
  }

  Comment toFallbackComment({String? nickname, String? userProfileUrl}) {
    final waveform = waveformData == null || waveformData!.isEmpty
        ? null
        : waveformData!.map((value) => value.toStringAsFixed(4)).join(',');

    return Comment(
      id: null,
      userId: userId,
      userProfileKey: profileImageUrlKey,
      text: text,
      fileKey: fileKey,
      audioUrl: audioPath,
      waveformData: waveform,
      duration: duration,
      locationX: locationX,
      locationY: locationY,
      type: commentType,
      replyUserName: null,
      nickname: nickname,
      userProfileUrl: userProfileUrl ?? profileImageUrlKey,
      fileUrl: null,
      emojiId: 0,
    );
  }
}
