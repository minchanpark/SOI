import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../api/models/post.dart';
import '../../../api/models/comment.dart';
import '../../../api/controller/audio_controller.dart';
import 'api_photo_display_widget.dart';
import 'api_user_info_widget.dart';
import '../about_comment_version_2/comment_composer_v2_widget.dart';
import '../about_comment_version_2/comment_media_tag_preview_widget.dart';
import '../about_comment_version_1/api_voice_comment_list_sheet.dart';
import '../about_comment_version_1/pending_api_voice_comment.dart';
import '../report/report_bottom_sheet.dart';
import 'tag_pointer.dart';

/// API 기반 사진 카드 위젯
///
/// Firebase 버전의 PhotoCardWidgetCommon과 동일한 디자인을 유지하면서
/// Post 모델을 사용합니다.
class ApiPhotoCardWidget extends StatefulWidget {
  final Post post;
  final String categoryName;
  final int categoryId;
  final int index;
  final bool isOwner;
  final bool isArchive;
  final bool isCategory;
  final bool isFromCamera;

  // postId별 선택된 이모지 (부모가 관리)
  final String? selectedEmoji;
  final ValueChanged<String?>? onEmojiSelected; // 부모 캐시 갱신 콜백
  final Future<void> Function(Post post, ReportResult result)?
  onReportSubmitted;

  // 상태 관리 관련
  final Map<int, List<Comment>> postComments;
  final Map<int, PendingApiCommentDraft> pendingCommentDrafts;
  final Map<int, PendingApiCommentMarker> pendingVoiceComments;

  // 콜백 함수들
  final Function(Post) onToggleAudio;
  final Function(int, String) onTextCommentCompleted;
  final Future<void> Function(
    int postId,
    String audioPath,
    List<double> waveformData,
    int durationMs,
  )
  onAudioCommentCompleted;
  final Future<void> Function(int postId, String localFilePath, bool isVideo)
  onMediaCommentCompleted;
  final Function(int, Offset) onProfileImageDragged;
  final void Function(int, double) onCommentSaveProgress;
  final void Function(int, Comment) onCommentSaveSuccess;
  final void Function(int, Object) onCommentSaveFailure;
  final VoidCallback onDeletePressed;
  final Future<void> Function(int postId)? onCommentsReloadRequested;

  const ApiPhotoCardWidget({
    super.key,
    required this.post,
    required this.categoryName,
    required this.categoryId,
    required this.index,
    required this.isOwner,
    this.isArchive = false,
    this.isCategory = false,
    this.isFromCamera = false,
    this.selectedEmoji,
    this.onEmojiSelected,
    this.onReportSubmitted,
    required this.postComments,
    required this.pendingCommentDrafts,
    this.pendingVoiceComments = const {},
    required this.onToggleAudio,
    required this.onTextCommentCompleted,
    required this.onAudioCommentCompleted,
    required this.onMediaCommentCompleted,
    required this.onProfileImageDragged,
    required this.onCommentSaveProgress,
    required this.onCommentSaveSuccess,
    required this.onCommentSaveFailure,
    required this.onDeletePressed,
    this.onCommentsReloadRequested,
  });

  @override
  State<ApiPhotoCardWidget> createState() => _ApiPhotoCardWidgetState();
}

class _ApiPhotoCardWidgetState extends State<ApiPhotoCardWidget>
    with SingleTickerProviderStateMixin {
  static const Duration _kOverlayExpandDuration = Duration(milliseconds: 220);
  static const Curve _kOverlayExpandCurve = Curves.easeOutCubic;

  bool _isTextFieldFocused = false;
  ExpandedMediaTagOverlayData? _expandedOverlayData;
  OverlayEntry? _expandedOverlayEntry;
  late final AnimationController _overlayExpandController;
  late final Animation<double> _overlayExpandAnimation;

  Future<void> _handleTextCommentCreated(String text) async {
    debugPrint(
      '[ApiPhotoCard] 텍스트 댓글 생성: postId=${widget.post.id}, text=$text',
    );
    await widget.onTextCommentCompleted(widget.post.id, text);
  }

  Offset? _resolveDropRelativePosition(int postId) {
    return widget.pendingVoiceComments[postId]?.relativePosition;
  }

  @override
  void initState() {
    super.initState();
    _overlayExpandController = AnimationController(
      vsync: this,
      duration: _kOverlayExpandDuration,
    );
    _overlayExpandAnimation = CurvedAnimation(
      parent: _overlayExpandController,
      curve: _kOverlayExpandCurve,
    );
  }

  @override
  void didUpdateWidget(covariant ApiPhotoCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _removeExpandedMediaOverlay();
    }
  }

  @override
  void deactivate() {
    _removeExpandedMediaOverlay();
    super.deactivate();
  }

  @override
  void dispose() {
    _removeExpandedMediaOverlay();
    _overlayExpandController.dispose();
    super.dispose();
  }

  void _removeExpandedMediaOverlay() {
    _overlayExpandController.stop();
    _overlayExpandController.reset();
    _expandedOverlayEntry?.remove();
    _expandedOverlayEntry = null;
    _expandedOverlayData = null;
  }

  void _handleExpandedMediaOverlayChanged(ExpandedMediaTagOverlayData? data) {
    if (!mounted) return;
    if (data == null) {
      _removeExpandedMediaOverlay();
      return;
    }

    _expandedOverlayData = data;

    final overlay = Overlay.of(context, rootOverlay: true);

    if (_expandedOverlayEntry == null) {
      _expandedOverlayEntry = OverlayEntry(
        builder: _buildExpandedMediaOverlayEntry,
      );
      overlay.insert(_expandedOverlayEntry!);
    }
    _expandedOverlayEntry!.markNeedsBuild();
    _overlayExpandController.forward(from: 0.0);
  }

  Widget _buildExpandedMediaOverlayEntry(BuildContext overlayContext) {
    final data = _expandedOverlayData;
    if (data == null) return const SizedBox.shrink();

    final mediaQuery = MediaQuery.of(overlayContext);
    final screenSize = mediaQuery.size;
    final safePadding = mediaQuery.padding;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: data.onDismiss,
              child: const SizedBox.expand(),
            ),
          ),
          AnimatedBuilder(
            animation: _overlayExpandAnimation,
            builder: (_, __) {
              final progress = _overlayExpandAnimation.value;
              final contentSize =
                  data.collapsedContentSize +
                  ((data.expandedContentSize - data.collapsedContentSize) *
                      progress);
              final diameter = TagBubble.diameterForContent(
                contentSize: contentSize,
              );
              final totalHeight = TagBubble.totalHeightForContent(
                contentSize: contentSize,
              );
              final topLeft = Offset(
                data.globalCircleCenter.dx - (diameter / 2),
                data.globalCircleCenter.dy - (diameter / 2),
              );

              final clampedLeft = topLeft.dx.clamp(
                0.0,
                (screenSize.width - diameter).clamp(0.0, double.infinity),
              );
              final maxTop = (screenSize.height - totalHeight).clamp(
                0.0,
                double.infinity,
              );
              final minTop = safePadding.top.clamp(0.0, maxTop);
              final clampedTop = topLeft.dy.clamp(minTop, maxTop);

              return Positioned(
                left: clampedLeft,
                top: clampedTop,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: data.onDismiss,
                  onLongPress: data.onLongPress,
                  child: TagBubble(
                    contentSize: contentSize,
                    child: CommentMediaTagPreviewWidget(
                      key: ValueKey('overlay_media_${data.tagKey}'),
                      comment: data.comment,
                      size: contentSize,
                      autoplayVideo: true,
                      playWithSound: true,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = _isTextFieldFocused;
    final bottomPadding = isKeyboardVisible
        ? 10.0
        : (widget.isCategory ? 55.0 : 10.0);

    return Stack(
      clipBehavior: Clip.none, // 오버레이와 하단 코멘트 컴포저 레이어를 유지
      children: [
        SingleChildScrollView(
          clipBehavior: Clip.none,
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 피드 페이지에 SOI Appbar를 표시하지 않는 경우를 대비한 공간 확보
              // if (!widget.isArchive) SizedBox(height: 90.h),

              // 사진 표시 위젯
              ApiPhotoDisplayWidget(
                key: ValueKey(widget.post.id),
                post: widget.post,
                categoryId: widget.categoryId,
                categoryName: widget.categoryName,
                isArchive: widget.isArchive,
                isFromCamera: widget.isFromCamera,
                postComments: widget.postComments,
                onProfileImageDragged: widget.onProfileImageDragged,
                onToggleAudio: widget.onToggleAudio,
                pendingVoiceComments: widget.pendingVoiceComments,
                onCommentsReloadRequested: widget.onCommentsReloadRequested,
                onExpandedMediaOverlayChanged:
                    _handleExpandedMediaOverlayChanged,
              ),
              SizedBox(height: 12.h),

              // 사용자 정보 위젯 (아이디와 날짜)
              ApiUserInfoWidget(
                post: widget.post,
                isCurrentUserPost: widget.isOwner,
                onDeletePressed: widget.onDeletePressed,
                onReportSubmitted: widget.onReportSubmitted == null
                    ? null
                    : (result) =>
                          widget.onReportSubmitted!(widget.post, result),
                onCommentPressed: () {
                  // 댓글 리스트 Bottom Sheet 표시
                  final comments = widget.postComments[widget.post.id] ?? [];
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) {
                      return ChangeNotifierProvider(
                        create: (_) => AudioController(),
                        child: SizedBox(
                          height: 480.h,
                          child: ApiVoiceCommentListSheet(
                            postId: widget.post.id,
                            comments: comments,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              SizedBox(height: 10.h),

              // 음성 녹음 위젯을 위한 공간 확보
              SizedBox(height: 90.h),
            ],
          ),
        ),

        // 음성 녹음 위젯을 Stack 위에 배치
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomPadding,
          child: CommentComposerV2Widget(
            postId: widget.post.id,
            pendingCommentDrafts: widget.pendingCommentDrafts,
            onTextCommentCompleted: (postId, text) =>
                _handleTextCommentCreated(text),
            onAudioCommentCompleted:
                (postId, audioPath, waveformData, durationMs) =>
                    widget.onAudioCommentCompleted(
                      postId,
                      audioPath,
                      waveformData,
                      durationMs,
                    ),
            onMediaCommentCompleted: (postId, localFilePath, isVideo) =>
                widget.onMediaCommentCompleted(postId, localFilePath, isVideo),
            resolveDropRelativePosition: _resolveDropRelativePosition,
            onCommentSaveProgress: widget.onCommentSaveProgress,
            onCommentSaveSuccess: widget.onCommentSaveSuccess,
            onCommentSaveFailure: widget.onCommentSaveFailure,
            onTextFieldFocusChanged: (isFocused) {
              setState(() {
                _isTextFieldFocused = isFocused;
              });
            },
          ),
        ),
      ],
    );
  }
}
