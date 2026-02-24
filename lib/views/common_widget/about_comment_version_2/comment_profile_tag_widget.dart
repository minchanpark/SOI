import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/media_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/comment.dart';
import '../../../api/services/media_service.dart';
import '../api_photo/tag_pointer.dart';
import 'comment_save_payload.dart';

class CommentProfileTagWidget extends StatefulWidget {
  final CommentSavePayload payload;
  final FutureOr<Offset?> Function() resolveDropRelativePosition;
  final ValueChanged<double>? onSaveProgress;
  final ValueChanged<Comment>? onSaveSuccess;
  final ValueChanged<Object>? onSaveFailure;
  final VoidCallback? onDropCancelled;
  final String dragData;
  final double avatarSize;

  const CommentProfileTagWidget({
    super.key,
    required this.payload,
    required this.resolveDropRelativePosition,
    this.onSaveProgress,
    this.onSaveSuccess,
    this.onSaveFailure,
    this.onDropCancelled,
    this.dragData = 'profile_image',
    this.avatarSize = 27,
  });

  @override
  State<CommentProfileTagWidget> createState() =>
      _CommentProfileTagWidgetState();
}

class _CommentProfileTagWidgetState extends State<CommentProfileTagWidget> {
  static const int _kMaxWaveformSamples = 30;
  bool _isSaving = false;
  double _progress = 0.0;
  late Future<String?> _profileImageFuture;

  @override
  void initState() {
    super.initState();
    _profileImageFuture = _resolveProfileImageUrl(
      widget.payload.profileImageUrlKey,
    );
  }

  @override
  void didUpdateWidget(covariant CommentProfileTagWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payload.profileImageUrlKey !=
        widget.payload.profileImageUrlKey) {
      _profileImageFuture = _resolveProfileImageUrl(
        widget.payload.profileImageUrlKey,
      );
    }
  }

  Future<String?> _resolveProfileImageUrl(String? source) async {
    if (source == null || source.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(source);
    if (uri != null && uri.hasScheme) {
      return source;
    }

    try {
      final mediaController = context.read<MediaController>();
      return await mediaController.getPresignedUrl(source) ?? source;
    } catch (_) {
      return source;
    }
  }

  Offset _tagPointerDragAnchor(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) {
    return TagBubble.pointerTipOffset(contentSize: widget.avatarSize);
  }

  void _updateProgress(double value) {
    _progress = value.clamp(0.0, 1.0).toDouble();
    widget.onSaveProgress?.call(_progress);
  }

  Future<Comment> _saveTextComment(CommentSavePayload payload) async {
    final commentController = context.read<CommentController>();
    final currentUser = context.read<UserController>().currentUser;
    String? resolvedProfileUrl;
    try {
      resolvedProfileUrl = await _profileImageFuture;
    } catch (_) {
      resolvedProfileUrl = null;
    }

    _updateProgress(0.45);
    final result = await commentController.createComment(
      postId: payload.postId,
      userId: payload.userId,
      parentId: payload.parentId ?? 0,
      replyUserId: payload.replyUserId ?? 0,
      text: payload.text,
      locationX: payload.locationX,
      locationY: payload.locationY,
      type: CommentType.text,
    );

    _updateProgress(0.9);

    if (!result.success) {
      throw StateError('댓글 저장에 실패했습니다.');
    }

    if (result.comment != null) {
      return result.comment!;
    }

    return payload.toFallbackComment(
      nickname: currentUser?.userId,
      userProfileUrl: resolvedProfileUrl ?? currentUser?.profileImageUrlKey,
    );
  }

  Future<Comment> _saveAudioComment(CommentSavePayload payload) async {
    final commentController = context.read<CommentController>();
    final mediaController = context.read<MediaController>();
    final currentUser = context.read<UserController>().currentUser;

    String? resolvedProfileUrl;
    try {
      resolvedProfileUrl = await _profileImageFuture;
    } catch (_) {
      resolvedProfileUrl = null;
    }

    final audioPath = (payload.audioPath ?? '').trim();
    if (audioPath.isEmpty) {
      throw StateError('오디오 경로가 없습니다.');
    }

    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw StateError('녹음 파일을 찾을 수 없습니다.');
    }

    _updateProgress(0.2);
    final multipartFile = await mediaController.fileToMultipart(audioFile);

    _updateProgress(0.45);
    final audioKey = await mediaController.uploadCommentAudio(
      file: multipartFile,
      userId: payload.userId,
      postId: payload.postId,
    );

    if (audioKey == null || audioKey.isEmpty) {
      throw StateError('음성 업로드에 실패했습니다.');
    }

    _updateProgress(0.65);
    final result = await commentController.createAudioComment(
      postId: payload.postId,
      userId: payload.userId,
      audioFileKey: audioKey,
      waveformData: _encodeWaveformForRequest(payload.waveformData),
      duration: payload.duration ?? 0,
      locationX: payload.locationX ?? 0.0,
      locationY: payload.locationY ?? 0.0,
    );

    _updateProgress(0.9);

    if (!result.success) {
      throw StateError('음성 댓글 저장에 실패했습니다.');
    }

    if (result.comment != null) {
      return result.comment!;
    }

    final refreshedComment = await _findSavedAudioComment(payload);
    if (refreshedComment != null) {
      return refreshedComment;
    }

    return payload.toFallbackComment(
      nickname: currentUser?.userId,
      userProfileUrl: resolvedProfileUrl ?? currentUser?.profileImageUrlKey,
    );
  }

  Future<Comment?> _findSavedAudioComment(CommentSavePayload payload) async {
    final commentController = context.read<CommentController>();
    final comments = await commentController.getComments(
      postId: payload.postId,
    );

    for (final comment in comments.reversed) {
      if (!comment.isAudio || comment.userId != payload.userId) {
        continue;
      }

      final matchesX = _isNearCoordinate(comment.locationX, payload.locationX);
      final matchesY = _isNearCoordinate(comment.locationY, payload.locationY);
      if (matchesX && matchesY) {
        return comment;
      }
    }

    for (final comment in comments.reversed) {
      if (comment.isAudio && comment.userId == payload.userId) {
        return comment;
      }
    }

    return null;
  }

  Future<Comment> _saveMediaComment(CommentSavePayload payload) async {
    final commentController = context.read<CommentController>();
    final mediaController = context.read<MediaController>();
    final currentUser = context.read<UserController>().currentUser;

    String? resolvedProfileUrl;
    try {
      resolvedProfileUrl = await _profileImageFuture;
    } catch (_) {
      resolvedProfileUrl = null;
    }

    final localFilePath = (payload.localFilePath ?? '').trim();
    if (localFilePath.isEmpty) {
      throw StateError('미디어 경로가 없습니다.');
    }

    final mediaFile = File(localFilePath);
    if (!await mediaFile.exists()) {
      throw StateError('미디어 파일을 찾을 수 없습니다.');
    }

    _updateProgress(0.2);
    final multipartFile = await mediaController.fileToMultipart(mediaFile);

    final mediaType = payload.kind == CommentDraftKind.video
        ? MediaType.video
        : MediaType.image;
    _updateProgress(0.45);
    final keys = await mediaController.uploadMedia(
      files: [multipartFile],
      types: [mediaType],
      usageTypes: [MediaUsageType.comment],
      userId: payload.userId,
      refId: payload.postId,
      usageCount: 1,
    );

    final fileKey = keys.isEmpty ? null : keys.first;
    if (fileKey == null || fileKey.isEmpty) {
      throw StateError('미디어 업로드에 실패했습니다.');
    }

    _updateProgress(0.7);
    final result = await commentController.createComment(
      postId: payload.postId,
      userId: payload.userId,
      parentId: payload.parentId ?? 0,
      replyUserId: payload.replyUserId ?? 0,
      fileKey: fileKey,
      locationX: payload.locationX,
      locationY: payload.locationY,
      type: CommentType.photo,
    );
    _updateProgress(0.9);

    if (!result.success) {
      throw StateError('미디어 댓글 저장에 실패했습니다.');
    }

    if (result.comment != null) {
      return result.comment!;
    }

    final refreshed = await _findSavedMediaComment(payload, fileKey);
    if (refreshed != null) {
      return refreshed;
    }

    final fallbackPayload = CommentSavePayload(
      postId: payload.postId,
      userId: payload.userId,
      kind: payload.kind,
      fileKey: fileKey,
      localFilePath: localFilePath,
      parentId: payload.parentId,
      replyUserId: payload.replyUserId,
      profileImageUrlKey: payload.profileImageUrlKey,
      locationX: payload.locationX,
      locationY: payload.locationY,
    );

    return fallbackPayload.toFallbackComment(
      nickname: currentUser?.userId,
      userProfileUrl: resolvedProfileUrl ?? currentUser?.profileImageUrlKey,
    );
  }

  Future<Comment?> _findSavedMediaComment(
    CommentSavePayload payload,
    String fileKey,
  ) async {
    final commentController = context.read<CommentController>();
    final comments = await commentController.getComments(
      postId: payload.postId,
    );

    for (final comment in comments.reversed) {
      if (!comment.isPhoto || comment.userId != payload.userId) {
        continue;
      }

      final sameFileKey = (comment.fileKey ?? '').trim() == fileKey;
      if (sameFileKey) {
        return comment;
      }

      final matchesX = _isNearCoordinate(comment.locationX, payload.locationX);
      final matchesY = _isNearCoordinate(comment.locationY, payload.locationY);
      if (matchesX && matchesY) {
        return comment;
      }
    }

    for (final comment in comments.reversed) {
      if (comment.isPhoto && comment.userId == payload.userId) {
        return comment;
      }
    }

    return null;
  }

  bool _isNearCoordinate(double? a, double? b) {
    if (a == null || b == null) {
      return false;
    }
    return (a - b).abs() <= 0.03;
  }

  String _encodeWaveformForRequest(List<double>? waveformData) {
    if (waveformData == null || waveformData.isEmpty) {
      return '';
    }
    final sampled = _sampleWaveformData(waveformData, _kMaxWaveformSamples);
    final rounded = sampled
        .map((value) => double.parse(value.toStringAsFixed(4)))
        .toList();
    return jsonEncode(rounded);
  }

  List<double> _sampleWaveformData(List<double> source, int maxLength) {
    if (source.length <= maxLength) {
      return source;
    }

    final step = source.length / maxLength;
    return List<double>.generate(
      maxLength,
      (index) => source[(index * step).floor()],
    );
  }

  Future<void> _handleDropAccepted() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    _updateProgress(0.05);

    try {
      final validationError = widget.payload.validateForSave();
      if (validationError != null) {
        throw StateError(validationError);
      }

      await Future<void>.delayed(Duration.zero);
      final relativePosition = await widget.resolveDropRelativePosition();
      if (relativePosition == null) {
        throw StateError('댓글 위치를 확인하지 못했습니다.');
      }

      final payloadWithLocation = widget.payload.copyWithLocation(
        locationX: relativePosition.dx,
        locationY: relativePosition.dy,
      );

      Comment savedComment;
      switch (payloadWithLocation.kind) {
        case CommentDraftKind.text:
          savedComment = await _saveTextComment(payloadWithLocation);
          break;
        case CommentDraftKind.audio:
          savedComment = await _saveAudioComment(payloadWithLocation);
          break;
        case CommentDraftKind.image:
        case CommentDraftKind.video:
          savedComment = await _saveMediaComment(payloadWithLocation);
          break;
      }

      _updateProgress(1.0);
      widget.onSaveSuccess?.call(savedComment);
    } catch (error) {
      _updateProgress(0.0);
      widget.onSaveFailure?.call(error);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildAvatar(String? imageUrl) {
    return SizedBox(
      width: widget.avatarSize,
      height: widget.avatarSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isSaving)
            SizedBox(
              width: widget.avatarSize,
              height: widget.avatarSize,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                backgroundColor: Colors.black.withValues(alpha: 0.3),
              ),
            ),
          ClipOval(
            child: imageUrl != null && imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: widget.avatarSize,
                    height: widget.avatarSize,
                    fit: BoxFit.cover,
                    memCacheWidth: (widget.avatarSize * 2).round(),
                    maxWidthDiskCache: (widget.avatarSize * 2).round(),
                    placeholder: (_, __) =>
                        Container(color: Colors.grey.shade700),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.red.shade700,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.error,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xffd9d9d9),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagBubble = FutureBuilder<String?>(
      future: _profileImageFuture,
      builder: (context, snapshot) {
        final imageUrl = snapshot.data ?? widget.payload.profileImageUrlKey;
        return TagBubble(
          contentSize: widget.avatarSize,
          child: _buildAvatar(imageUrl),
        );
      },
    );

    if (_isSaving) {
      return IgnorePointer(child: tagBubble);
    }

    return Draggable<String>(
      data: widget.dragData,
      dragAnchorStrategy: _tagPointerDragAnchor,
      feedback: Transform.scale(
        scale: 1.2,
        child: Opacity(opacity: 0.85, child: tagBubble),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tagBubble),
      onDragEnd: (details) {
        if (!details.wasAccepted) {
          widget.onDropCancelled?.call();
          return;
        }
        unawaited(_handleDropAccepted());
      },
      child: tagBubble,
    );
  }
}
