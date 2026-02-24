import 'dart:async';

import 'package:flutter/material.dart';

import '../../../api/models/comment.dart';
import '../about_voice_comment/pending_api_voice_comment.dart';
import 'comment_audio_recording_bottom_sheet_widget.dart';
import 'comment_camera_recording_bottom_sheet_widget.dart';
import 'comment_base_bar_widget.dart';
import 'comment_profile_tag_widget.dart';
import 'comment_save_payload.dart';
import 'comment_text_input_widget.dart';

enum _CommentComposerMode { base, typing, placing }

class CommentComposerV2Widget extends StatefulWidget {
  final int postId;
  final Map<int, PendingApiCommentDraft> pendingCommentDrafts;
  final Future<void> Function(int postId, String text) onTextCommentCompleted;
  final Future<void> Function(
    int postId,
    String audioPath,
    List<double> waveformData,
    int durationMs,
  )
  onAudioCommentCompleted;
  final Future<void> Function(int postId, String localFilePath, bool isVideo)
  onMediaCommentCompleted;
  final FutureOr<Offset?> Function(int postId) resolveDropRelativePosition;
  final void Function(int postId, double progress) onCommentSaveProgress;
  final void Function(int postId, Comment comment) onCommentSaveSuccess;
  final void Function(int postId, Object error) onCommentSaveFailure;
  final ValueChanged<bool>? onTextFieldFocusChanged;
  final VoidCallback? onCameraPressed;
  final VoidCallback? onMicPressed;

  const CommentComposerV2Widget({
    super.key,
    required this.postId,
    required this.pendingCommentDrafts,
    required this.onTextCommentCompleted,
    required this.onAudioCommentCompleted,
    required this.onMediaCommentCompleted,
    required this.resolveDropRelativePosition,
    required this.onCommentSaveProgress,
    required this.onCommentSaveSuccess,
    required this.onCommentSaveFailure,
    this.onTextFieldFocusChanged,
    this.onCameraPressed,
    this.onMicPressed,
  });

  @override
  State<CommentComposerV2Widget> createState() =>
      _CommentComposerV2WidgetState();
}

class _CommentComposerV2WidgetState extends State<CommentComposerV2Widget> {
  _CommentComposerMode _mode = _CommentComposerMode.base;

  void _showTyping() {
    setState(() {
      _mode = _CommentComposerMode.typing;
    });
  }

  CommentSavePayload? _buildPayloadFromDraft() {
    final draft = widget.pendingCommentDrafts[widget.postId];
    if (draft == null) {
      return null;
    }

    if (draft.isTextComment) {
      return CommentSavePayload(
        postId: widget.postId,
        userId: draft.recorderUserId,
        kind: CommentDraftKind.text,
        text: draft.text,
        profileImageUrlKey: draft.profileImageUrlKey,
      );
    }

    if ((draft.audioPath ?? '').isNotEmpty) {
      return CommentSavePayload(
        postId: widget.postId,
        userId: draft.recorderUserId,
        kind: CommentDraftKind.audio,
        audioPath: draft.audioPath,
        waveformData: draft.waveformData,
        duration: draft.duration,
        profileImageUrlKey: draft.profileImageUrlKey,
      );
    }

    if ((draft.mediaPath ?? '').isNotEmpty) {
      return CommentSavePayload(
        postId: widget.postId,
        userId: draft.recorderUserId,
        kind: draft.isVideo == true
            ? CommentDraftKind.video
            : CommentDraftKind.image,
        localFilePath: draft.mediaPath,
        profileImageUrlKey: draft.profileImageUrlKey,
      );
    }

    return null;
  }

  Future<void> _handleTextSubmit(String text) async {
    await widget.onTextCommentCompleted(widget.postId, text);
    if (!mounted) {
      return;
    }

    setState(() {
      _mode = _CommentComposerMode.placing;
    });
    widget.onTextFieldFocusChanged?.call(false);
  }

  Future<void> _handleCameraPressed() async {
    widget.onCameraPressed?.call();

    final result = await showModalBottomSheet<CommentCameraSheetResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const CommentCameraRecordingBottomSheetWidget(),
    );

    if (!mounted || result == null) {
      return;
    }

    await widget.onMediaCommentCompleted(
      widget.postId,
      result.localFilePath,
      result.isVideo,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _mode = _CommentComposerMode.placing;
    });
    widget.onTextFieldFocusChanged?.call(false);
  }

  Future<void> _handleMicPressed() async {
    widget.onMicPressed?.call();

    final result = await showModalBottomSheet<CommentAudioSheetResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const CommentAudioRecordingBottomSheetWidget(),
    );

    if (!mounted || result == null) {
      return;
    }

    await widget.onAudioCommentCompleted(
      widget.postId,
      result.audioPath,
      result.waveformData,
      result.durationMs,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _mode = _CommentComposerMode.placing;
    });
    widget.onTextFieldFocusChanged?.call(false);
  }

  void _handleTextFocusChanged(bool isFocused) {
    widget.onTextFieldFocusChanged?.call(isFocused);
  }

  void _handleTypingCancelled() {
    if (!mounted) {
      return;
    }
    setState(() {
      _mode = _CommentComposerMode.base;
    });
    widget.onTextFieldFocusChanged?.call(false);
  }

  FutureOr<Offset?> _resolveDropPosition() {
    return widget.resolveDropRelativePosition(widget.postId);
  }

  void _handleSaveSuccess(Comment comment) {
    widget.onCommentSaveSuccess(widget.postId, comment);
    if (!mounted) {
      return;
    }
    setState(() {
      _mode = _CommentComposerMode.base;
    });
  }

  void _handleSaveFailure(Object error) {
    widget.onCommentSaveFailure(widget.postId, error);
    if (!mounted) {
      return;
    }
    setState(() {
      _mode = _CommentComposerMode.placing;
    });
  }

  Widget _buildPlacingMode() {
    final payload = _buildPayloadFromDraft();

    if (payload == null) {
      return CommentBaseBarWidget(
        onCenterTap: _showTyping,
        onCameraPressed: _handleCameraPressed,
        onMicPressed: _handleMicPressed,
      );
    }

    return Align(
      alignment: Alignment.center,
      child: CommentProfileTagWidget(
        payload: payload,
        resolveDropRelativePosition: _resolveDropPosition,
        onSaveProgress: (progress) {
          widget.onCommentSaveProgress(widget.postId, progress);
        },
        onSaveSuccess: _handleSaveSuccess,
        onSaveFailure: _handleSaveFailure,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    late final Widget child;

    switch (_mode) {
      case _CommentComposerMode.base:
        child = CommentBaseBarWidget(
          onCenterTap: _showTyping,
          onCameraPressed: _handleCameraPressed,
          onMicPressed: _handleMicPressed,
        );
        break;
      case _CommentComposerMode.typing:
        child = CommentTextInputWidget(
          onSubmitText: _handleTextSubmit,
          onFocusChanged: _handleTextFocusChanged,
          onEditingCancelled: _handleTypingCancelled,
        );
        break;
      case _CommentComposerMode.placing:
        child = _buildPlacingMode();
        break;
    }

    return SizedBox(
      width: 353,
      height: 52,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (widget, animation) {
          return FadeTransition(opacity: animation, child: widget);
        },
        child: KeyedSubtree(key: ValueKey(_mode.name), child: child),
      ),
    );
  }
}
