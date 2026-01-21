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
import 'api_voice_comment_list_sheet.dart';
import 'pending_api_voice_comment.dart';
import 'package:soi/api/controller/media_controller.dart';

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
  final Map<int, List<Comment>> postComments;
  final Function(int, Offset) onProfileImageDragged;
  final Function(Post) onToggleAudio;
  final Map<int, PendingApiCommentMarker> pendingVoiceComments;
  final Future<void> Function(int postId)? onCommentsReloadRequested;

  const ApiPhotoDisplayWidget({
    super.key,
    required this.post,
    required this.categoryId,
    required this.categoryName,
    this.isArchive = false,
    required this.postComments,
    required this.onProfileImageDragged,
    required this.onToggleAudio,
    this.pendingVoiceComments = const {},
    this.onCommentsReloadRequested,
  });

  @override
  State<ApiPhotoDisplayWidget> createState() => _ApiPhotoDisplayWidgetState();
}

class _ApiPhotoDisplayWidgetState extends State<ApiPhotoDisplayWidget>
    with WidgetsBindingObserver {
  static const double _avatarSize = 27.0;
  static const double _avatarRadius = 13.5;
  static const double _imageWidth = 354.0;
  static const double _imageHeight = 500.0;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    // Avoid mutating the element/render tree during layout/paint/semantics work.
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
  int? _selectedCommentId;
  Offset? _selectedCommentPosition;
  bool _showActionOverlay = false;
  bool _isShowingComments = false;
  bool _autoOpenedOnce = false;
  bool _isCaptionExpanded = false;
  String? _uploaderProfileImageUrl;
  bool _isProfileLoading = false;
  late final MediaController _mediaController;

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
    _isShowingComments =
        _hasComments || _hasPendingMarker; // 댓글/대기 마커가 있으면 댓글 표시
    _mediaController = Provider.of<MediaController>(
      context,
      listen: false,
    ); // 미디어 컨트롤러 인스턴스 가져오기
    _scheduleProfileLoad(widget.post.userProfileImageKey); // 프로필 이미지 로드 예약

    if (widget.post.postFileKey?.isNotEmpty ?? false) {
      // 추가: presigned URL은 매번 달라질 수 있어서(=캐시 미스),
      // 이미 발급/캐싱된 URL이 있으면 첫 프레임부터 바로 보여주도록 합니다.
      postImageUrl = _mediaController.peekPresignedUrl(
        widget.post.postFileKey!,
      );

      _loadPostImage(widget.post.postFileKey!); // 게시물 이미지 로드
    } else {
      postImageUrl = null; // 게시물 이미지 키가 없으면 null로 설정
    }
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
    // 프로필 이미지 키가 변경되었는지 확인
    if (oldWidget.post.userProfileImageKey != widget.post.userProfileImageKey) {
      // 프로필 이미지가 변경되었으므로 프레임 콜백으로 로드 예약
      _scheduleProfileLoad(widget.post.userProfileImageKey);
    }

    // 게시물 이미지 키가 변경되었는지 확인
    if (oldWidget.post.postFileKey != widget.post.postFileKey) {
      // 추가: 새 key의 presigned URL이 캐시에 있으면 즉시 UI에 반영(쉬머 최소화)
      _safeSetState(() {
        final newKey = widget.post.postFileKey;
        postImageUrl = (newKey != null && newKey.isNotEmpty)
            ? _mediaController.peekPresignedUrl(newKey)
            : null;
      });

      // 게시물 이미지가 변경되었으므로 새로 로드
      _loadPostImage(widget.post.postFileKey!);

      // 비디오 컨트롤러 갱신
      _ensureVideoController(forceRecreate: true);
    }
    // 게시물 이미지 키가 동일한 경우
    else {
      // 비디오 컨트롤러 갱신
      _ensureVideoController();
    }
  }

  /// 게시물 이미지 로드
  ///
  /// Parameters:
  ///   - [key]: 미디어 파일의 키
  Future<void> _loadPostImage(String key) async {
    // 키가 비어있는 경우 처리
    if (widget.post.postFileKey == null || widget.post.postFileKey!.isEmpty) {
      _safeSetState(() {
        // 이미지 URL을 null로 설정
        postImageUrl = null;
      });
      return;
    }

    try {
      // 추가: 네트워크 요청 전에, 캐시된 presigned URL이 있으면 먼저 보여줍니다.
      final cached = _mediaController.peekPresignedUrl(key);
      if (cached != null && cached != postImageUrl) {
        _safeSetState(() {
          postImageUrl = cached;
        });
      }

      // 미디어 컨트롤러를 사용하여 presignedURL 가져오기
      final url = await _mediaController.getPresignedUrl(key);
      if (!mounted) return;
      _safeSetState(() {
        // 가지고 온 URL을 postImageUrl에 설정
        postImageUrl = url;
      });

      // 비디오 컨트롤러 갱신
      _ensureVideoController();
    } catch (_) {
      if (!mounted) return;
      _safeSetState(() {
        // 오류 발생 시 이미지 URL을 null로 설정
        postImageUrl = null;
      });
    }
  }

  /// 비디오 컨트롤러 초기화 및 갱신
  ///
  /// Parameters:
  ///   - [forceRecreate]: 강제로 컨트롤러를 재생성할지 여부
  void _ensureVideoController({bool forceRecreate = false}) {
    // 비디오가 아닌 경우
    if (!widget.post.isVideo) {
      // 기존 비디오 컨트롤러 해제
      _disposeVideoController();
      return;
    }

    // 비디오 URL 가져오기
    final url = postImageUrl;
    if (url == null || url.isEmpty) return;

    // 현재 비디오 컨트롤러의 데이터 소스 가져오기
    final currentUrl = _videoController?.dataSource;

    // 같은 URL이고 강제 재생성이 아닌 경우 리턴
    if (!forceRecreate && _videoController != null && currentUrl == url) {
      return;
    }

    // 기존 비디오 컨트롤러 해제
    _disposeVideoController();

    // 새로운 비디오 컨트롤러 생성
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));

    // 새로운 비디오 컨트롤러 설정 및 초기화
    _videoController = controller;

    // 비디오 초기화 Future 설정
    _videoInitialization = controller.initialize().then((_) async {
      // video 초기화 완료 후 반복 재생 설정
      await controller.setLooping(true);
      // 비디오가 보이는 상태라면 재생 시작
      if (_isVideoVisible) {
        await controller.play();
      }
      // 상태 업데이트
      _safeSetState(() {});
    });
  }

  /// 비디오 컨트롤러 해제
  /// 비디오 컨트롤러를 해제하고 관련 리소스를 정리합니다.
  void _disposeVideoController() {
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeVideoController();
    super.dispose();
  }

  /// String 형태의 웨이브폼 데이터를 `List<double>` 형태로 파싱
  ///
  /// Parameters:
  ///   - [waveformString]: 웨이브폼 데이터 문자열
  ///
  /// Returns:
  ///   - `List<double>`: 파싱된 웨이브폼 데이터 리스트 (없으면 null)
  ///     - null: 파싱 실패 또는 데이터 없음
  List<double>? _parseWaveformData(String? waveformString) {
    // 입력 문자열이 null이거나 비어있는 경우 null 반환
    if (waveformString == null || waveformString.isEmpty) {
      return null;
    }

    // 문자열 양쪽 공백 제거
    // 양쪽의 대괄호([]) 제거 --> waveform을 String으로 저장해두기 때문에
    final trimmed = waveformString.trim();
    if (trimmed.isEmpty) return null;

    try {
      // JSON 디코딩 시도
      final decoded = jsonDecode(trimmed);

      // 디코딩된 결과가 리스트인 경우, 각 요소를 double로 변환하여 리스트로 반환
      if (decoded is List) {
        // 각 요소를 double로 변환하여 리스트로 반환
        return decoded.map((e) => (e as num).toDouble()).toList();
      }
    } catch (_) {
      // JSON 디코딩 실패 시 수동 파싱 시도 --> 대괄호([]) 제거 후 쉼표 또는 공백으로 분리
      final sanitized = trimmed.replaceAll('[', '').replaceAll(']', '').trim();

      // 대괄호 제거 후 남은 문자열이 비어있는지 확인
      // 비어있으면 null 반환
      if (sanitized.isEmpty) return null;

      // 문자열을 쉼표 또는 공백으로 분리하여 double로 변환
      final parts = sanitized
          .split(RegExp(r'[,\s]+'))
          .where((part) => part.isNotEmpty);
      try {
        // 각 부분을 double로 변환하여 리스트로 반환
        final values = parts.map((part) => double.parse(part)).toList();

        // 변환된 값이 비어있으면 null 반환, 아니면 값 반환
        return values.isEmpty ? null : values;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// 프로필 이미지 로드
  ///
  /// Parameters:
  ///  - [key]: 프로필 이미지의 미디어 키
  Future<void> _loadProfileImage(String? key) async {
    // 키가 없거나 비어있는 경우 처리
    if (key == null || key.isEmpty) {
      _safeSetState(() {
        // 프로필 이미지 URL을 null로 설정
        _uploaderProfileImageUrl = null;
        _isProfileLoading = false;
      });
      return;
    }

    _safeSetState(() => _isProfileLoading = true);
    try {
      final url = await _mediaController.getPresignedUrl(key);
      if (!mounted) return;
      _safeSetState(() {
        _uploaderProfileImageUrl = url;
        _isProfileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      _safeSetState(() {
        _uploaderProfileImageUrl = null;
        _isProfileLoading = false;
      });
    }
  }

  /// 프로필 이미지 로드를 프레임 콜백으로 예약
  void _scheduleProfileLoad(String? key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadProfileImage(key);
      }
    });
  }

  /// 미디어(이미지 또는 비디오) 콘텐츠 빌드
  Widget _buildMediaContent() {
    if (widget.post.isVideo) {
      if (postImageUrl == null || postImageUrl!.isEmpty) {
        // postImageUrl가 아직 로드되지 않았거나 비어있는 경우에 띄울 위젯 빌드
        return _buildMediaPlaceholder();
      }

      // 비디오 컨트롤러 사용
      final controller = _videoController;

      // 비디오 컨트롤러와 초기화 Future가 준비되지 않은 경우
      final init = _videoInitialization;

      // 컨트롤러나 초기화 Future가 null인 경우 지원되지 않는 미디어 위젯 빌드
      if (controller == null || init == null) {
        return _buildUnsupportedMedia();
      }

      return FutureBuilder(
        future: init,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              !controller.value.isInitialized) {
            return _buildMediaPlaceholder();
          }

          // 비디오를 VisibilityDetector로 감싸서 화면에 보이는지 감지
          // 60% 이상 보일 때 재생, 그렇지 않으면 일시정지
          return VisibilityDetector(
            key: ValueKey('api_video_${widget.post.id}'),
            onVisibilityChanged: (info) {
              final visible = info.visibleFraction >= 0.6; // 60% 이상 보이는지 여부
              if (_isVideoVisible == visible) return; // 상태가 변경되지 않은 경우 리턴
              _isVideoVisible = visible; // 상태 업데이트 --> 재생/일시정지 제어
              if (visible) {
                _playVideoIfReady(); // 비디오가 60% 이상 보이면 재생
              } else {
                _pauseVideo(); // 비디오가 60% 미만이면 일시정지
              }
            },
            child: GestureDetector(
              onDoubleTap: () {
                if (!mounted) return;
                setState(() {
                  _isVideoCoverMode = !_isVideoCoverMode;
                });
              },
              child: Container(
                width: _imageWidth.w,
                height: _imageHeight.h,
                clipBehavior: Clip.antiAlias, // BoxFit.cover 시 overflow 방지
                decoration: BoxDecoration(
                  color: Colors.black, // 원본 비율일 때 여백 색상
                  border: Border.all(
                    color: Color(0xff2b2b2b), // 테두리 색상
                    width: 2.0, // 테두리 두께
                  ),
                  borderRadius: BorderRadius.circular(20.0), // 모서리 둥글게
                ),
                // border 안쪽을 정확히 클리핑 (borderRadius - borderWidth)
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18.0),
                  child: FittedBox(
                    fit: _isVideoCoverMode ? BoxFit.cover : BoxFit.contain,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    if (widget.post.hasImage) {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final url = postImageUrl;

      // 추가: URL이 아직 없으면(=presigned URL 발급 전) CachedNetworkImage에 빈 URL을 넣지 않고
      // 우리가 원하는 쉬머 UI만 보여줍니다. (불필요한 실패/깜빡임 방지)
      if (url == null || url.isEmpty) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[800]!,
          highlightColor: Colors.grey[600]!,
          child: Container(
            width: _imageWidth.w,
            height: _imageHeight.h,
            color: Colors.grey[800],
          ),
        );
      }

      // 더블탭으로 비율 전환 (기본: 원본 비율)
      return GestureDetector(
        onDoubleTap: () {
          if (!mounted) return;
          setState(() {
            _isImageCoverMode = !_isImageCoverMode;
          });
        },
        child: Container(
          width: _imageWidth.w,
          height: _imageHeight.h,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black, // 원본 비율일 때 여백 색상
            border: Border.all(
              color: Color(0xff2b2b2b), // 테두리 색상
              width: 2.0, // 테두리 두께
            ),
            borderRadius: BorderRadius.circular(20.0), // 모서리 둥글게
          ),
          // border 안쪽을 정확히 클리핑 (borderRadius - borderWidth)
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18.0),
            child: CachedNetworkImage(
              imageUrl: url,
              // 추가: presigned URL이 바뀌어도(쿼리스트링 변경 등) 같은 파일 key면 같은 캐시를 쓰게 함
              cacheKey: widget.post.postFileKey,
              useOldImageOnUrlChange: true, // URL 변경 시에도 이전 이미지 유지(체감 깜빡임 감소)
              fadeInDuration: Duration.zero, // 로드 후 페이드 제거(체감 쉬머 감소)
              fadeOutDuration: Duration.zero,
              width: _imageWidth.w,
              height: _imageHeight.h,
              fit: _isImageCoverMode
                  ? BoxFit.cover
                  : BoxFit.contain, // 더블탭으로 전환
              memCacheWidth: ((354.w * dpr).round()),
              maxWidthDiskCache: (354.w * dpr).round(),
              placeholder: (context, _) => Shimmer.fromColors(
                baseColor: Colors.grey[800]!,
                highlightColor: Colors.grey[600]!,
                child: Container(
                  width: _imageWidth.w,
                  height: _imageHeight.h,
                  color: Colors.grey[800],
                ),
              ),
              errorWidget: (context, _, __) => Container(
                width: _imageWidth.w,
                height: _imageHeight.h,
                color: Colors.grey[800],
                child: Icon(
                  Icons.broken_image,
                  color: Colors.grey[600],
                  size: 50.w,
                ),
              ),
            ),
          ), // ClipRRect 닫기
        ),
      );
    }

    return _buildUnsupportedMedia();
  }

  Widget _buildUnsupportedMedia() {
    return Container(
      width: _imageWidth.w,
      height: _imageHeight.h,
      color: Colors.grey[800],
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[600],
        size: 50.w,
      ),
    );
  }

  Widget _buildMediaPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: Container(
        width: _imageWidth.w,
        height: _imageHeight.h,
        color: Colors.grey[800],
      ),
    );
  }

  /// 댓글의 프로필 이미지를 위치에 맞게 배치
  List<Widget> _buildCommentAvatars() {
    if (!_isShowingComments) return const [];

    final filteredComments = _postComments
        .where(
          (c) =>
              (c.type == CommentType.text || c.type == CommentType.audio) &&
              c.hasLocation,
        )
        .toList();

    final actualSize = Size(_imageWidth.w, _imageHeight.h);

    return List<Widget>.generate(filteredComments.length, (index) {
      final comment = filteredComments[index];
      final key = '${index}_${comment.hashCode}';
      final relative = Offset(
        comment.locationX ?? 0.5,
        comment.locationY ?? 0.5,
      );
      final absolute = PositionConverter.toAbsolutePosition(
        relative,
        actualSize,
      );
      final clamped = PositionConverter.clampPosition(absolute, actualSize);
      final hideOther =
          _showActionOverlay &&
          _selectedCommentKey != null &&
          key != _selectedCommentKey;
      if (hideOther) {
        return const SizedBox.shrink();
      }

      final isSelected = _selectedCommentKey == key;

      return Positioned(
        left: clamped.dx - _avatarRadius,
        top: clamped.dy - _avatarRadius,
        child: GestureDetector(
          onTap: () => _openCommentSheet(key),
          onLongPress: () => _handleCommentLongPress(
            key: key,
            commentId: comment.id,
            position: clamped,
          ),
          child: _buildCircleAvatar(
            imageUrl: comment.userProfile,
            size: _avatarSize,
            showBorder: isSelected,
            borderColor: Colors.white,
          ),
        ),
      );
    });
  }

  /// 업로드 중인 음성 댓글 마커 빌드
  /// 대기 중인 음성 댓글이 있으면 해당 위치에 마커를 표시합니다.
  /// 업로드 되기 전에, 댓글이 UI에 미리 보이도록 합니다.
  Widget? _buildPendingMarker() {
    final pending = widget.pendingVoiceComments[widget.post.id];
    if (pending == null) {
      return null;
    }

    final actualSize = Size(_imageWidth.w, _imageHeight.h);
    final absolute = PositionConverter.toAbsolutePosition(
      pending.relativePosition,
      actualSize,
    );
    final clamped = PositionConverter.clampPosition(absolute, actualSize);

    return Positioned(
      left: clamped.dx - _avatarRadius,
      top: clamped.dy - _avatarRadius,
      child: IgnorePointer(
        child: _buildPendingProgressAvatar(
          imageUrl: pending.profileImageUrlKey,
          size: _avatarSize,
          progress: pending.progress,
          opacity: 0.85,
        ),
      ),
    );
  }

  /// 원형 아바타 위젯 빌드
  /// 프로필 이미지 URL을 사용하여 원형 아바타를 생성합니다.
  ///
  /// Parameters:
  ///   - [imageUrl]: 아바타 이미지 URL
  ///   - [size]: 아바타 크기
  ///   - [progress]: 진행률 (0.0 ~ 1.0)
  ///   - [opacity]: 아바타 투명도 (기본값: 1.0)
  Widget _buildPendingProgressAvatar({
    required String? imageUrl, // 프로필 이미지 URL
    required double size, // 프로필 이미지 크기
    required double? progress, // 업로드 진행률 (0.0 ~ 1.0)
    double opacity = 1.0, // 프로필 이미지 투명도 (기본값 1.0)
  }) {
    // 프로그레스 링 크기
    final ringSize = size + 3.0;

    // 원형 프로그레스 링과 아바타를 겹쳐서 표시
    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: CircularProgressIndicator(
              value: progress?.clamp(0.0, 2.0),
              strokeWidth: 2.0,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
              backgroundColor: Colors.transparent,
            ),
          ),
          _buildCircleAvatar(imageUrl: imageUrl, size: size, opacity: opacity),
        ],
      ),
    );
  }

  /// 댓글 삭제 액션 팝업 빌드
  Widget? _buildDeleteActionPopup() {
    if (!_showActionOverlay ||
        _selectedCommentPosition == null ||
        _selectedCommentId == null) {
      return null;
    }

    final popupWidth = 180.0;
    double left = _selectedCommentPosition!.dx;
    double top = _selectedCommentPosition!.dy + 20;
    final imageWidth = _imageWidth.w;

    if (left + popupWidth > imageWidth) {
      left = imageWidth - popupWidth - 8;
    }

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 173.w,
          height: 45.h,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _deleteSelectedComment,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(width: 14.w),
                Padding(
                  padding: EdgeInsets.only(bottom: 1.h),
                  child: Image.asset(
                    'assets/trash_red.png',
                    width: (12.2).w,
                    height: (13.6).w,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'comments.delete',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFF0000),
                    fontFamily: 'Pretendard',
                  ),
                ).tr(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 프로필 + 캡션을 띄우는 오버레이를 빌드하는 위젯 메서드 입니다.
  ///
  /// Parameters:
  ///   - [isCaption]: 캡션 모드 여부
  ///
  /// Returns:
  ///   - [Widget]: 프로필 + 캡션 오버레이 위젯
  Widget _buildCaptionOverlay(bool isCaption) {
    final captionStyle = TextStyle(
      color: Colors.white,
      fontSize: 14.sp,
      fontFamily: 'Pretendard',
      fontWeight: FontWeight.w400,
    );

    final avatarSize = 27.0; // 프로필 이미지 크기 설정

    return GestureDetector(
      onTap: () {
        setState(() => _isCaptionExpanded = !_isCaptionExpanded);
      },
      // 프로필 + 캡션을 띄우틑 컨테이너 위젯
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(13.6),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
        child: Row(
          crossAxisAlignment: _isCaptionExpanded
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            // 프로필 아바타
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: _isProfileLoading
                  ? Shimmer.fromColors(
                      baseColor: Colors.grey[800]!,
                      highlightColor: Colors.grey[600]!,
                      child: Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF2A2A2A),
                        ),
                      ),
                    )
                  : _buildCircleAvatar(
                      imageUrl: _uploaderProfileImageUrl,
                      size: avatarSize,
                      isCaption: isCaption,
                    ),
            ),
            SizedBox(width: 12.w),

            // 캡션 텍스트
            Expanded(
              child: _isCaptionExpanded
                  ? ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.05, 0.95, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6.h),
                          child: Text(
                            widget.post.content!,
                            style: captionStyle,
                          ),
                        ),
                      ),
                    )
                  : FirstLineEllipsisText(
                      // 첫 줄만 표시하는 커스텀 텍스트 위젯
                      text: widget.post.content!,
                      style: captionStyle,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 원형 아바타 위젯 빌드
  /// 프로필 이미지 URL을 사용하여 원형 아바타를 생성합니다.
  ///
  /// Parameters:
  ///   - [imageUrl]: 아바타 이미지 URL
  ///   - [size]: 아바타 크기 (기본값: 27.0)
  ///   - [showBorder]: 테두리 표시 여부 (기본값: false)
  ///   - [borderColor]: 테두리 색상 (기본값: null)
  ///   - [borderWidth]: 테두리 두께 (기본값: 1.5)
  ///   - [opacity]: 아바타 투명도 (기본값: 1.0)
  ///   - [isCaption]: 캡션 모드 여부 (기본값: null)
  Widget _buildCircleAvatar({
    required String? imageUrl,
    double size = 32.0,
    bool showBorder = false,
    Color? borderColor,
    double borderWidth = 1.5,
    double opacity = 1.0,
    bool? isCaption,
  }) {
    Widget avatarContent;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      avatarContent = ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // 아바타는 실제 표시 크기만큼만 디코딩하면 충분합니다.
          memCacheWidth: (size * dpr).round(),
          memCacheHeight: (size * dpr).round(),
          maxWidthDiskCache: (size * 4).round(),
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: const Color(0xFF2A2A2A),
            highlightColor: const Color(0xFF3A3A3A),
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF2A2A2A),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: Color(0xffd9d9d9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white),
          ),
        ),
      );
    } else {
      avatarContent = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xffd9d9d9),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, color: Colors.white),
      );
    }

    if (showBorder) {
      avatarContent = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? Colors.white,
            width: borderWidth,
          ),
        ),
        child: avatarContent,
      );
    }

    // 3D: 댓글에 태그되는 프로필이 사진 위에서 떠 보이도록(원형 그림자 + 하이라이트)
    final avatar3d = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          if (isCaption != true)
            BoxShadow(
              color: Colors.white.withValues(alpha: 1.0),
              blurRadius: 2,
              spreadRadius: -2,
            ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.10),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: avatarContent,
    );

    return opacity < 1.0
        ? Opacity(opacity: opacity, child: avatar3d)
        : avatar3d;
  }

  /// 기본 영역 탭 처리
  void _handleBaseTap() {
    if (_showActionOverlay) {
      _dismissOverlay();
      return;
    }
    if (_hasComments || _hasPendingMarker) {
      setState(() {
        _isShowingComments = !_isShowingComments;
      });
    }
  }

  /// 액션 오버레이 닫기
  /// 액션 오버레이란, 댓글 삭제 팝업 등을 의미합니다.
  void _dismissOverlay() {
    setState(() {
      _showActionOverlay = false; // 액션 오버레이 숨기기
      _selectedCommentKey = null; // 선택된 댓글 키 초기화
      _selectedCommentId = null; // 선택된 댓글 ID 초기화
      _selectedCommentPosition = null; // 선택된 댓글 위치 초기화
    });
  }

  /// 댓글 시트 열기
  ///
  /// Parameters:
  ///  - [selectedKey]: 선택된 댓글의 고유 키
  void _openCommentSheet(String selectedKey) {
    final comments = _postComments;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ChangeNotifierProvider(
          create: (_) => AudioController(),
          child: SizedBox(
            height: 480.h,
            child: ApiVoiceCommentListSheet(
              postId: widget.post.id,
              comments: comments,
              selectedCommentId: selectedKey,
            ),
          ),
        );
      },
    );
  }

  /// 댓글 길게 눌렀을 때, 삭제 액션 오버레이 표시
  ///
  /// Parameters:
  ///   - [key]: 선택된 댓글의 고유 키
  ///   - [commentId]: 선택된 댓글의 ID
  ///   - [position]: 댓글 아바타의 절대 위치
  void _handleCommentLongPress({
    required String key,
    required int? commentId,
    required Offset position,
  }) {
    if (commentId == null) {
      _showSnackBar(tr('comments.delete_unavailable', context: context));
      return;
    }
    setState(() {
      // 선택된 댓글 정보 저장
      _selectedCommentKey = key;

      // 댓글 ID와 위치 저장
      _selectedCommentId = commentId;

      // 댓글 아바타의 위치 저장
      _selectedCommentPosition = position;

      // 액션 오버레이 표시
      _showActionOverlay = true;
    });
  }

  /// 댓글 삭제 처리
  Future<void> _deleteSelectedComment() async {
    final targetId = _selectedCommentId;
    if (targetId == null) return;
    try {
      final commentController = Provider.of<CommentController>(
        context,
        listen: false,
      );
      final success = await commentController.deleteComment(targetId);
      if (!mounted) return;
      if (success) {
        _removeCommentFromCache(targetId);
        await widget.onCommentsReloadRequested?.call(widget.post.id);
        _showSnackBar(tr('comments.delete_success', context: context));
        _dismissOverlay();
      } else {
        _showSnackBar(tr('comments.delete_failed', context: context));
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(tr('comments.delete_error', context: context));
    }
  }

  /// 댓글 캐시에서 제거
  /// 댓글 삭제 후 UI 즉시 반영을 위해 사용
  ///
  /// Parameters:
  ///   - [commentId]: 삭제할 댓글의 ID
  void _removeCommentFromCache(int commentId) {
    final updated = List<Comment>.from(
      widget.postComments[widget.post.id] ?? const <Comment>[],
    )..removeWhere((comment) => comment.id == commentId);
    widget.postComments[widget.post.id] = updated;
    setState(() {});
  }

  /// 카테고리 화면으로 네비게이트
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

  /// 스낵바 표시
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryTrimmed = widget.categoryName.trim();
    final isEnglishCategory =
        categoryTrimmed.isNotEmpty &&
        RegExp(r'^[A-Za-z\s]+$').hasMatch(categoryTrimmed);
    final waveformData = _parseWaveformData(widget.post.waveformData);
    final pendingMarker = _buildPendingMarker();
    final deletePopup = _showActionOverlay ? _buildDeleteActionPopup() : null;

    return Center(
      child: SizedBox(
        width: _imageWidth.w,
        height: _imageHeight.h,
        child: Builder(
          builder: (builderContext) {
            return DragTarget<String>(
              onWillAcceptWithDetails: (details) => details.data.isNotEmpty,
              onAcceptWithDetails: (details) {
                final renderBox =
                    builderContext.findRenderObject() as RenderBox?;
                if (renderBox == null) return;
                final localPosition = renderBox.globalToLocal(details.offset);
                final adjusted = Offset(
                  localPosition.dx + 32,
                  localPosition.dy + 32,
                );
                widget.onProfileImageDragged(widget.post.id, adjusted);
              },
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  onTap: _handleBaseTap,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _buildMediaContent(),
                      ),

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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Pretendard',
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
                      /* if (_hasComments)
                        Positioned(
                          bottom: 18.h,
                          right: 18.w,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isShowingComments = !_isShowingComments;
                              });
                            },
                            child: Image.asset(
                              "assets/comment_profile_icon.png",
                              width: 25,
                              height: 25,
                            ),
                          ),
                        ),*/
                      if (_hasCaption && !widget.post.hasAudio)
                        Positioned(
                          left: 16.w,
                          right: 16.w,
                          bottom: 18.h,
                          child: _buildCaptionOverlay(true),
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
