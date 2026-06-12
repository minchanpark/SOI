import 'dart:io';

import 'package:tagging_core/tagging_core.dart';

import '../../api/controller/comment_controller.dart';
import '../../api/controller/media_controller.dart';
import '../../api/media_processing/waveform_codec.dart';
import '../../api/models/comment.dart';
import '../../api/services/media_service.dart';
import 'soi_tag_comment_mapper.dart';
import 'soi_tagging_ids.dart';
import 'soi_tagging_metadata.dart';

/// SOI의 댓글/미디어 컨트롤러를 이용해 core 저장 요청을 서버 댓글 저장으로 변환합니다.
class SoiTaggingSaveDelegate implements TagMutationPort {
  const SoiTaggingSaveDelegate({
    required CommentController commentController,
    required MediaController mediaController,
  }) : _commentController = commentController,
       _mediaController = mediaController;

  static const int _kMaxWaveformSamples = 30;
  static const int _kSavedCommentLookupAttempts = 4;
  static const Duration _kSavedCommentLookupDelay = Duration(milliseconds: 180);
  static final WaveformCodec _waveformCodec = WaveformCodec();

  final CommentController _commentController;
  final MediaController _mediaController;

  @override
  Future<TagMutationResult> save({
    required TagSaveRequest request,
    void Function(double progress)? onProgress,
  }) async {
    final validationError = request.validateForSave();
    if (validationError != null) {
      throw StateError(validationError.name);
    }

    switch (request.content.type) {
      case TagContentType.text:
        return _saveTextComment(request, onProgress);
      case TagContentType.audio:
        return _saveAudioComment(request, onProgress);
      case TagContentType.image:
      case TagContentType.video:
        return _saveMediaComment(request, onProgress);
    }
  }

  Future<TagMutationResult> _saveTextComment(
    TagSaveRequest request,
    void Function(double progress)? onProgress,
  ) async {
    final postId = SoiTaggingIds.postIdFromScopeId(request.scopeId);
    final userId = SoiTaggingIds.requiredIntFromEntityId(
      request.actorId,
      fieldName: 'actorId',
    );
    onProgress?.call(0.45);
    final result = await _commentController.createComment(
      postId: postId,
      userId: userId,
      parentId: SoiTaggingIds.intFromEntityId(request.parentEntryId) ?? 0,
      replyUserId: _replyUserId(request),
      text: request.content.text,
      locationX: request.anchor?.x,
      locationY: request.anchor?.y,
      type: CommentType.text,
    );
    onProgress?.call(0.9);

    if (!result.success) {
      throw StateError('댓글 저장에 실패했습니다.');
    }

    final comment = await _resolvePersistedComment(
      request: request,
      directComment: result.comment,
      matcher: (comments) => _findSavedTextComment(comments, request),
    );
    return TagMutationResult(
      entry: SoiTagCommentMapper.fromComment(
        comment,
        scopeId: request.scopeId,
      ),
    );
  }

  Future<TagMutationResult> _saveAudioComment(
    TagSaveRequest request,
    void Function(double progress)? onProgress,
  ) async {
    final postId = SoiTaggingIds.postIdFromScopeId(request.scopeId);
    final userId = SoiTaggingIds.requiredIntFromEntityId(
      request.actorId,
      fieldName: 'actorId',
    );
    final audioPath = (request.content.reference ?? '').trim();
    if (audioPath.isEmpty) {
      throw StateError('오디오 경로가 없습니다.');
    }

    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw StateError('오디오 파일을 찾을 수 없습니다.');
    }

    onProgress?.call(0.15);
    final multipartFile = await _mediaController.fileToMultipart(audioFile);
    onProgress?.call(0.35);
    final audioKey = await _mediaController.uploadCommentAudio(
      file: multipartFile,
      userId: userId,
      postId: postId,
    );
    if (audioKey == null || audioKey.isEmpty) {
      throw StateError('오디오 업로드에 실패했습니다.');
    }

    final waveformJson = _waveformCodec.encodeOrEmpty(
      request.content.waveformSamples,
      maxSamples: _kMaxWaveformSamples,
    );

    onProgress?.call(0.82);
    final result = await _commentController.createComment(
      postId: postId,
      userId: userId,
      parentId: SoiTaggingIds.intFromEntityId(request.parentEntryId) ?? 0,
      replyUserId: _replyUserId(request),
      audioKey: audioKey,
      waveformData: waveformJson,
      duration: request.content.durationMs,
      locationX: request.anchor?.x,
      locationY: request.anchor?.y,
      type: CommentType.audio,
    );
    onProgress?.call(0.95);

    if (!result.success) {
      throw StateError('댓글 저장에 실패했습니다.');
    }

    final comment = await _resolvePersistedComment(
      request: request,
      directComment: result.comment,
      matcher: (comments) => _findSavedAudioComment(comments, request),
    );
    return TagMutationResult(
      entry: SoiTagCommentMapper.fromComment(
        comment,
        scopeId: request.scopeId,
      ),
    );
  }

  Future<TagMutationResult> _saveMediaComment(
    TagSaveRequest request,
    void Function(double progress)? onProgress,
  ) async {
    final postId = SoiTaggingIds.postIdFromScopeId(request.scopeId);
    final userId = SoiTaggingIds.requiredIntFromEntityId(
      request.actorId,
      fieldName: 'actorId',
    );
    final localFilePath = (request.content.reference ?? '').trim();
    if (localFilePath.isEmpty) {
      throw StateError('미디어 경로가 없습니다.');
    }

    final mediaFile = File(localFilePath);
    if (!await mediaFile.exists()) {
      throw StateError('미디어 파일을 찾을 수 없습니다.');
    }

    onProgress?.call(0.18);
    final multipartFile = await _mediaController.fileToMultipart(mediaFile);
    final mediaType = request.content.type == TagContentType.video
        ? MediaType.video
        : MediaType.image;
    final uploadedKeys = await _mediaController.uploadMedia(
      files: [multipartFile],
      types: [mediaType],
      usageTypes: [MediaUsageType.comment],
      userId: userId,
      refId: postId,
      usageCount: 1,
    );
    if (uploadedKeys.isEmpty || uploadedKeys.first.isEmpty) {
      throw StateError('미디어 업로드에 실패했습니다.');
    }

    final fileKey = uploadedKeys.first;
    onProgress?.call(0.84);
    final result = await _commentController.createComment(
      postId: postId,
      userId: userId,
      parentId: SoiTaggingIds.intFromEntityId(request.parentEntryId) ?? 0,
      replyUserId: _replyUserId(request),
      fileKey: fileKey,
      locationX: request.anchor?.x,
      locationY: request.anchor?.y,
      type: request.content.type == TagContentType.video
          ? CommentType.video
          : CommentType.photo,
    );
    onProgress?.call(0.95);

    if (!result.success) {
      throw StateError('댓글 저장에 실패했습니다.');
    }

    final comment = await _resolvePersistedComment(
      request: request,
      directComment: result.comment,
      matcher: (comments) => _findSavedMediaComment(comments, request, fileKey),
    );
    return TagMutationResult(
      entry: SoiTagCommentMapper.fromComment(
        comment,
        scopeId: request.scopeId,
      ),
    );
  }

  Future<Comment> _resolvePersistedComment({
    required TagSaveRequest request,
    required Comment? directComment,
    required Comment? Function(List<Comment> comments) matcher,
  }) async {
    final postId = SoiTaggingIds.postIdFromScopeId(request.scopeId);
    final persistedDirect = _persistedCommentOrNull(directComment);
    if (persistedDirect != null) {
      return persistedDirect;
    }

    for (var attempt = 0; attempt < _kSavedCommentLookupAttempts; attempt++) {
      final comments = await _commentController.getComments(postId: postId);
      final matched = _persistedCommentOrNull(matcher(comments));
      if (matched != null) {
        return matched;
      }
      if (attempt < _kSavedCommentLookupAttempts - 1) {
        await Future<void>.delayed(_kSavedCommentLookupDelay);
      }
    }

    throw StateError('저장된 댓글의 id/userId를 확인하지 못했습니다.');
  }

  Comment? _persistedCommentOrNull(Comment? comment) {
    if (comment == null || comment.id == null || comment.userId == null) {
      return null;
    }
    return comment;
  }

  Comment? _findSavedTextComment(
    List<Comment> comments,
    TagSaveRequest request,
  ) {
    final trimmedText = (request.content.text ?? '').trim();
    final userId = SoiTaggingIds.intFromEntityId(request.actorId);
    if (trimmedText.isEmpty) {
      return null;
    }

    for (final comment in comments.reversed) {
      if (!comment.isText || comment.userId != userId) {
        continue;
      }

      final matchesX = _isNearCoordinate(comment.locationX, request.anchor?.x);
      final matchesY = _isNearCoordinate(comment.locationY, request.anchor?.y);
      final sameText = (comment.text ?? '').trim() == trimmedText;
      if (matchesX && matchesY && sameText) {
        return comment;
      }
    }

    return null;
  }

  Comment? _findSavedAudioComment(
    List<Comment> comments,
    TagSaveRequest request,
  ) {
    final expectedDuration = request.content.durationMs ?? 0;
    final userId = SoiTaggingIds.intFromEntityId(request.actorId);

    for (final comment in comments.reversed) {
      if (!comment.isAudio || comment.userId != userId) {
        continue;
      }

      final matchesX = _isNearCoordinate(comment.locationX, request.anchor?.x);
      final matchesY = _isNearCoordinate(comment.locationY, request.anchor?.y);
      final matchesDuration =
          expectedDuration <= 0 ||
          comment.duration == null ||
          comment.duration == expectedDuration;
      if (matchesX && matchesY && matchesDuration) {
        return comment;
      }
    }

    return null;
  }

  Comment? _findSavedMediaComment(
    List<Comment> comments,
    TagSaveRequest request,
    String fileKey,
  ) {
    final userId = SoiTaggingIds.intFromEntityId(request.actorId);
    for (final comment in comments.reversed) {
      if (comment.userId != userId) {
        continue;
      }

      if ((comment.fileKey ?? '').trim() == fileKey) {
        return comment;
      }

      final isMediaComment = comment.isPhoto || comment.isVideo;
      if (!isMediaComment) {
        continue;
      }

      final matchesX = _isNearCoordinate(comment.locationX, request.anchor?.x);
      final matchesY = _isNearCoordinate(comment.locationY, request.anchor?.y);
      if (matchesX && matchesY) {
        return comment;
      }
    }

    return null;
  }

  bool _isNearCoordinate(double? lhs, double? rhs) {
    if (lhs == null || rhs == null) {
      return false;
    }
    return (lhs - rhs).abs() <= 0.0001;
  }

  int _replyUserId(TagSaveRequest request) {
    final rawValue = request.metadata[SoiTaggingMetadata.replyUserId];
    if (rawValue is String) {
      return SoiTaggingIds.intFromEntityId(rawValue) ?? 0;
    }
    return 0;
  }
}
