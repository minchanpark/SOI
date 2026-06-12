import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:tagging_core/tagging_core.dart';
import 'package:tagging_flutter/tagging_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../../api/controller/audio_controller.dart';
import '../../../api/controller/category_controller.dart' as api_category;
import '../../../api/controller/media_controller.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../api/controller/comment_controller.dart';
import '../../../api/models/comment.dart';
import '../../../api/models/post.dart';
import '../../../features/tagging_soi/tagging_soi.dart';
import '../../about_archiving/screens/archive_detail/category_photos_screen.dart';
import '../comment/comment_list_bottom_sheet.dart';
import 'audio_control_widget.dart';
import 'services/photo_waveform_parser_service.dart';
import 'widgets/photo_caption_overlay.dart';
import 'widgets/photo_delete_action_popup.dart';
import 'widgets/photo_media_content.dart';

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

/// 미디어 태그 오버레이가 확장될 때 전달되는 데이터 모델입니다.
///
/// fields:
/// - [tagKey]: 확장된 태그의 고유 키입니다.
///   - 이 키를 통해 어떤 태그가 확장되었는지 식별할 수 있습니다.
/// - [comment]: 확장된 태그와 관련된 댓글 데이터 모델입니다. 댓글 작성자, 내용, 타입 등의 정보를 포함합니다.
/// - [globalCircleCenter]: 태그 원형 아바타의 중심 위치를 글로벌 좌표로 나타낸 Offset입니다.
///   - 이 위치를 기준으로 오버레이가 표시됩니다.
/// - [collapsedContentSize]: 태그가 축소된 상태에서의 콘텐츠 크기입니다.
/// - [expandedContentSize]: 태그가 확장된 상태에서의 콘텐츠 크기입니다.
///   - 확장된 오버레이가 이 크기로 표시됩니다.
/// - [onDismiss]: 오버레이가 축소되어야 할 때 호출되는 콜백 함수입니다.
///   - 사용자가 오버레이 외부를 탭하거나, 다른 태그를 탭하는 등의 행동으로 오버레이가 닫힐 때 이 함수를 호출하여 상위 위젯에서 상태를 업데이트할 수 있도록 합니다.
/// - [onLongPress]: 태그가 길게 눌렸을 때 호출되는 콜백 함수입니다.
///   - 이 함수를 통해 댓글 삭제 등의 추가 액션을 구현할 수 있습니다.
class ExpandedMediaTagOverlayData {
  final String tagKey;
  final TagComment comment;
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

typedef ExpandedMediaOverlayDismissRequest =
    Future<void> Function(VoidCallback finalizeDismissal);

class ApiPhotoDisplayWidget extends StatefulWidget {
  final Post post;
  final int categoryId;
  final String categoryName;
  final bool isArchive;
  final bool isFromCamera;
  final SoiTaggingController taggingController;
  final Future<List<Comment>> Function(int postId)? loadFullComments;
  final Function(int, Offset) onProfileImageDragged;
  final Function(Post) onToggleAudio;
  final Map<TagScopeId, TagPendingMarker> pendingVoiceComments;
  final Future<void> Function(int postId)? onCommentsReloadRequested;
  final ValueChanged<ExpandedMediaTagOverlayData?>?
  onExpandedMediaOverlayChanged;
  final ExpandedMediaOverlayDismissRequest?
  onExpandedMediaOverlayDismissRequested;

  ///
  /// API에서 받아온 Post 데이터를 기반으로 이미지/비디오, 작성자 아바타, 댓글 태그 등을 렌더링하는 위젯입니다.
  /// - Post의 content, postFileUrl, userProfileImageUrl 등의 필드를 활용해 미디어와 작성자 정보를 표시합니다.
  /// - 댓글이 있는 경우 댓글 태그를 미디어 위에 오버레이로 렌더링하며, 댓글 작성자의 프로필 사진을 원형 아바타로 표시합니다.
  /// - 댓글 태그는 댓글 작성자의 프로필 사진과 댓글 내용을 함께 보여주는 오버레이로, 탭하면 전체 댓글 내용을 스크롤 가능한 형태로 확장하여 보여줍니다.
  ///
  /// fields:
  /// - [post]
  ///   - API에서 받아온 Post 모델입니다.
  ///   - content, postFileUrl, userProfileImageUrl 등의 필드를 활용해 미디어와 작성자 정보를 표시합니다.
  /// - [categoryId]: 해당 포스트가 속한 카테고리의 ID입니다.
  /// - [categoryName]: 해당 포스트가 속한 카테고리의 이름입니다.
  /// - [isArchive]: 해당 포스트가 아카이브된 상태인지 여부를 나타내는 플래그입니다.
  /// - [isFromCamera]: 해당 포스트가 카메라에서 촬영된 미디어인지 여부를 나타내는 플래그입니다.
  /// - [onProfileImageDragged]: 작성자 아바타가 드래그될 때 호출되는 콜백 함수입니다. 댓글 태그의 위치 조정에 사용됩니다.
  /// - [onToggleAudio]: 오디오 컨트롤 위젯이 토글될 때 호출되는 콜백 함수입니다. 오디오 재생/일시정지 등에 사용됩니다.
  /// - [pendingVoiceComments]
  ///   - 포스트 ID를 키로, 해당 포스트에 달린 음성 댓글 중 아직 서버에 등록되지 않은 댓글의 마커 정보를 값으로 가지는 맵입니다.
  ///   - 댓글 태그 렌더링에 사용됩니다.
  /// - [onCommentsReloadRequested]
  ///   - 댓글 목록을 새로고침할 때 호출되는 콜백 함수입니다.
  ///   - 댓글 태그의 최신 상태 반영에 사용됩니다.
  /// - [onExpandedMediaOverlayChanged]
  ///   - 댓글 태그의 오버레이가 확장되거나 축소될 때 호출되는 콜백 함수입니다.
  ///   - 오버레이의 표시 상태를 상위 위젯에서 관리하는 데 사용됩니다.
  ///

  const ApiPhotoDisplayWidget({
    super.key,
    required this.post,
    required this.categoryId,
    required this.categoryName,
    this.isArchive = false,
    this.isFromCamera = false,
    required this.taggingController,
    this.loadFullComments,
    required this.onProfileImageDragged,
    required this.onToggleAudio,
    this.pendingVoiceComments = const {},
    this.onCommentsReloadRequested,
    this.onExpandedMediaOverlayChanged,
    this.onExpandedMediaOverlayDismissRequested,
  });

  @override
  State<ApiPhotoDisplayWidget> createState() => _ApiPhotoDisplayWidgetState();
}

class _ApiPhotoDisplayWidgetState extends State<ApiPhotoDisplayWidget>
    with WidgetsBindingObserver {
  /// 댓글 태그의 기본 아바타 규격은 공용 댓글 태그 상수와 동일하게 유지합니다.
  static const double _avatarSize = TagProfileTagSpec.avatarSize;
  static const double _expandedAvatarSize = TagMediaTagSpec.contentSize;
  static const double _imageWidth = 354.0;
  static const double _imageHeight = 500.0;

  Size get _imageSize => Size(_imageWidth.w, _imageHeight.h);

  /// display 전용 오버레이 상태는 항상 현재 post의 공통 tagging scope에 묶입니다.
  TagScopeId get _scopeId => SoiTaggingIds.postScopeId(widget.post.id);

  String get _heroTag => 'archive_photo_${widget.categoryId}_${widget.post.id}';

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
  TagEntityId? _selectedCommentId;
  Offset? _selectedCommentPosition;
  bool _showActionOverlay = false;
  bool _isShowingComments = false;
  bool _autoOpenedOnce = false;
  bool _isCaptionExpanded = false;
  String? _uploaderProfileImageUrl;
  bool _isProfileLoading = false;
  int _profileLoadGeneration = 0;
  int _mediaLoadGeneration = 0;
  final GlobalKey _displayStackKey = GlobalKey();

  List<TagComment> get _overlayComments =>
      widget.taggingController.peekTagComments(_scopeId);

  /// 댓글 시트는 full cache가 없을 때 원댓글 미리보기를 먼저 보여 주고, 없으면 태그 캐시로 즉시 엽니다.
  List<Comment> get _parentComments =>
      context.read<CommentController>().peekParentCommentsCache(
        postId: widget.post.id,
      ) ??
      const <Comment>[];

  List<Comment> get _postComments =>
      context.read<CommentController>().peekCommentsCache(
        postId: widget.post.id,
      ) ??
      const <Comment>[];

  /// 댓글 시트 초기 진입값은 full -> parent preview -> tag overlay 순으로 선택합니다.
  List<Comment> get _initialSheetComments => _postComments.isNotEmpty
      ? _postComments
      : _parentComments.isNotEmpty
      ? _parentComments
      : SoiTagCommentMapper.toComments(_overlayComments);

  bool get _hasPendingMarker => widget.pendingVoiceComments[_scopeId] != null;

  bool get _hasComments => _overlayComments.isNotEmpty;

  bool get _hasCaption => widget.post.content?.isNotEmpty ?? false;

  /// 현재 게시물을 텍스트 전용 카드 레이아웃으로 그려야 하는지 판별합니다.
  bool get _isTextOnlyPost {
    final hasText = widget.post.content?.trim().isNotEmpty ?? false;
    return (widget.post.postType?.isTextCategory ?? false) ||
        (!widget.post.hasMedia && hasText);
  }

  String? postImageUrl;
  VideoPlayerController? _videoController;
  Future<void>? _videoInitialization;

  /// 비디오의 기본 cover/contain 표시 상태를 추적해, 서버 기본값과 사용자 토글을 함께 반영합니다.
  bool _isVideoCoverMode = false;

  /// 이미지의 기본 cover/contain 표시 상태를 추적해, 서버 기본값과 사용자 토글을 함께 반영합니다.
  bool _isImageCoverMode = false;

  // 비디오는 실제로 보이는 시점에만 초기화해서 오프스크린 디코더 메모리 넘침 현상을 막습니다.

  /// 비디오가 현재 화면에 보여지고 있는지 여부를 추적하는 상태 변수입니다.
  bool _isVideoVisible = false;

  /// videoController의 현재 초기화 세대입니다. 초기화가 필요할 때마다 증가시켜,
  /// 비디오 초기화 완료 시점에 여전히 최신 컨트롤러인지 확인하는 데 사용합니다.
  int _videoControllerGeneration = 0;

  /// 게시물 메타데이터를 읽어 첫 렌더의 미디어 fit 기본값과 URL 로딩 상태를 준비합니다.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialCoverMode = _resolveInitialMediaCoverMode();
    _isImageCoverMode = initialCoverMode;
    _isVideoCoverMode = initialCoverMode;
    _isShowingComments = _hasComments || _hasPendingMarker;
    _uploaderProfileImageUrl = _resolveImmediateProfileImageUrl();
    _isProfileLoading =
        _uploaderProfileImageUrl == null &&
        _normalizedProfileImageKey() != null;
    postImageUrl = _resolveImmediatePostMediaUrl();
    _scheduleProfileLoad();
    _schedulePostMediaLoad();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.post.isVideo) return;
    if (state == AppLifecycleState.resumed) {
      if (_isVideoVisible) {
        _ensureVideoController();
        _playVideoIfReady();
      }
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pauseVideo();
    }
  }

  @override
  void deactivate() {
    if (widget.post.isVideo) {
      _pauseVideo();
    }
    super.deactivate();
  }

  /// 같은 카드가 새 post 메타데이터를 받으면 서버 기준 fit 기본값과 미디어 URL 로딩을 다시 맞춥니다.
  @override
  void didUpdateWidget(covariant ApiPhotoDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.isFromGallery != widget.post.isFromGallery) {
      final initialCoverMode = _resolveInitialMediaCoverMode();
      setState(() {
        _isImageCoverMode = initialCoverMode;
        _isVideoCoverMode = initialCoverMode;
      });
    }

    if (_hasComments && !_autoOpenedOnce) {
      setState(() {
        _isShowingComments = true;
        _autoOpenedOnce = true;
      });
    }

    if (_hasPendingMarker && !_isShowingComments) {
      setState(() {
        _isShowingComments = true;
      });
    }

    if (oldWidget.post.userProfileImageUrl != widget.post.userProfileImageUrl ||
        oldWidget.post.userProfileImageKey != widget.post.userProfileImageKey) {
      _scheduleProfileLoad();
    }

    if (oldWidget.post.postFileUrl != widget.post.postFileUrl ||
        oldWidget.post.postFileKey != widget.post.postFileKey) {
      _schedulePostMediaLoad();
    } else {
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

  void _ensureVideoController({bool forceRecreate = false}) {
    if (!widget.post.isVideo) {
      _disposeVideoController();
      return;
    }

    // 비디오가 보여지고 있지 않다면 컨트롤러를 초기화하지 않습니다.
    // 이렇게 하면 푸시 알림에서 진입한 직후 인접 페이지의 메모리 점유를 줄일 수 있습니다.
    if (!_isVideoVisible) {
      return;
    }

    final url = postImageUrl;
    if (url == null || url.isEmpty) return;

    final currentUrl = _videoController?.dataSource;
    if (!forceRecreate && _videoController != null && currentUrl == url) {
      return;
    }

    _disposeVideoController();

    // 새로운 컨트롤러 세대 생성
    // 비디오 컨트롤러를 초기화할 때마다 세대를 증가시켜,
    // 초기화 완료 시점에 여전히 최신 컨트롤러인지 확인할 수 있도록 합니다.
    final generation = ++_videoControllerGeneration;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = controller;

    // 컨트롤러 초기화 시작
    // 초기화가 완료된 시점에, 여전히 최신 컨트롤러인지 확인하기 위해 세대 정보를 캡처합니다.
    _videoInitialization = controller.initialize().then((_) async {
      if (!mounted ||
          _videoController != controller ||
          generation != _videoControllerGeneration) {
        return;
      }
      await controller.setLooping(true); // 비디오를 반복 재생하도록 설정합니다.

      // 비디오가 초기화된 시점에 여전히 화면에 보여지고 있는 경우에만 재생을 시작합니다.
      if (_isVideoVisible) {
        await controller.play();
      }

      // 초기화가 완료된 후 UI를 업데이트합니다. 이때도 여전히 최신 컨트롤러인지 확인합니다.
      if (!mounted ||
          _videoController != controller ||
          generation != _videoControllerGeneration) {
        // 초기화가 완료되었지만, 컨트롤러가 교체되었거나 위젯이 언마운트된 경우에는 UI 업데이트를 하지 않습니다.
        // 위젯 언마운트란, 사용자가 다른 페이지로 이동하거나, 푸시 알림에서 진입한 직후 인접 페이지로 이동하는 등의 상황을 말합니다.
        //  이런 경우에는 초기화가 완료된 컨트롤러가 더 이상 화면에 표시되지 않으므로, UI 업데이트를 하지 않는 것이 메모리 관리 측면에서 유리합니다.
        return;
      }
      _safeSetState(() {});
    });
  }

  void _disposeVideoController() {
    _videoControllerGeneration++;
    _videoController?.dispose();
    _videoController = null;
    _videoInitialization = null;
  }

  void _pauseVideo() {
    final controller = _videoController;
    if (controller == null) return;
    if (!controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    }
  }

  void _playVideoIfReady() {
    final controller = _videoController;
    if (controller == null) return;
    if (!controller.value.isInitialized) return;
    if (!controller.value.isPlaying) {
      controller.play();
    }
  }

  /// 서버가 저장한 업로드 출처를 기준으로 첫 렌더의 cover/contain 기본값을 계산합니다.
  bool _resolveInitialMediaCoverMode() {
    return !widget.post.prefersContainMediaFit;
  }

  /// 서버가 내려준 작성자 프로필 URL을 첫 프레임 표시용 값으로 정규화합니다.
  String? _normalizeImageUrl(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 미디어/프로필 키를 캐시 식별과 presigned URL 재발급 기준으로 정규화합니다.
  String? _normalizeImageKey(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  /// 캡션 아바타는 서버 URL을 바로 쓰고, 없을 때만 key의 캐시된 presigned URL을 재사용합니다.
  String? _resolveImmediateProfileImageUrl() {
    final immediateUrl = _normalizeImageUrl(widget.post.userProfileImageUrl);
    if (immediateUrl != null) {
      return immediateUrl;
    }

    final profileKey = _normalizedProfileImageKey();
    if (profileKey == null) {
      return null;
    }

    try {
      return context.read<MediaController>().peekPresignedUrl(profileKey);
    } catch (_) {
      return null;
    }
  }

  /// 포토 미디어는 서버 URL을 바로 쓰고, 없을 때만 key의 캐시된 presigned URL을 재사용합니다.
  String? _resolveImmediatePostMediaUrl() {
    final immediateUrl = _normalizeImageUrl(widget.post.postFileUrl);
    if (immediateUrl != null) {
      return immediateUrl;
    }

    final postFileKey = _normalizedPostFileKey();
    if (postFileKey == null) {
      return null;
    }

    try {
      return context.read<MediaController>().peekPresignedUrl(postFileKey);
    } catch (_) {
      return null;
    }
  }

  /// 작성자 프로필 key는 캐시와 presigned URL 갱신의 단일 기준으로 사용합니다.
  String? _normalizedProfileImageKey() {
    return _normalizeImageKey(widget.post.userProfileImageKey);
  }

  /// 게시물 미디어 key는 캐시와 presigned URL 갱신의 단일 기준으로 사용합니다.
  String? _normalizedPostFileKey() {
    return _normalizeImageKey(widget.post.postFileKey);
  }

  /// 캡션 아바타는 key를 우선 캐시 식별자로 쓰고, 없을 때만 URL 기반 식별자를 계산합니다.
  String? _resolveProfileCacheKey() {
    final profileKey = _normalizedProfileImageKey();
    if (profileKey != null) {
      return profileKey;
    }

    final profileImageUrl = _normalizeImageUrl(_uploaderProfileImageUrl);
    if (profileImageUrl == null) {
      return null;
    }

    final uri = Uri.tryParse(profileImageUrl);
    if (uri == null || !uri.hasScheme) {
      return null;
    }

    final normalizedHost = uri.host.trim();
    final normalizedPath = uri.path.trim();
    if (normalizedPath.isEmpty) {
      return null;
    }

    return normalizedHost.isEmpty
        ? normalizedPath
        : '$normalizedHost$normalizedPath';
  }

  /// 캡션 오버레이 작성자 아바타는 URL을 먼저 표시하고, key가 있으면 최신 presigned URL로 백그라운드 갱신합니다.
  Future<void> _loadProfileImage() async {
    final requestId = ++_profileLoadGeneration;
    final immediateUrl = _resolveImmediateProfileImageUrl();
    final profileKey = _normalizedProfileImageKey();

    _safeSetState(() {
      _uploaderProfileImageUrl = immediateUrl;
      _isProfileLoading = immediateUrl == null && profileKey != null;
    });

    if (profileKey == null) {
      return;
    }

    try {
      final resolvedUrl = _normalizeImageUrl(
        await context.read<MediaController>().getPresignedUrl(profileKey),
      );
      if (!mounted || requestId != _profileLoadGeneration) {
        return;
      }

      _safeSetState(() {
        _uploaderProfileImageUrl = resolvedUrl ?? immediateUrl;
        _isProfileLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _profileLoadGeneration) {
        return;
      }

      _safeSetState(() {
        _uploaderProfileImageUrl = immediateUrl;
        _isProfileLoading = false;
      });
    }
  }

  /// 화면 미디어 URL이 바뀌면 로컬 상태만 갱신하고, 비디오 컨트롤러는 현재 가시성에 맞춰 다시 맞춥니다.
  void _applyPostMediaUrl(String? nextUrl) {
    final normalizedNextUrl = _normalizeImageUrl(nextUrl);
    final previousUrl = postImageUrl;
    if (previousUrl == normalizedNextUrl) {
      return;
    }

    _safeSetState(() {
      postImageUrl = normalizedNextUrl;
    });

    if (!widget.post.isVideo) {
      return;
    }

    if (_isVideoVisible && normalizedNextUrl != null) {
      _ensureVideoController(forceRecreate: true);
      return;
    }

    _disposeVideoController();
  }

  /// 포토 미디어는 URL을 먼저 표시하고, key가 있으면 최신 presigned URL로 백그라운드 갱신합니다.
  Future<void> _loadPostMediaUrl() async {
    final requestId = ++_mediaLoadGeneration;
    final immediateUrl = _resolveImmediatePostMediaUrl();
    final postFileKey = _normalizedPostFileKey();
    _applyPostMediaUrl(immediateUrl);

    if (postFileKey == null) {
      return;
    }

    try {
      final resolvedUrl = _normalizeImageUrl(
        await context.read<MediaController>().getPresignedUrl(postFileKey),
      );
      if (!mounted || requestId != _mediaLoadGeneration) {
        return;
      }

      _applyPostMediaUrl(resolvedUrl ?? immediateUrl);
    } catch (_) {
      if (!mounted || requestId != _mediaLoadGeneration) {
        return;
      }
    }
  }

  /// 프레임 안정화 이후 작성자 아바타 refresh를 시작해 build 중 provider 접근을 피합니다.
  void _scheduleProfileLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProfileImage();
      }
    });
  }

  /// 프레임 안정화 이후 포스트 미디어 refresh를 시작해 URL 교체와 비디오 컨트롤러 재생성을 분리합니다.
  void _schedulePostMediaLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadPostMediaUrl();
      }
    });
  }

  void _handleVideoVisibilityChanged(bool visible) {
    if (_isVideoVisible == visible) {
      return;
    }

    // 보이는 동안만 controller를 유지해 푸시 진입 직후 인접 페이지 메모리 점유를 줄입니다.
    _isVideoVisible = visible;
    if (!visible) {
      _disposeVideoController();
      _safeSetState(() {});
      return;
    }

    _ensureVideoController();
    _playVideoIfReady();
    _safeSetState(() {});
  }

  void _notifyExpandedMediaOverlay(ExpandedMediaTagOverlayData? data) {
    widget.onExpandedMediaOverlayChanged?.call(data);
  }

  void _clearExpandedMediaOverlay() {
    _notifyExpandedMediaOverlay(null);
  }

  /// 확장된 미디어 오버레이를 표시하기 위해 필요한 데이터를 계산하고, 상위 위젯에 전달하는 함수입니다.
  void _emitExpandedMediaOverlay({
    required String tagKey,
    required TagComment comment,
    required Offset localCircleCenter,
    required double collapsedContentSize,
    required double expandedContentSize,
    VoidCallback? onLongPress,
  }) {
    final callback = widget.onExpandedMediaOverlayChanged;
    if (callback == null) return;

    final renderBox = _displayStackKey.currentContext?.findRenderObject();
    if (renderBox is! RenderBox) return;

    final globalCircleCenter = renderBox.localToGlobal(localCircleCenter);
    callback(
      ExpandedMediaTagOverlayData(
        tagKey: tagKey,
        comment: comment,
        globalCircleCenter: globalCircleCenter,
        collapsedContentSize: collapsedContentSize,
        expandedContentSize: expandedContentSize,
        onDismiss: _collapseExpandedMediaTag,
        onLongPress: onLongPress,
      ),
    );
  }

  void _collapseExpandedMediaTag() {
    _requestExpandedMediaTagDismissal();
  }

  /// 확장 태그 닫힘 애니메이션이 끝난 뒤 로컬 선택 상태와 오버레이 상태를 함께 정리합니다.
  void _finalizeExpandedMediaTagDismissal() {
    if (!mounted) return;
    if (_expandedMediaTagKey == null) {
      _clearExpandedMediaOverlay();
      return;
    }
    setState(() {
      _expandedMediaTagKey = null;
    });
    _clearExpandedMediaOverlay();
  }

  /// 상위 카드가 reverse 애니메이션을 지원하면 거기에 위임하고, 없으면 즉시 태그를 닫습니다.
  Future<void> _requestExpandedMediaTagDismissal() async {
    if (!mounted) return;
    if (_expandedMediaTagKey == null) {
      _clearExpandedMediaOverlay();
      return;
    }

    final dismissRequest = widget.onExpandedMediaOverlayDismissRequested;
    if (dismissRequest == null ||
        widget.onExpandedMediaOverlayChanged == null) {
      _finalizeExpandedMediaTagDismissal();
      return;
    }

    await dismissRequest(_finalizeExpandedMediaTagDismissal);
  }

  /// 댓글 태그가 탭되어 확장된 미디어 오버레이를 표시할 때 필요한 데이터를 계산하고, 상위 위젯에 전달하는 함수입니다.
  void _showExpandedMediaOverlay({
    required String tagKey,
    required TagComment comment,
    required Offset tipAnchor,
    VoidCallback? onLongPress,
  }) {
    final localCircleCenter = TagGeometryService.tagCircleCenterFromTipAnchor(
      tipAnchor,
      _avatarSize,
    );

    // 확장된 미디어 오버레이를 표시하기 위해 필요한 데이터를 계산하고, 상위 위젯에 전달합니다.
    _emitExpandedMediaOverlay(
      tagKey: tagKey,
      comment: comment,
      localCircleCenter: localCircleCenter,
      collapsedContentSize: _avatarSize,
      expandedContentSize: _expandedAvatarSize,
      onLongPress: onLongPress,
    );
  }

  /// 댓글 태그를 탭했을 때의 행동을 처리하는 함수입니다. 댓글의 타입과 현재 오버레이 상태에 따라 다른 행동을 수행합니다.
  /// - 댓글이 포토 타입인 경우:
  ///   - 해당 댓글이 확장 가능한 미디어 댓글인지 확인합니다.
  ///     - 확장이 불가능한 경우: 댓글 시트를 엽니다.
  ///     - 확장 가능한 경우: 현재 오버레이가 해당 댓글의 태그인지 확인합니다. 이미 확장된 태그를 탭한 경우, 오버레이를 축소합니다.
  /// - 댓글이 포토 타입이 아닌 경우:
  ///   - 현재 확장된 미디어 태그가 있다면 축소합니다.
  ///   - 댓글 시트를 엽니다.
  Future<void> _handleCommentTap({
    required TagComment comment,
    required String key,
    required Offset tipAnchor,
  }) async {
    if (comment.isImage || comment.isVideo) {
      if (!comment.hasMediaAttachment) {
        _openCommentSheet(key);
        return;
      }

      if (widget.onExpandedMediaOverlayChanged == null) {
        _openCommentSheet(key);
        return;
      }

      if (_expandedMediaTagKey == key) {
        await _requestExpandedMediaTagDismissal();
        return;
      }

      setState(() {
        _expandedMediaTagKey = key;
      });

      // 미디어 태그 오버레이를 확장된 상태로 표시합니다.
      // 이때, 오버레이가 탭된 태그에 맞게 표시되도록 필요한 데이터를 전달합니다.
      _showExpandedMediaOverlay(
        tagKey: key,
        comment: comment,
        tipAnchor: tipAnchor,
        onLongPress: () => _handleCommentLongPress(
          key: key,
          commentId: comment.id,
          position: tipAnchor,
        ),
      );
      return;
    }

    if (_expandedMediaTagKey != null) {
      await _requestExpandedMediaTagDismissal();
    }
    _openCommentSheet(key);
  }

  Future<void> _handleBaseTap() async {
    if (_showActionOverlay) {
      _dismissOverlay();
      return;
    }
    if (_expandedMediaTagKey != null) {
      await _requestExpandedMediaTagDismissal();
      return;
    }
    if (_hasComments || _hasPendingMarker) {
      setState(() {
        _isShowingComments = !_isShowingComments;
        if (!_isShowingComments) {
          _expandedMediaTagKey = null;
        }
      });
      if (!_isShowingComments) {
        _clearExpandedMediaOverlay();
      }
    }
  }

  void _dismissOverlay() {
    setState(() {
      _showActionOverlay = false;
      _selectedCommentKey = null;
      _expandedMediaTagKey = null;
      _selectedCommentId = null;
      _selectedCommentPosition = null;
    });
    _clearExpandedMediaOverlay();
  }

  void _openCommentSheet(String selectedKey) {
    final comments = _initialSheetComments;
    if (_expandedMediaTagKey != null) {
      _finalizeExpandedMediaTagDismissal();
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ChangeNotifierProvider(
          create: (_) => AudioController(),
          child: ApiVoiceCommentListSheet(
            postId: widget.post.id,
            initialComments: comments,
            loadFullComments: widget.loadFullComments,
            selectedCommentId: selectedKey,
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
  }

  void _handleCommentLongPress({
    required String key,
    required TagEntityId? commentId,
    required Offset position,
  }) {
    if (commentId == null) {
      _showSnackBar(tr('comments.delete_unavailable', context: context));
      return;
    }
    setState(() {
      _selectedCommentKey = key;
      _expandedMediaTagKey = null;
      _selectedCommentId = commentId;
      _selectedCommentPosition = position;
      _showActionOverlay = true;
    });
    _clearExpandedMediaOverlay();
  }

  Future<void> _deleteSelectedComment() async {
    final targetId = _selectedCommentId;
    if (targetId == null) return;
    final numericCommentId = SoiTaggingIds.intFromEntityId(targetId);
    if (numericCommentId == null) {
      _showSnackBar(tr('comments.delete_unavailable', context: context));
      return;
    }
    try {
      final commentController = Provider.of<CommentController>(
        context,
        listen: false,
      );
      final success = await commentController.deleteComment(numericCommentId);
      if (!mounted) return;
      if (success) {
        _removeCommentFromCache(targetId);
        await widget.onCommentsReloadRequested?.call(widget.post.id);
        if (!mounted) return;
        _showSnackBar(tr('comments.delete_success', context: context));
        _dismissOverlay();
      } else {
        _showSnackBar(tr('comments.delete_failed', context: context));
      }
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(tr('comments.delete_error', context: context));
    }
  }

  void _removeCommentFromCache(TagEntityId commentId) {
    widget.taggingController.removeCommentFromCache(
      scopeId: _scopeId,
      commentId: commentId,
    );
  }

  /// 댓글시트의 full thread 결과를 controller cache 한 곳에 반영합니다.
  void _replaceCommentCaches(List<Comment> updatedComments) {
    widget.taggingController.replaceCommentsCache(
      _scopeId,
      SoiTagCommentMapper.fromComments(updatedComments, scopeId: _scopeId),
    );
  }

  void _navigateToCategory() {
    final controller = context.read<api_category.CategoryController?>();
    final category = controller?.getCategoryById(widget.categoryId);
    if (category == null) {
      _showSnackBar('카테고리 정보를 불러오지 못했습니다.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApiCategoryPhotosScreen(category: category),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    SnackBarUtils.showSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    // 이 카드와 관련된 댓글 cache 변화만 구독해 오버레이와 시트 진입값을 최신으로 유지합니다.
    context.select<
      CommentController,
      ({List<Comment>? full, List<Comment>? parent, List<Comment>? tag})
    >(
      (controller) => (
        full: controller.peekCommentsCache(postId: widget.post.id),
        parent: controller.peekParentCommentsCache(postId: widget.post.id),
        tag: controller.peekTagCommentsCache(postId: widget.post.id),
      ),
    );
    final categoryTrimmed = widget.categoryName.trim();
    final isEnglishCategory =
        categoryTrimmed.isNotEmpty &&
        RegExp(r'^[A-Za-z\s]+$').hasMatch(categoryTrimmed);
    final waveformData = ApiPhotoWaveformParserService.parse(
      widget.post.waveformData,
    );
    final deletePopup =
        _showActionOverlay &&
            _selectedCommentPosition != null &&
            _selectedCommentId != null
        ? ApiPhotoDeleteActionPopup(
            position: _selectedCommentPosition!,
            imageWidth: _imageSize.width,
            onDeleteTap: _deleteSelectedComment,
          )
        : null;
    final showCaptionOverlay = _hasCaption && !_isTextOnlyPost;

    return Center(
      child: SizedBox(
        width: _imageSize.width,
        height: _imageSize.height,
        child: Builder(
          builder: (builderContext) {
            final mediaBase = ApiPhotoMediaContent(
              isTextOnlyPost: _isTextOnlyPost,
              isVideoPost: widget.post.isVideo,
              hasImage: widget.post.hasImage,
              mediaUrl: postImageUrl,
              postFileKey: widget.post.postFileKey,
              textContent: widget.post.content ?? '',
              imageSize: _imageSize,
              videoController: _videoController,
              videoInitialization: _videoInitialization,
              isVideoCoverMode: _isVideoCoverMode,
              isImageCoverMode: _isImageCoverMode,
              onVideoToggleFit: () {
                if (!mounted) return;
                setState(() {
                  _isVideoCoverMode = !_isVideoCoverMode;
                });
              },
              onImageToggleFit: () {
                if (!mounted) return;
                setState(() {
                  _isImageCoverMode = !_isImageCoverMode;
                });
              },
              onVideoVisibilityChanged: _handleVideoVisibilityChanged,
            );

            final mediaFrame = _isTextOnlyPost
                ? mediaBase
                : ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: mediaBase,
                  );

            final mediaWithHero = widget.isArchive
                ? Hero(
                    tag: _heroTag,
                    createRectTween: (begin, end) =>
                        MaterialRectArcTween(begin: begin, end: end),
                    transitionOnUserGestures: true,
                    flightShuttleBuilder: _heroFlightShuttleBuilder,
                    child: mediaFrame,
                  )
                : mediaFrame;

            // 드래그 앤 드롭을 위한 DragTarget으로 전체 영역을 감싸서, 프로필 태그가 드롭될 때 위치 정보를 받을 수 있도록 합니다.
            return DragTarget<String>(
              onWillAcceptWithDetails: (details) => details.data.isNotEmpty,
              onAcceptWithDetails: (details) {
                final renderBox =
                    builderContext.findRenderObject() as RenderBox?;
                if (renderBox == null) return;
                final localPosition = renderBox.globalToLocal(details.offset);
                final tipOffset = TagBubble.pointerTipOffset(
                  contentSize: _avatarSize,
                  padding: TagProfileTagSpec.padding,
                );
                widget.onProfileImageDragged(
                  widget.post.id,
                  localPosition + tipOffset,
                );
              },
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  onTap: () {
                    _handleBaseTap();
                  },
                  child: Stack(
                    key: _displayStackKey,
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      mediaWithHero,
                      if (_showActionOverlay)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: _dismissOverlay,
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      if (!widget.isArchive)
                        Positioned(
                          top: 11.h,
                          child: GestureDetector(
                            onTap: _navigateToCategory,
                            child: IntrinsicWidth(
                              // 카테고리 이름을 감싸는 컨테이너로, 텍스트 길이에 따라 크기가 조절됩니다.
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
                      if (!widget.post.hasAudio && showCaptionOverlay)
                        Positioned(
                          left: 16.w,
                          right: 16.w,
                          bottom: 18.h,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 캡션이 있는 게시물에서, 작성자 아바타와 캡션 텍스트를 함께 오버레이로 표시합니다.
                              Expanded(
                                child: ApiPhotoCaptionOverlay(
                                  content: widget.post.content!,
                                  isExpanded: _isCaptionExpanded,
                                  isProfileLoading: _isProfileLoading,
                                  profileImageUrl: _uploaderProfileImageUrl,
                                  profileImageCacheKey:
                                      _resolveProfileCacheKey(),
                                  onTap: () {
                                    if (!mounted) return;
                                    setState(() {
                                      _isCaptionExpanded = !_isCaptionExpanded;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      // 댓글이 있는 경우, 댓글 태그를 미디어 위에 오버레이로 렌더링합니다.
                      Positioned.fill(
                        child: TagOverlay(
                          comments: _overlayComments,
                          pendingMarker: widget.pendingVoiceComments[_scopeId],
                          isShowingComments: _isShowingComments,
                          showActionOverlay: _showActionOverlay,
                          selectedCommentKey: _selectedCommentKey,
                          expandedMediaTagKey: _expandedMediaTagKey,
                          imageSize: _imageSize,
                          canExpandEntry: (entry) => entry.hasMediaAttachment,
                          commentAvatarBuilder:
                              SoiTaggingAvatarBuilders.buildCommentAvatar,
                          pendingAvatarBuilder:
                              SoiTaggingAvatarBuilders.buildPendingMarkerAvatar,
                          onCommentTap: _handleCommentTap,
                          onCommentLongPress: _handleCommentLongPress,
                        ),
                      ),
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
