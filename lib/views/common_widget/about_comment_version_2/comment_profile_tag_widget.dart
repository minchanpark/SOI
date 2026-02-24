import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/media_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/comment.dart';
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
        case CommentDraftKind.image:
        case CommentDraftKind.video:
          throw UnsupportedError('V2 1차에서는 텍스트 댓글만 저장할 수 있습니다.');
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
