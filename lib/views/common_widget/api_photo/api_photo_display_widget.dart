import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../api/controller/category_controller.dart' as api_category;
import '../../../api/controller/comment_controller.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../api/models/comment.dart';
import '../../../api/models/post.dart';
import '../../../utils/position_converter.dart';
import '../../about_archiving/screens/archive_detail/api_category_photos_screen.dart';
import 'first_line_ellipsis_text.dart';
import 'api_audio_control_widget.dart';
import '../about_comment_version_1/api_voice_comment_list_sheet.dart';
import '../about_comment_version_1/pending_api_voice_comment.dart';
import 'tag_pointer.dart';

part 'extension/api_photo_display_widget_video.dart';
part 'extension/api_photo_display_widget_media.dart';
part 'extension/api_photo_display_widget_comment_tags.dart';
part 'extension/api_photo_display_widget_comment_actions.dart';

Widget _heroFlightShuttleBuilder(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  final toHero = (toHeroContext.widget as Hero).child;
  final fromHero = (fromHeroContext.widget as Hero).child;
  final shuttleChild = flightDirection == HeroFlightDirection.push
      ? toHero
      : fromHero;
  return Material(
    type: MaterialType.transparency,
    child: ClipRect(child: shuttleChild),
  );
}

class ExpandedMediaTagOverlayData {
  final String tagKey;
  final Comment comment;
  final Offset globalCircleCenter;
  final double collapsedContentSize;
  final double expandedContentSize;
  final VoidCallback onDismiss;
  final VoidCallback? onLongPress;

  const ExpandedMediaTagOverlayData({
    required this.tagKey,
    required this.comment,
    required this.globalCircleCenter,
    required this.collapsedContentSize,
    required this.expandedContentSize,
    required this.onDismiss,
    this.onLongPress,
  });
}

/// API 사진/비디오 표시 위젯
/// 게시물의 사진 또는 비디오를 표시하고, 댓글 아바타 및 캡션 오버레이를 관리합니다.
///
/// Parameters:
///   - [post]: 표시할 게시물 데이터
///   - [categoryId]: 게시물이 속한 카테고리 ID
///   - [categoryName]: 게시물이 속한 카테고리 이름
///   - [isArchive]: 아카이브 모드 여부
///   - [postComments]: 게시물 ID별 댓글 맵
///   - [onProfileImageDragged]: 프로필 이미지 드래그 콜백
///   - [onToggleAudio]: 오디오 토글 콜백
///   - [pendingVoiceComments]: 업로드 중인 음성 댓글 맵
///   - [onCommentsReloadRequested]: 댓글 재로딩 요청 콜백
///
/// Returns:
///   - [ApiPhotoDisplayWidget]: API 사진/비디오 표시 위젯 인스턴스
class ApiPhotoDisplayWidget extends StatefulWidget {
  final Post post;
  final int categoryId;
  final String categoryName;
  final bool isArchive;
  final bool isFromCamera;
  final Map<int, List<Comment>> postComments;
  final Function(int, Offset) onProfileImageDragged;
  final Function(Post) onToggleAudio;
  final Map<int, PendingApiCommentMarker> pendingVoiceComments;
  final Future<void> Function(int postId)? onCommentsReloadRequested;
  final ValueChanged<ExpandedMediaTagOverlayData?>?
  onExpandedMediaOverlayChanged;

  const ApiPhotoDisplayWidget({
    super.key,
    required this.post,
    required this.categoryId,
    required this.categoryName,
    this.isArchive = false,
    this.isFromCamera = false,
    required this.postComments,
    required this.onProfileImageDragged,
    required this.onToggleAudio,
    this.pendingVoiceComments = const {},
    this.onCommentsReloadRequested,
    this.onExpandedMediaOverlayChanged,
  });

  @override
  State<ApiPhotoDisplayWidget> createState() => _ApiPhotoDisplayWidgetState();
}

class _ApiPhotoDisplayWidgetState extends State<ApiPhotoDisplayWidget>
    with WidgetsBindingObserver {
  static const double _avatarSize = 27.0;
  static const double _expandedAvatarSize = 108.0;
  static const double _imageWidth = 354.0;
  static const double _imageHeight = 500.0;

  // 실제 이미지/비디오 표시 크기 (프레임 고정)
  // savedAspectRatio는 메타데이터로 유지하되, 피드 프레임 높이 계산에는 사용하지 않습니다.
  Size get _imageSize => Size(_imageWidth.w, _imageHeight.h);

  // Hero 태그 생성 (카테고리 ID와 게시물 ID를 조합하여 고유한 태그 생성)
  String get _heroTag => 'archive_photo_${widget.categoryId}_${widget.post.id}';

  // 안전한 setState 호출 메서드
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(fn);
      });
      return;
    }
    setState(fn);
  }

  String? _selectedCommentKey;
  String? _expandedMediaTagKey;
  int? _selectedCommentId;
  Offset? _selectedCommentPosition;
  bool _showActionOverlay = false;
  bool _isShowingComments = false;
  bool _autoOpenedOnce = false;
  bool _isCaptionExpanded = false;
  String? _uploaderProfileImageUrl;
  bool _isProfileLoading = false;
  final GlobalKey _displayStackKey = GlobalKey();

  /// 댓글 목록을 해당 게시물 ID로부터 가져오는 getter
  List<Comment> get _postComments =>
      widget.postComments[widget.post.id] ?? const <Comment>[];

  /// 대기 중인 음성 댓글의 마커 존재 여부를 체크해서 return하는 getter
  /// 대기 중인 음성 댓글이 있으면 true, 없으면 false 반환
  bool get _hasPendingMarker {
    final pending = widget.pendingVoiceComments[widget.post.id];
    return pending != null;
  }

  /// 댓글 존재 여부를 체크해서 return하는 getter
  bool get _hasComments => _postComments.isNotEmpty;

  /// 게시글 존재 여부를 체크해서 return하는 getter
  bool get _hasCaption => widget.post.content?.isNotEmpty ?? false;

  /// text-only 게시물 여부
  bool get _isTextOnlyPost {
    final hasText = widget.post.content?.trim().isNotEmpty ?? false;
    return widget.post.postType == PostType.textOnly ||
        (!widget.post.hasMedia && hasText);
  }

  /// 게시물 이미지 또는 비디오의 URL을 저장하는 변수
  String? postImageUrl;

  /// 비디오 컨트롤러
  /// 비디오 재생 및 제어를 담당하는 VideoPlayerController 인스턴스 입니다.
  VideoPlayerController? _videoController;

  /// 비디오가 초기화되었는 지를 나타내는 Future로 선언된 변수
  /// 비디오 컨트롤러의 초기화 상태를 나타냅니다.
  /// initialize()가 끝날 때까지 기다리는 “초기화 작업 핸들러” 역할을 합니다.
  ///   --> initialize() 메서드는 비디오의 메타데이터를 로드하고 재생 준비를 완료하는 "비동기 작업"이기 때문에,
  ///       이 Future를 사용하여 초기화가 완료될 때까지 기다릴 수 있습니다.
  Future<void>? _videoInitialization;

  /// 비디오가 BoxFit.cover 모드인지 여부 (false = 원본 비율, true = 화면 채우기)
  bool _isVideoCoverMode = false;

  /// 이미지가 BoxFit.cover 모드인지 여부 (false = 원본 비율, true = 화면 채우기)
  bool _isImageCoverMode = false;

  /// 비디오가 화면에 보이는지 여부
  bool _isVideoVisible = true;

  /// 초기화 메서드
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 앱의 라이프사이클의 변화를 감지하기 위해 옵저버 등록
    _isImageCoverMode = widget.isFromCamera;
    _isVideoCoverMode = widget.isFromCamera;
    _isShowingComments =
        _hasComments || _hasPendingMarker; // 댓글/대기 마커가 있으면 댓글 표시
    _scheduleProfileLoad(widget.post.userProfileImageKey); // 프로필 이미지 로드 예약

    // 서버에서 제공하는 postFileUrl을 직접 사용
    final url = widget.post.postFileUrl;
    postImageUrl = (url != null && url.isNotEmpty) ? url : null;
    _ensureVideoController(); // 비디오 컨트롤러 초기화
  }

  /// 앱 라이프사이클 상태 변경 처리
  /// 비디오 게시물의 경우, 앱이 백그라운드로 전환될 때 비디오를 일시정지합니다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.post.isVideo) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pauseVideo(); // 앱이 백그라운드로 전환될 때 비디오 일시정지
    }
  }

  @override
  void deactivate() {
    if (widget.post.isVideo) {
      _pauseVideo();
    }
    super.deactivate();
  }

  @override
  void didUpdateWidget(covariant ApiPhotoDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFromCamera != widget.isFromCamera) {
      setState(() {
        _isImageCoverMode = widget.isFromCamera;
        _isVideoCoverMode = widget.isFromCamera;
      });
    }
    if (_hasComments && !_autoOpenedOnce) {
      setState(() {
        _isShowingComments = true;
        _autoOpenedOnce = true;
      });
    }

    // 대기 중인 프로필 태그가 생기면(첫 댓글 포함) 즉시 표시하도록 한다.
    if (_hasPendingMarker && !_isShowingComments) {
      setState(() {
        _isShowingComments = true;
      });
    }
    // 프로필 이미지 URL이 변경되었는지 확인
    if (oldWidget.post.userProfileImageUrl != widget.post.userProfileImageUrl ||
        oldWidget.post.userProfileImageKey != widget.post.userProfileImageKey) {
      // 프로필 이미지가 변경되었으므로 프레임 콜백으로 로드 예약
      _scheduleProfileLoad(widget.post.userProfileImageKey);
    }

    // 게시물 이미지 URL이 변경되었는지 확인
    if (oldWidget.post.postFileUrl != widget.post.postFileUrl ||
        oldWidget.post.postFileKey != widget.post.postFileKey) {
      _safeSetState(() {
        final url = widget.post.postFileUrl;
        postImageUrl = (url != null && url.isNotEmpty) ? url : null;
      });

      // 비디오 컨트롤러 갱신
      _ensureVideoController(forceRecreate: true);
    }
    // 게시물 이미지가 동일한 경우
    else {
      // 비디오 컨트롤러 갱신
      _ensureVideoController();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearExpandedMediaOverlay();
    _disposeVideoController();
    super.dispose();
  }

  // Responsibilities split into part files:
  // - video lifecycle/controller: api_photo_display_widget_video.dart
  // - media/profile rendering: api_photo_display_widget_media.dart
  // - comment tag overlay geometry: api_photo_display_widget_comment_tags.dart
  // - comment actions/sheet/navigation: api_photo_display_widget_comment_actions.dart

  @override
  Widget build(BuildContext context) {
    final categoryTrimmed = widget.categoryName.trim();
    final isEnglishCategory =
        categoryTrimmed.isNotEmpty &&
        RegExp(r'^[A-Za-z\s]+$').hasMatch(categoryTrimmed);
    final waveformData = _parseWaveformData(widget.post.waveformData);
    final pendingMarker = _buildPendingMarker();
    final deletePopup = _showActionOverlay ? _buildDeleteActionPopup() : null;
    final showCaptionOverlay = _hasCaption && !_isTextOnlyPost;
    final showCommentToggle = _hasComments || _hasPendingMarker;

    return Center(
      child: SizedBox(
        width: _imageSize.width,
        height: _imageSize.height,
        child: Builder(
          builder: (builderContext) {
            final mediaBase = _buildMediaContent();
            final mediaFrame = _isTextOnlyPost
                ? mediaBase
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: mediaBase,
                  );
            final mediaWithHero = widget.isArchive
                ? Hero(
                    tag: _heroTag,
                    createRectTween: (begin, end) => MaterialRectArcTween(
                      begin: begin,
                      end: end,
                    ), // 아카이브에서는 둥근 모서리 유지하며 애니메이션
                    transitionOnUserGestures: true, // 사용자 제스처 중에도 애니메이션 허용
                    flightShuttleBuilder: _heroFlightShuttleBuilder,
                    child: mediaFrame,
                  )
                : mediaFrame;

            return DragTarget<String>(
              onWillAcceptWithDetails: (details) => details.data.isNotEmpty,
              onAcceptWithDetails: (details) {
                final renderBox =
                    builderContext.findRenderObject() as RenderBox?;
                if (renderBox == null) return;
                final localPosition = renderBox.globalToLocal(details.offset);
                final tipOffset = TagBubble.pointerTipOffset(
                  contentSize: _avatarSize,
                );
                widget.onProfileImageDragged(
                  widget.post.id,
                  localPosition + tipOffset,
                );
              },
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  onTap: _handleBaseTap,
                  child: Stack(
                    key: _displayStackKey,
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      mediaWithHero,

                      // 댓글 액션 오버레이
                      if (_showActionOverlay)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: _dismissOverlay,
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.6),
                            ),
                          ),
                        ),

                      // 카테고리 라벨
                      if (!widget.isArchive)
                        Positioned(
                          top: 11.h,
                          child: GestureDetector(
                            onTap: _navigateToCategory,
                            child: IntrinsicWidth(
                              child: Container(
                                height: 25,
                                padding: EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: isEnglishCategory ? 0 : 2,
                                  bottom: isEnglishCategory ? 2 : 0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  widget.categoryName,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Pretendard Variable',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 오디오 컨트롤 위젯
                      if (widget.post.hasAudio)
                        Positioned(
                          left: 18.w,
                          right: 18.w,
                          bottom: 22.h,
                          child: ApiAudioControlWidget(
                            post: widget.post,
                            waveformData: waveformData,
                          ),
                        ),
                      if (!widget.post.hasAudio &&
                          (showCaptionOverlay || showCommentToggle))
                        Positioned(
                          left: 16.w,
                          right: 16.w,
                          bottom: 18.h,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (showCaptionOverlay)
                                Expanded(child: _buildCaptionOverlay(true)),
                              if (showCommentToggle) ...[
                                if (showCaptionOverlay) SizedBox(width: 12.w),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isShowingComments = !_isShowingComments;
                                      if (!_isShowingComments) {
                                        _expandedMediaTagKey = null;
                                      }
                                    });
                                    if (!_isShowingComments) {
                                      _clearExpandedMediaOverlay();
                                    }
                                  },
                                  child: Image.asset(
                                    "assets/comment_profile_icon.png",
                                    width: 25,
                                    height: 25,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ..._buildCommentAvatars(),
                      if (pendingMarker != null) pendingMarker,
                      if (deletePopup != null) deletePopup,
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
