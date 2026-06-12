import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tagging_core/tagging_core.dart';
import 'package:tagging_flutter/tagging_flutter.dart';

import 'soi_tag_base_bar_widget.dart';
import 'soi_tag_text_input_widget.dart';

enum _SoiTagComposerMode { base, typing, placing }

/// SOI 댓글 컴포저는 draft 작성, 미디어 선택, 드래그 저장 모드를 서비스 UX에 맞게 오케스트레이션합니다.
class SoiTagComposerWidget extends StatefulWidget {
  const SoiTagComposerWidget({
    super.key,
    required this.scopeId,
    required this.pendingDrafts,
    required this.mutationPort,
    required this.avatarBuilder,
    required this.resolveDropRelativePosition,
    required this.onTextDraftSubmitted,
    required this.basePlaceholderText,
    required this.textInputHintText,
    required this.cameraIcon,
    required this.micIcon,
    required this.onCommentSaveProgress,
    required this.onCommentSaveSuccess,
    required this.onCommentSaveFailure,
    this.onCameraDraftRequested,
    this.onAudioDraftRequested,
    this.onTextFieldFocusChanged,
    this.avatarSize = TagProfileTagSpec.avatarSize,
  });

  final TagScopeId scopeId;
  final Map<TagScopeId, TagDraft> pendingDrafts;
  final TagMutationPort mutationPort;
  final TagDragHandleBuilder avatarBuilder;
  final FutureOr<TagPosition?> Function(TagScopeId scopeId)
  resolveDropRelativePosition;
  final Future<void> Function(TagScopeId scopeId, String text)
  onTextDraftSubmitted;
  final Future<bool> Function(TagScopeId scopeId)? onCameraDraftRequested;
  final Future<bool> Function(TagScopeId scopeId)? onAudioDraftRequested;
  final String basePlaceholderText;
  final String textInputHintText;
  final Widget cameraIcon;
  final Widget micIcon;
  final void Function(TagScopeId scopeId, double progress)
  onCommentSaveProgress;
  final void Function(TagScopeId scopeId, TagEntry comment)
  onCommentSaveSuccess;
  final void Function(TagScopeId scopeId, Object error) onCommentSaveFailure;
  final ValueChanged<bool>? onTextFieldFocusChanged;
  final double avatarSize;

  @override
  State<SoiTagComposerWidget> createState() => _SoiTagComposerWidgetState();
}

/// 현재 scope draft를 저장 요청으로 바꾸고 모드 전환을 담당합니다.
class _SoiTagComposerWidgetState extends State<SoiTagComposerWidget> {
  _SoiTagComposerMode _mode = _SoiTagComposerMode.base;

  void _showTyping() {
    setState(() {
      _mode = _SoiTagComposerMode.typing;
    });
  }

  TagSaveRequest? _buildRequestFromDraft() {
    final draft = widget.pendingDrafts[widget.scopeId];
    if (draft == null) {
      return null;
    }

    return TagSaveRequest(
      scopeId: widget.scopeId,
      actorId: draft.actorId,
      content: draft.content,
      parentEntryId: draft.parentEntryId,
      metadata: draft.metadata,
    );
  }

  Future<void> _handleTextSubmit(String text) async {
    await widget.onTextDraftSubmitted(widget.scopeId, text);
    if (!mounted) {
      return;
    }

    setState(() {
      _mode = _SoiTagComposerMode.placing;
    });
    widget.onTextFieldFocusChanged?.call(false);
  }

  Future<void> _handleCameraPressed() async {
    final accepted = await widget.onCameraDraftRequested?.call(widget.scopeId);
    if (!mounted || accepted != true) {
      return;
    }

    setState(() {
      _mode = _SoiTagComposerMode.placing;
    });
    widget.onTextFieldFocusChanged?.call(false);
  }

  Future<void> _handleMicPressed() async {
    final accepted = await widget.onAudioDraftRequested?.call(widget.scopeId);
    if (!mounted || accepted != true) {
      return;
    }

    setState(() {
      _mode = _SoiTagComposerMode.placing;
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
      _mode = _SoiTagComposerMode.base;
    });
    widget.onTextFieldFocusChanged?.call(false);
  }

  FutureOr<TagPosition?> _resolveDropPosition() {
    return widget.resolveDropRelativePosition(widget.scopeId);
  }

  void _handleSaveSuccess(TagEntry comment) {
    widget.onCommentSaveSuccess(widget.scopeId, comment);
    if (!mounted) {
      return;
    }
    setState(() {
      _mode = _SoiTagComposerMode.base;
    });
  }

  void _handleSaveFailure(Object error) {
    widget.onCommentSaveFailure(widget.scopeId, error);
    if (!mounted) {
      return;
    }
    setState(() {
      _mode = _SoiTagComposerMode.placing;
    });
  }

  Widget _buildBaseBar() {
    return SoiTagBaseBarWidget(
      onCenterTap: _showTyping,
      placeholderText: widget.basePlaceholderText,
      cameraIcon: widget.cameraIcon,
      micIcon: widget.micIcon,
      onCameraPressed: _handleCameraPressed,
      onMicPressed: _handleMicPressed,
    );
  }

  Widget _buildPlacingMode() {
    final request = _buildRequestFromDraft();
    if (request == null) {
      return _buildBaseBar();
    }

    return Align(
      alignment: Alignment.center,
      child: TagDragHandle(
        request: request,
        mutationPort: widget.mutationPort,
        handleBuilder: widget.avatarBuilder,
        avatarSize: widget.avatarSize,
        resolveDropRelativePosition: _resolveDropPosition,
        onSaveProgress: (progress) {
          widget.onCommentSaveProgress(widget.scopeId, progress);
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
      case _SoiTagComposerMode.base:
        child = _buildBaseBar();
      case _SoiTagComposerMode.typing:
        child = SoiTagTextInputWidget(
          onSubmitText: _handleTextSubmit,
          onFocusChanged: _handleTextFocusChanged,
          onEditingCancelled: _handleTypingCancelled,
          hintText: widget.textInputHintText,
        );
      case _SoiTagComposerMode.placing:
        child = _buildPlacingMode();
    }

    return SizedBox(
      width: 354,
      height: 52,
      child: KeyedSubtree(key: ValueKey(_mode.name), child: child),
    );
  }
}
