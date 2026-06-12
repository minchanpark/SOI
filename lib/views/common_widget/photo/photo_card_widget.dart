import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:tagging_core/tagging_core.dart';
import 'package:tagging_flutter/tagging_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../api/controller/comment_controller.dart';
import '../../../api/models/post.dart';
import '../../../api/models/comment.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../features/tagging_soi/tagging_soi.dart';
import 'photo_display_widget.dart';
import 'user_info_widget.dart';
import '../comment/comment_media_tag_preview_widget.dart';
import '../comment/comment_list_bottom_sheet.dart';
import '../report/report_bottom_sheet.dart';

/// 사진 카드 위젯.
/// 사진과 작성자 정보를 보여주고, 댓글 작성과 댓글 태그 기능을 제공합니다.
/// 댓글 태그를 탭하면 내용을 크게 보여주는 팝업도 관리합니다.
/// 피드, 아카이브 상세, 카테고리 페이지 등에서 사용됩니다.
///
/// Parameters:
/// - [post]: 표시할 게시물 데이터
/// - [categoryName]: 게시물이 속한 카테고리 이름 (댓글 태그에 표시하기 위함)
/// - [categoryId]: 게시물이 속한 카테고리 ID (댓글 태그 저장 시 필요)
/// - [index]: 피드 내에서의 게시물 순서 (댓글 태그 저장 시 필요)
/// - [isOwner]: 현재 사용자가 게시물 작성자인지 여부 (삭제 버튼 표시 여부 결정)
/// - [isArchive]: 아카이브 상세 페이지에서 사용되는지 여부 (댓글 태그 저장 시 surface 구분)
/// - [isCategory]: 카테고리 페이지에서 사용되는지 여부 (댓글 태그 저장 시 surface 구분)
/// - [isFromCamera]: 카메라에서 바로 게시된 사진인지 여부 (댓글 태그 저장 시 surface 구분)
/// - [selectedEmoji]: 현재 게시물에 선택된 이모지 (댓글 태그에 표시하기 위함)
/// - [onEmojiSelected]: 이모지 선택이 변경될 때 호출되는 콜백 (부모 위젯에서 선택된 이모지를 관리하기 위함)
/// - [onReportSubmitted]: 신고 제출이 완료되었을 때 호출되는 콜백 (신고 결과를 부모 위젯에서 처리하기 위함)
/// - [pendingCommentDrafts]: 게시물 ID별 댓글 작성 중인 드래프트 (댓글 태그의 콘텐츠 유형 판단과 댓글 작성 UI에 필요)
/// - [pendingVoiceComments]: 게시물 ID별 음성 댓글 작성 중인 드래프트 (댓글 태그의 콘텐츠 유형 판단과 음성 댓글 작성 UI에 필요)
/// - [onToggleAudio]: 게시물의 음성 댓글 재생/일시정지 토글 시 호출되는 콜백 (음성 댓글 UI와 상호작용하기 위함)
/// - [onTextCommentCompleted]: 텍스트 댓글 작성이 완료되었을 때 호출되는 콜백 (댓글 작성 UI와 상호작용하기 위함)
/// - [onAudioCommentCompleted]: 음성 댓글 작성이 완료되었을 때 호출되는 콜백 (댓글 작성 UI와 상호작용하기 위함)
/// - [onMediaCommentCompleted]: 미디어 댓글 작성이 완료되었을 때 호출되는 콜백 (댓글 작성 UI와 상호작용하기 위함)
/// - [onProfileImageDragged]: 프로필 이미지를 드래그하여 댓글 태그 위치를 지정할 때 호출되는 콜백 (댓글 태그 위치 지정과 상호작용하기 위함)
/// - [onCommentSaveProgress]: 댓글 저장 진행 상황이 업데이트될 때 호출되는 콜백 (댓글 작성 UI에서 저장 진행 상황 표시하기 위함)
/// - [onCommentSaveSuccess]: 댓글이 성공적으로 저장되었을 때 호출되는 콜백 (댓글 작성 UI에서 저장 성공 처리하기 위함)
/// - [onCommentSaveFailure]: 댓글 저장이 실패했을 때 호출되는 콜백 (댓글 작성 UI에서 저장 실패 처리하기 위함)
/// - [onDeletePressed]: 게시물 삭제 버튼이 눌렸을 때 호출되는 콜백 (게시물 삭제 처리하기 위함)
/// - [onCommentsReloadRequested]: 댓글 리스트를 새로고침해야 할 때 호출되는 콜백 (댓글 리스트 새로고침 처리하기 위함)
class ApiPhotoCardWidget extends StatefulWidget {
  final Post post;
  final String categoryName;
  final int categoryId;
  final int index;
  final bool isOwner;
  final bool isArchive;
  final bool isCategory;
  final bool isFromCamera;

  /// true이면 사진/영상 부분만 표시하고, 작성자 정보와 댓글 입력창은 표시하지 않습니다.
  /// 피드에서 사진 영역만 스크롤할 때 사용합니다.
  final bool displayOnly;

  // postId별 선택된 이모지 (부모가 관리)
  final String? selectedEmoji;
  final ValueChanged<String?>? onEmojiSelected; // 부모 캐시 갱신 콜백
  final Future<void> Function(Post post, ReportResult result)?
  onReportSubmitted;

  // 상태 관리 관련
  final Map<TagScopeId, TagDraft> pendingCommentDrafts;
  final Map<TagScopeId, TagPendingMarker> pendingVoiceComments;
  final SoiTaggingController taggingController;
  final TagMutationPort saveDelegate;

  // 콜백 함수들
  final Function(Post) onToggleAudio;
  final Function(int, String)? onTextCommentCompleted;
  final Future<void> Function(
    int postId,
    String audioPath,
    List<double> waveformData,
    int durationMs,
  )?
  onAudioCommentCompleted;
  final Future<void> Function(int postId, String localFilePath, bool isVideo)?
  onMediaCommentCompleted;
  final Function(int, Offset) onProfileImageDragged;
  final void Function(int, double)? onCommentSaveProgress;
  final void Function(int, TagComment)? onCommentSaveSuccess;
  final void Function(int, Object)? onCommentSaveFailure;
  final VoidCallback? onDeletePressed;
  final Future<void> Function(int postId)? onCommentsReloadRequested;
  final Future<List<Comment>> Function(int postId)? onLoadFullComments;

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
    this.displayOnly = false,
    this.selectedEmoji,
    this.onEmojiSelected,
    this.onReportSubmitted,
    required this.pendingCommentDrafts,
    this.pendingVoiceComments = const {},
    required this.taggingController,
    required this.saveDelegate,
    required this.onToggleAudio,
    this.onTextCommentCompleted,
    this.onAudioCommentCompleted,
    this.onMediaCommentCompleted,
    required this.onProfileImageDragged,
    this.onCommentSaveProgress,
    this.onCommentSaveSuccess,
    this.onCommentSaveFailure,
    this.onDeletePressed,
    this.onCommentsReloadRequested,
    this.onLoadFullComments,
  });

  @override
  State<ApiPhotoCardWidget> createState() => _ApiPhotoCardWidgetState();
}

/// ApiPhotoCardWidget의 상태 관리 클래스.
/// 댓글 태그를 탭했을 때 나타나는 팝업 애니메이션을 관리합니다.
/// displayOnly 모드에서도 팝업 관련 기능은 그대로 동작합니다.
class _ApiPhotoCardWidgetState extends State<ApiPhotoCardWidget>
    with SingleTickerProviderStateMixin {
  static const Duration _kOverlayExpandDuration = Duration(milliseconds: 220);
  static const Curve _kOverlayExpandCurve = Curves.easeOutCubic;

  bool _isTextFieldFocused = false;
  ExpandedMediaTagOverlayData? _expandedOverlayData;
  OverlayEntry? _expandedOverlayEntry;
  late final AnimationController _overlayExpandController;
  late final Animation<double> _overlayExpandAnimation;
  bool _isOverlayDismissAnimating = false;

  /// 카드가 보여 주는 post를 tagging 모듈의 공통 scope 식별자로 노출합니다.
  TagScopeId get _scopeId => SoiTaggingIds.postScopeId(widget.post.id);

  List<TagComment> get _tagComments =>
      widget.taggingController.peekTagComments(_scopeId);

  /// 댓글 시트는 full cache가 없을 때 원댓글 미리보기를 먼저 사용하고, 마지막 fallback으로 태그 캐시를 사용합니다.
  List<Comment> get _parentComments =>
      context.read<CommentController>().peekParentCommentsCache(
        postId: widget.post.id,
      ) ??
      const <Comment>[];

  /// 댓글 시트 초기 진입값은 full -> parent preview -> tag overlay 순으로 선택합니다.
  List<Comment> get _initialSheetComments {
    final fullComments =
        context.read<CommentController>().peekCommentsCache(
          postId: widget.post.id,
        ) ??
        const <Comment>[];
    if (fullComments.isNotEmpty) {
      return fullComments;
    }
    if (_parentComments.isNotEmpty) {
      return _parentComments;
    }
    return SoiTagCommentMapper.toComments(_tagComments);
  }

  /// 텍스트 댓글 작성이 완료되면 부모 위젯에 알립니다.
  Future<void> _handleTextCommentCreated(String text) async {
    await widget.onTextCommentCompleted?.call(widget.post.id, text);
  }

  /// 작성 중인 댓글의 종류를 반환합니다. 통계 기록에 사용됩니다.
  String _currentTagContentType() {
    final draft = widget.pendingCommentDrafts[_scopeId];
    if (draft == null) {
      return 'unknown';
    }

    if (draft.isTextComment) {
      return 'text';
    }

    if (draft.isAudioComment) {
      return 'audio';
    }

    if (draft.isImageComment) return 'image';
    if (draft.isVideoComment) return 'video';

    return 'unknown';
  }

  /// 댓글 태그가 사진에 저장됐을 때 통계 이벤트를 전송합니다.
  /// 어느 화면인지, 댓글 종류, 기존 태그 수 등의 정보를 함께 보냅니다.
  Future<void> _trackCommentTagSaved({
    required TagComment comment,
    required int existingTagCountBefore,
  }) async {
    await SoiTaggingAnalytics.trackCommentTagSaved(
      context,
      postId: widget.post.id,
      categoryId: widget.categoryId,
      surface: widget.isArchive ? 'archive_detail' : 'feed_home',
      tagContentType: _currentTagContentType(),
      existingTagCountBefore: existingTagCountBefore,
      comment: comment,
    );
  }

  /// 음성 댓글을 드래그해서 사진에 태그할 때의 위치를 반환합니다.
  TagPosition? _resolveDropRelativePosition(TagScopeId scopeId) {
    return widget.pendingVoiceComments[scopeId]?.relativePosition;
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
    // 보여주는 게시물이 바뀌면 이전 팝업을 닫습니다.
    if (oldWidget.post.id != widget.post.id) {
      _removeExpandedMediaOverlay();
    }
  }

  @override
  void deactivate() {
    // 화면에서 사라질 때(페이지 이동 등) 팝업을 닫습니다.
    _teardownExpandedMediaOverlay();
    super.deactivate();
  }

  @override
  void dispose() {
    // 위젯이 완전히 제거될 때 팝업과 애니메이션을 정리합니다.
    _teardownExpandedMediaOverlay();
    _overlayExpandController.dispose();
    super.dispose();
  }

  /// 현재 열려 있는 댓글 태그 팝업을 닫고 애니메이션을 초기화합니다.
  void _removeExpandedMediaOverlay() {
    _overlayExpandController.stop();
    _overlayExpandController.reset();
    _expandedOverlayEntry?.remove();
    _expandedOverlayEntry = null;
    _expandedOverlayData = null;
    _isOverlayDismissAnimating = false;
  }

  /// teardown 경로에서는 animation reset 알림을 생략해 dispose 중 build 충돌을 피합니다.
  void _teardownExpandedMediaOverlay() {
    _overlayExpandController.stop();
    _expandedOverlayEntry?.remove();
    _expandedOverlayEntry = null;
    _expandedOverlayData = null;
    _isOverlayDismissAnimating = false;
  }

  /// 시트가 돌려준 full thread 결과를 controller cache 한 곳에 반영합니다.
  void _replaceCommentCaches(List<Comment> updatedComments) {
    widget.taggingController.replaceCommentsCache(
      _scopeId,
      SoiTagCommentMapper.fromComments(updatedComments, scopeId: _scopeId),
    );
  }

  /// 사진에서 댓글 태그를 탭했을 때 호출됩니다.
  /// data가 null이면 팝업을 닫고, 값이 있으면 팝업을 열거나 내용을 업데이트합니다.
  void _handleExpandedMediaOverlayChanged(ExpandedMediaTagOverlayData? data) {
    if (!mounted) return;
    if (data == null) {
      _removeExpandedMediaOverlay();
      return;
    }

    _expandedOverlayData = data;

    final overlay = Overlay.of(context, rootOverlay: true); // 최상위 Overlay

    if (_expandedOverlayEntry == null) {
      _expandedOverlayEntry = OverlayEntry(
        builder: _buildExpandedMediaOverlayEntry,
      );
      overlay.insert(_expandedOverlayEntry!);
    }
    _expandedOverlayEntry!.markNeedsBuild();
    _overlayExpandController.forward(from: 0.0);
  }

  /// 확장된 태그를 reverse 애니메이션으로 닫은 뒤 카드 내부 선택 상태를 복원합니다.
  Future<void> _handleExpandedMediaOverlayDismissRequested(
    VoidCallback finalizeDismissal,
  ) async {
    if (_isOverlayDismissAnimating) {
      return;
    }

    if (_expandedOverlayEntry == null) {
      finalizeDismissal();
      return;
    }

    _isOverlayDismissAnimating = true;
    try {
      await _overlayExpandController.reverse(
        from: _overlayExpandController.value,
      );
      _removeExpandedMediaOverlay();
      finalizeDismissal();
    } finally {
      _isOverlayDismissAnimating = false;
    }
  }

  /// 댓글 태그 팝업 위젯을 만듭니다.
  /// 화면 밖으로 넘어가지 않도록 위치를 조정하고, 열릴 때 크기가 커지는 애니메이션을 적용합니다.
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
              final animationValue = _overlayExpandAnimation.value;
              final contentSize =
                  lerpDouble(
                    data.collapsedContentSize,
                    data.expandedContentSize,
                    animationValue,
                  ) ??
                  data.expandedContentSize;
              final avatarOpacity =
                  1.0 -
                  Curves.easeOut.transform(
                    Interval(0.0, 0.45).transform(animationValue),
                  );
              final previewOpacity = Curves.easeOutCubic.transform(
                Interval(0.18, 1.0).transform(animationValue),
              );
              final diameter = TagBubble.diameterForContent(
                contentSize: contentSize,
                padding: TagMediaTagSpec.padding,
              );
              final totalHeight = TagBubble.totalHeightForContent(
                contentSize: contentSize,
                padding: TagMediaTagSpec.padding,
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
                  onTap: () {
                    unawaited(
                      _handleExpandedMediaOverlayDismissRequested(
                        data.onDismiss,
                      ),
                    );
                  },
                  onLongPress: data.onLongPress,
                  child: TagBubble(
                    contentSize: contentSize,
                    padding: TagMediaTagSpec.padding,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        IgnorePointer(
                          child: Opacity(
                            opacity: avatarOpacity.clamp(0.0, 1.0),
                            child: TagCircleAvatar(
                              key: ValueKey('overlay_avatar_${data.tagKey}'),
                              imageUrl: data.comment.userProfileUrl,
                              size: contentSize,
                              cacheKey: data.comment.userProfileKey,
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Opacity(
                            opacity: previewOpacity.clamp(0.0, 1.0),
                            child: CommentMediaTagPreviewWidget(
                              key: ValueKey('overlay_media_${data.tagKey}'),
                              comment: data.comment,
                              autoplayVideo: true,
                              playWithSound: true,
                              frameSize: diameter,
                              contentSize: contentSize,
                            ),
                          ),
                        ),
                      ],
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

  /// 카드 레이아웃을 구성합니다.
  ///
  /// - displayOnly가 true이면: 사진/영상만 보여줍니다 (피드 스크롤 화면에서 사용).
  /// - displayOnly가 false이면: 사진 + 작성자 정보 + 댓글 입력창을 모두 보여줍니다
  ///   (아카이브, 카테고리 상세 화면에서 사용).
  @override
  Widget build(BuildContext context) {
    // displayOnly 모드: ApiPhotoDisplayWidget만 렌더링 (UserInfo, Composer 제외)
    if (widget.displayOnly) {
      return VisibilityDetector(
        key: ValueKey('api_photo_card_${widget.post.id}'),
        onVisibilityChanged: (info) {
          if (info.visibleFraction < 0.55 && _expandedOverlayEntry != null) {
            _removeExpandedMediaOverlay();
          }
        },
        child: ApiPhotoDisplayWidget(
          key: ValueKey(widget.post.id),
          post: widget.post,
          categoryId: widget.categoryId,
          categoryName: widget.categoryName,
          isArchive: widget.isArchive,
          isFromCamera: widget.isFromCamera,
          taggingController: widget.taggingController,
          loadFullComments: widget.onLoadFullComments,
          onProfileImageDragged: widget.onProfileImageDragged,
          onToggleAudio: widget.onToggleAudio,
          pendingVoiceComments: widget.pendingVoiceComments,
          onCommentsReloadRequested: widget.onCommentsReloadRequested,
          onExpandedMediaOverlayChanged: _handleExpandedMediaOverlayChanged,
          onExpandedMediaOverlayDismissRequested:
              _handleExpandedMediaOverlayDismissRequested,
        ),
      );
    }

    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = _isTextFieldFocused || keyboardInset > 0;
    final composerBottomInset = isKeyboardVisible
        ? keyboardInset + 10.0
        : (widget.isCategory ? 55.0 : 10.0);

    return VisibilityDetector(
      key: ValueKey('api_photo_card_${widget.post.id}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction < 0.55 && _expandedOverlayEntry != null) {
          _removeExpandedMediaOverlay();
        }
      },
      child: Stack(
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
                  taggingController: widget.taggingController,
                  loadFullComments: widget.onLoadFullComments,
                  onProfileImageDragged: widget.onProfileImageDragged,
                  onToggleAudio: widget.onToggleAudio,
                  pendingVoiceComments: widget.pendingVoiceComments,
                  onCommentsReloadRequested: widget.onCommentsReloadRequested,
                  onExpandedMediaOverlayChanged:
                      _handleExpandedMediaOverlayChanged,
                  onExpandedMediaOverlayDismissRequested:
                      _handleExpandedMediaOverlayDismissRequested,
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
                    final comments = _initialSheetComments;
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) {
                        return ChangeNotifierProvider(
                          create: (_) => AudioController(),
                          child: ApiVoiceCommentListSheet(
                            postId: widget.post.id,
                            initialComments: comments,
                            loadFullComments: widget.onLoadFullComments,
                            onCommentsUpdated: (updatedComments) {
                              if (!mounted) return;
                              setState(() {
                                _replaceCommentCaches(updatedComments);
                              });
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: 10.h),

                // 음성 녹음 위젯을 위한 공간 확보
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: isKeyboardVisible ? 0 : 90.h,
                ),
              ],
            ),
          ),

          // 음성 녹음 위젯을 Stack 위에 배치
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: composerBottomInset),
              child: SoiTagComposerWidget(
                scopeId: _scopeId,
                pendingDrafts: widget.pendingCommentDrafts,
                mutationPort: widget.saveDelegate,
                avatarBuilder: SoiTaggingAvatarBuilders.buildComposerAvatar,
                onTextDraftSubmitted: (_, text) =>
                    _handleTextCommentCreated(text),
                onAudioDraftRequested: (scopeId) {
                  final postId = SoiTaggingIds.postIdFromScopeId(scopeId);
                  return SoiTaggingComposerActions.requestAudioDraft(
                    context: context,
                    onSelected: (audioPath, waveformData, durationMs) async {
                      await widget.onAudioCommentCompleted!(
                        postId,
                        audioPath,
                        waveformData,
                        durationMs,
                      );
                    },
                  );
                },
                onCameraDraftRequested: (scopeId) {
                  final postId = SoiTaggingIds.postIdFromScopeId(scopeId);
                  return SoiTaggingComposerActions.requestCameraDraft(
                    context: context,
                    onSelected: (localFilePath, isVideo) async {
                      await widget.onMediaCommentCompleted!(
                        postId,
                        localFilePath,
                        isVideo,
                      );
                    },
                  );
                },
                basePlaceholderText: '댓글 추가...',
                textInputHintText: '댓글 추가...',
                cameraIcon: Image.asset(
                  'assets/camera_button_baseBar.png',
                  width: 32.sp,
                  height: 32.sp,
                ),
                micIcon: Image.asset('assets/mic_icon.png'),
                resolveDropRelativePosition: _resolveDropRelativePosition,
                onCommentSaveProgress: (scopeId, progress) {
                  widget.onCommentSaveProgress!(
                    SoiTaggingIds.postIdFromScopeId(scopeId),
                    progress,
                  );
                },
                onCommentSaveSuccess: (scopeId, comment) {
                  final postId = SoiTaggingIds.postIdFromScopeId(scopeId);
                  final existingTagCountBefore = _tagComments.length;

                  if (comment.hasLocation) {
                    unawaited(
                      _trackCommentTagSaved(
                        comment: comment,
                        existingTagCountBefore: existingTagCountBefore,
                      ),
                    );
                  }

                  widget.onCommentSaveSuccess!(postId, comment);
                },
                onCommentSaveFailure: (scopeId, error) {
                  widget.onCommentSaveFailure!(
                    SoiTaggingIds.postIdFromScopeId(scopeId),
                    error,
                  );
                },
                onTextFieldFocusChanged: (isFocused) {
                  setState(() {
                    _isTextFieldFocused = isFocused;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
