import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/api_firebase/controllers/comment_record_controller.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../../api_firebase/controllers/auth_controller.dart';
import '../../../api_firebase/controllers/comment_audio_controller.dart';
import '../../../api_firebase/controllers/category_controller.dart';
import '../../../api_firebase/models/photo_data_model.dart';
import '../../../api_firebase/models/comment_record_model.dart';
import '../../../utils/position_converter.dart';
import '../../../utils/app_route_observer.dart';
import '../../about_feed/manager/voice_comment_state_manager.dart';
import '../../about_archiving/screens/archive_detail/category_photos_screen.dart';
import '../about_voice_comment/voice_comment_list_sheet.dart';
import 'first_line_ellipsis_text.dart';
import 'category_label_widget.dart';
import 'audio_control_widget.dart';

/// 사진 표시 위젯
class PhotoDisplayWidget extends StatefulWidget {
  final MediaDataModel photo;
  final String categoryName;
  // Archive 여부에 따라 카테고리 라벨 숨김
  final bool isArchive;
  final Map<String, List<CommentRecordModel>> photoComments;
  final Map<String, String> userProfileImages;
  final Map<String, bool> profileLoadingStates;
  final Function(String, Offset) onProfileImageDragged;
  final Function(MediaDataModel) onToggleAudio;
  final Map<String, PendingVoiceComment> pendingVoiceComments;

  const PhotoDisplayWidget({
    super.key,
    required this.photo,
    required this.categoryName,
    this.isArchive = false,
    required this.photoComments,
    required this.userProfileImages,
    required this.profileLoadingStates,
    required this.onProfileImageDragged,
    required this.onToggleAudio,
    this.pendingVoiceComments = const {},
  });

  @override
  State<PhotoDisplayWidget> createState() => _PhotoDisplayWidgetState();
}

class _PhotoDisplayWidgetState extends State<PhotoDisplayWidget>
    with RouteAware {
  // 상수
  static const double _avatarSize = 27.0;
  static const double _avatarRadius = 13.5;
  static const double _imageWidth = 354.0;
  static const double _imageHeight = 500.0;

  // 선택된(롱프레스) 음성 댓글 ID 및 위치
  String? _selectedCommentId;
  Offset? _selectedCommentPosition;
  bool _showActionOverlay = false;
  bool _isShowingComments = false;
  bool _autoOpenedOnce = false;
  bool _isCaptionExpanded = false;

  final CommentRecordController _commentRecordController =
      CommentRecordController();

  // 비디오 플레이어 관련
  VideoPlayerController? _videoController;

  // 비디오 초기화되었는 지를 체크하는 변수
  bool _isVideoInitialized = false;

  // 비디오 음소거 상태를 체크하는 변수
  bool _isMuted = false;

  // 비디오 fit 모드 - 초기 모드는 contain
  BoxFit _videoFit = BoxFit.contain;

  // 현재 Route 저장용
  ModalRoute<dynamic>? _route;

  // 비디오가 실제로 보이는지 체크하는 변수
  // 이 변수는 TickerMode 상태와 실제 위젯의 가시성을 분리하여 관리합니다.
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    // 카메라 촬영 영상은 기본값을 BoxFit.fill로 설정
    if (widget.photo.isFromCamera) {
      _videoFit = BoxFit.fill;
    }
    _initializeVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      if (_route != route) {
        if (_route != null) {
          appRouteObserver.unsubscribe(this);
        }
        _route = route;
        appRouteObserver.subscribe(this, route);
      }
    }

    // 비디오인 경우: 초기화 완료 후에만 visibility 업데이트 -> 비디오 초기화가 된 경우에만 가시성을 업데이트해서
    //             컨텐츠가 표시되도록 한다.
    if (widget.photo.isVideo) {
      if (_isVideoInitialized) {
        _updateVisibility(TickerMode.of(context));
      }
    }
    // 비디오가 아닌 경우: 즉시 visibility 업데이트 -> 즉시 가시성을 업데이트해서 바로 컨텐츠가 표시되도록 한다.
    else {
      _updateVisibility(TickerMode.of(context));
    }
  }

  @override
  void dispose() {
    if (_route != null) {
      // Route 구독 해제
      appRouteObserver.unsubscribe(this);
    }
    // 비디오 컨트롤러 해제 -> 메모리 누수 방지
    _videoController?.dispose();
    super.dispose();
  }

  /// 비디오 초기화
  Future<void> _initializeVideo() async {
    if (widget.photo.isVideo &&
        widget.photo.videoUrl != null &&
        widget.photo.videoUrl!.isNotEmpty) {
      try {
        // 비디오 컨트롤러를 생성한다.
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.photo.videoUrl!),
        );

        // 비디오 컨트롤러를 초기화하여서 사용 대기
        await _videoController!.initialize();

        // 반복 재생 설정
        await _videoController!.setLooping(true);
        if (mounted) {
          setState(() {
            // 비디오가 초기화 되었다는 것을 표시하기 위해서 true로 설정
            _isVideoInitialized = true;
          });
          // TickerMode 상태에 따라 재생 여부 결정
          _updateVisibility(TickerMode.of(context));
        }
      } catch (e) {
        debugPrint('비디오 초기화 실패: $e');
      }
    }
  }

  /// 비디오 음소거 토글
  void _toggleVideoMute() {
    if (_videoController == null || !_isVideoInitialized) return;

    setState(() {
      _isMuted = !_isMuted;
      _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  /// 비디오 fit 모드 토글 (contain → cover → fill → contain)
  void _toggleVideoFit() {
    setState(() {
      if (_videoFit == BoxFit.contain) {
        _videoFit = BoxFit.fill;
      } else if (_videoFit == BoxFit.fill) {
        _videoFit = BoxFit.contain;
      } else {
        _videoFit = BoxFit.contain;
      }
    });
  }

  void _updateVisibility(bool isVisible) {
    if (_isVisible == isVisible) return;
    _isVisible = isVisible;
    if (_isVisible) {
      _resumeVideoPlayback();
    } else {
      _pauseVideoPlayback();
    }
  }

  // 비디오 일시정지
  void _pauseVideoPlayback() {
    if (_videoController != null &&
        _isVideoInitialized &&
        _videoController!.value.isPlaying) {
      _videoController!.pause();
      _videoController!.seekTo(Duration.zero);
    }
  }

  // 비디오 재생 재개
  void _resumeVideoPlayback() {
    if (_videoController != null &&
        _isVideoInitialized &&
        !_videoController!.value.isPlaying) {
      _videoController!.play();
    }
  }

  @override
  void didPushNext() {
    _pauseVideoPlayback();
    super.didPushNext();
  }

  @override
  void didPopNext() {
    // 현재 페이지가 실제로 보이는지 체크 후 재생
    // PageView에서 보이지 않는 페이지는 재생하지 않음
    _updateVisibility(TickerMode.of(context));
    super.didPopNext();
  }

  /// 공통 Circle Avatar 빌더
  Widget _buildCircleAvatar({
    required String? imageUrl,
    double size = 27.0,
    bool showBorder = false,
    Color? borderColor,
    double borderWidth = 1.5,
    double opacity = 1.0,
  }) {
    Widget avatarContent;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      avatarContent = ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: (size * 4).round(),
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
            color: borderColor ?? Colors.white.withValues(alpha: 0.7),
            width: borderWidth,
          ),
        ),
        child: avatarContent,
      );
    }

    return opacity < 1.0
        ? Opacity(opacity: opacity, child: avatarContent)
        : avatarContent;
  }

  /// 댓글 아바타 리스트 빌드
  List<Widget> _buildCommentAvatars() {
    if (!_isShowingComments) return [];

    final comments = widget.photoComments[widget.photo.id] ?? [];
    final commentsWithPosition = comments
        .where((comment) => comment.relativePosition != null)
        .toList();

    final actualImageSize = Size(_imageWidth.w, _imageHeight.h);

    return commentsWithPosition.map((comment) {
      // 오버레이 중이면 선택된 댓글 외에는 숨김
      if (_showActionOverlay &&
          _selectedCommentId != null &&
          comment.id != _selectedCommentId) {
        return const SizedBox.shrink();
      }

      final absolutePosition = PositionConverter.toAbsolutePosition(
        comment.relativePosition!,
        actualImageSize,
      );
      final clampedPosition = PositionConverter.clampPosition(
        absolutePosition,
        actualImageSize,
      );

      return Positioned(
        left: clampedPosition.dx - _avatarRadius,
        top: clampedPosition.dy - _avatarRadius,
        child: GestureDetector(
          onLongPress: () {
            setState(() {
              _selectedCommentId = comment.id;
              _selectedCommentPosition = clampedPosition;
              _showActionOverlay = true;
            });
          },
          child: Consumer2<AuthController, CommentAudioController>(
            builder: (context, authController, commentAudioController, child) {
              final isCurrentCommentPlaying = commentAudioController
                  .isCommentPlaying(comment.id);
              final isSelected =
                  _showActionOverlay && _selectedCommentId == comment.id;

              return InkWell(
                onTap: () async {
                  if (!mounted) return;
                  try {
                    final recordController = context
                        .read<CommentRecordController>();
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (sheetContext) => ChangeNotifierProvider.value(
                        value: recordController,
                        child: SizedBox(
                          height: 480.h,
                          child: VoiceCommentListSheet(
                            photoId: widget.photo.id,
                            categoryId: widget.photo.categoryId,
                            selectedCommentId: comment.id,
                          ),
                        ),
                      ),
                    );
                  } catch (e) {
                    debugPrint('Feed - 댓글 팝업 표시 실패: $e');
                  }
                },
                child: Container(
                  width: _avatarSize,
                  height: _avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                    border: Border.all(
                      color: isSelected || isCurrentCommentPlaying
                          ? Colors.white
                          : Colors.transparent,
                      width: isSelected ? 2.2 : 1,
                    ),
                  ),
                  child: _buildCircleAvatar(
                    imageUrl: comment.profileImageUrl,
                    size: _avatarSize,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }).toList();
  }

  /// 삭제 액션 팝업 빌드
  Widget? _buildDeleteActionPopup() {
    if (!_showActionOverlay ||
        _selectedCommentId == null ||
        _selectedCommentPosition == null) {
      return null;
    }

    final imageWidth = _imageWidth.w;
    final popupWidth = 180.0;

    double left = _selectedCommentPosition!.dx;
    double top = _selectedCommentPosition!.dy + 20;
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
            onTap: () async {
              if (_selectedCommentId == null) return;
              final targetId = _selectedCommentId!;
              try {
                await _commentRecordController.hardDeleteCommentRecord(
                  targetId,
                  widget.photo.id,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('댓글 삭제 실패: $e'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _showActionOverlay = false;
                    _selectedCommentId = null;
                    _selectedCommentPosition = null;
                    _isShowingComments = false;
                  });
                }
              }
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(width: 13.96.w),
                Image.asset(
                  "assets/trash_red.png",
                  width: 11.2.w,
                  height: 12.6.h,
                ),
                SizedBox(width: 12.59.w),
                Text(
                  '댓글 삭제',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xffff0000),
                    fontFamily: 'Pretendard',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildPendingMarker() {
    final pending = widget.pendingVoiceComments[widget.photo.id];
    if (pending == null || pending.relativePosition == null) return null;

    final actualImageSize = Size(_imageWidth.w, _imageHeight.h);
    final absolutePosition = PositionConverter.toAbsolutePosition(
      pending.relativePosition!,
      actualImageSize,
    );
    final clampedPosition = PositionConverter.clampPosition(
      absolutePosition,
      actualImageSize,
    );

    final profileImageUrl =
        pending.profileImageUrl ??
        ((pending.recorderUserId != null && pending.recorderUserId!.isNotEmpty)
            ? widget.userProfileImages[pending.recorderUserId!]
            : null);

    return Positioned(
      left: clampedPosition.dx - _avatarRadius,
      top: clampedPosition.dy - _avatarRadius,
      child: IgnorePointer(
        child: _buildCircleAvatar(
          imageUrl: profileImageUrl,
          size: _avatarSize,
          showBorder: true,

          // 사용자에게 보이지 않게 (위치 데이터만 유지)
          opacity: 0.0,
        ),
      ),
    );
  }

  /// 카테고리 화면으로 이동
  void _navigateToCategory() async {
    final categoryId = widget.photo.categoryId;
    if (categoryId.isEmpty) {
      debugPrint('카테고리 ID가 없습니다');
      return;
    }

    try {
      final categoryController = context.read<CategoryController>();
      final category = await categoryController.getCategory(categoryId);
      if (category == null) {
        debugPrint('카테고리를 찾을 수 없습니다: $categoryId');
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) {
              return CategoryPhotosScreen(category: category);
            },
          ),
        );
        debugPrint('카테고리로 이동: $categoryId');
      }
    } catch (e) {
      debugPrint('카테고리 로드 실패: $e');
    }
  }

  /// 사용자 프로필 이미지 위젯 빌드 (Caption에서만 사용)
  Widget _buildUserProfileWidget(BuildContext context) {
    final userId = widget.photo.userID;
    final screenWidth = MediaQuery.of(context).size.width;
    final profileSize = screenWidth * 0.085;

    return Consumer<AuthController>(
      builder: (context, authController, child) {
        final isLoading = widget.profileLoadingStates[userId] ?? false;

        if (isLoading) {
          return const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          );
        }

        return StreamBuilder<String>(
          stream: authController.getUserProfileImageUrlStream(userId),
          builder: (context, snapshot) {
            return _buildCircleAvatar(
              imageUrl: snapshot.data,
              size: profileSize,
            );
          },
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant PhotoDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 최초로 현재 사용자 댓글이 생긴 시점에 한 번만 자동 표시
    if (!_autoOpenedOnce) {
      try {
        final authController = context.read<AuthController?>();
        final uid = authController?.currentUser?.uid;
        if (uid != null) {
          final comments =
              widget.photoComments[widget.photo.id] ??
              const <CommentRecordModel>[];
          final hasUserComment = comments.any((c) => c.recorderUser == uid);
          if (hasUserComment) {
            setState(() {
              _isShowingComments = true; // 한번 자동으로 켜기
              _autoOpenedOnce = true; // 재자동 방지
            });
          }
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 이미지 영역에만 DragTarget 적용 - Builder Pattern 사용
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Builder(
            builder: (builderContext) {
              return DragTarget<String>(
                onWillAcceptWithDetails: (details) {
                  return (details.data).isNotEmpty;
                },
                onAcceptWithDetails: (details) {
                  // 드롭된 좌표를 사진 내 상대 좌표로 변환
                  final RenderBox renderBox =
                      builderContext.findRenderObject() as RenderBox;
                  final localPosition = renderBox.globalToLocal(details.offset);

                  // 프로필 크기(64)의 반지름만큼 보정하여 중심점으로 조정
                  final adjustedPosition = Offset(
                    localPosition.dx + 32,
                    localPosition.dy + 32,
                  );

                  widget.onProfileImageDragged(
                    widget.photo.id,
                    adjustedPosition,
                  );
                },
                builder: (context, candidateData, rejectedData) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      // 메모리 최적화: 배경 이미지 크기 제한
                      GestureDetector(
                        onTap: () {
                          final hasComments =
                              (widget.photoComments[widget.photo.id] ?? [])
                                  .isNotEmpty;
                          if (hasComments) {
                            setState(() {
                              _isShowingComments = !_isShowingComments;
                            });
                          }
                        },
                        onDoubleTap: () {
                          // 비디오인 경우 더블탭으로 fit 모드 전환
                          if (widget.photo.isVideo) {
                            _toggleVideoFit();
                          }
                        },
                        child: widget.photo.isVideo
                            ? (_isVideoInitialized && _videoController != null
                                  ? SizedBox(
                                      width: 354.w,
                                      height: 500.h,
                                      child: FittedBox(
                                        // 카메라 촬영: 기본값 BoxFit.fill, 토글로 변경 가능
                                        // 갤러리: 기본값 BoxFit.contain, 토글로 변경 가능
                                        fit: _videoFit,
                                        child: SizedBox(
                                          width: _videoController!
                                              .value
                                              .size
                                              .width,
                                          height: _videoController!
                                              .value
                                              .size
                                              .height,
                                          child: VideoPlayer(_videoController!),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 354.w,
                                      height: 500.h,
                                      color: Colors.grey[900],
                                      child:
                                          widget.photo.thumbnailUrl != null &&
                                              widget
                                                  .photo
                                                  .thumbnailUrl!
                                                  .isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl:
                                                  widget.photo.thumbnailUrl!,
                                              fit: BoxFit.cover,
                                              width: 354.w,
                                              height: 500.h,
                                              memCacheWidth: (354 * 2).round(),
                                              maxWidthDiskCache: (354 * 2)
                                                  .round(),
                                            )
                                          : const Center(
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                              ),
                                            ),
                                    ))
                            : CachedNetworkImage(
                                imageUrl: widget.photo.imageUrl,
                                fit: BoxFit.cover,
                                width: 354.w,
                                height: 500.h,

                                // 메모리 최적화: 디코딩 크기 제한으로 메모리 사용량 대폭 감소
                                memCacheWidth: (354 * 2).round(),
                                maxWidthDiskCache: (354 * 2).round(),

                                placeholder: (context, url) {
                                  return Container(
                                    width: 354.w,
                                    height: 500.h,
                                    color: Colors.grey[900],
                                    child: const Center(),
                                  );
                                },
                              ),
                      ),
                      // 댓글 보기 토글 시(롱프레스 액션 오버레이 아닐 때) 살짝 어둡게 마스킹하여 아바타 대비 확보
                      if (_isShowingComments && !_showActionOverlay)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      // 선택된 댓글이 있을 때 전체 마스킹 (선택된 것만 위에 남김)
                      if (_showActionOverlay)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showActionOverlay = false;
                                _selectedCommentId = null;
                                _selectedCommentPosition = null;
                              });
                            },
                            child: Container(
                              color: Color(0xffd9d9d9).withValues(alpha: 0.45),
                            ),
                          ),
                        ),

                      // 카테고리 정보
                      if (!widget.isArchive)
                        CategoryLabelWidget(
                          categoryName: widget.categoryName,
                          onTap: _navigateToCategory,
                        ),

                      // 비디오 음소거 버튼 (오른쪽 아래)
                      if (widget.photo.isVideo && _isVideoInitialized)
                        Positioned(
                          right: 20.w,
                          bottom: 20.h,
                          child: GestureDetector(
                            onTap: _toggleVideoMute,
                            child: SizedBox(
                              width: 24.sp,
                              height: 24.sp,
                              child: SvgPicture.asset(
                                _isMuted
                                    ? 'assets/sound_mute.svg'
                                    : 'assets/sound_on.svg',
                                colorFilter: ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 오디오 컨트롤 오버레이
                      if (widget.photo.audioUrl.isNotEmpty)
                        Positioned(
                          left: 20.w,
                          bottom: 7.h,
                          child: AudioControlWidget(
                            photo: widget.photo,
                            onAudioTap: () =>
                                widget.onToggleAudio(widget.photo),
                            hasComments:
                                (widget.photoComments[widget.photo.id] ?? [])
                                    .isNotEmpty,
                            onCommentIconTap: () {
                              setState(() {
                                _isShowingComments = !_isShowingComments;
                              });
                            },
                          ),
                        ),

                      // Caption 표시 (오디오가 없을 때)
                      if (widget.photo.audioUrl.isEmpty &&
                          widget.photo.caption != null &&
                          widget.photo.caption!.isNotEmpty)
                        Positioned(
                          left: 20.w,
                          bottom: 7.h,
                          child: Row(
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  // 텍스트가 오버플로우되는지 확인
                                  final captionStyle = TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w400,
                                  );
                                  final textSpan = TextSpan(
                                    text: widget.photo.caption!,
                                    style: captionStyle,
                                  );

                                  final textPainter = TextPainter(
                                    text: textSpan,
                                    maxLines: 1,
                                    textDirection: TextDirection.ltr,
                                  );

                                  textPainter.layout(
                                    maxWidth: 278.w - 10.w * 2 - 27 - 12.w,
                                  );
                                  final isOverflowing =
                                      textPainter.didExceedMaxLines ||
                                      widget.photo.caption!.contains('\n');

                                  return GestureDetector(
                                    onTap: isOverflowing
                                        ? () {
                                            setState(() {
                                              _isCaptionExpanded =
                                                  !_isCaptionExpanded;
                                            });
                                          }
                                        : null,
                                    child: Container(
                                      width: 278.w,
                                      constraints: BoxConstraints(
                                        minHeight: 40.h,
                                        maxHeight: _isCaptionExpanded
                                            ? 274.h
                                            : 40.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Color(
                                          0xff000000,
                                        ).withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                        ),
                                        child: Row(
                                          crossAxisAlignment: _isCaptionExpanded
                                              ? CrossAxisAlignment.start
                                              : CrossAxisAlignment.center,
                                          children: [
                                            // 왼쪽 프로필 이미지
                                            Container(
                                              width: 27,
                                              height: 27,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                              ),
                                              child: ClipOval(
                                                child: _buildUserProfileWidget(
                                                  context,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 12.w),

                                            // Caption 텍스트 with Scroll and Fade Effect
                                            Expanded(
                                              child: _isCaptionExpanded
                                                  ? ShaderMask(
                                                      shaderCallback:
                                                          (Rect bounds) {
                                                            return LinearGradient(
                                                              begin: Alignment
                                                                  .topCenter,
                                                              end: Alignment
                                                                  .bottomCenter,
                                                              colors: [
                                                                Colors
                                                                    .transparent,
                                                                Colors.white,
                                                                Colors.white,
                                                                Colors
                                                                    .transparent,
                                                              ],
                                                              stops: [
                                                                0.0,
                                                                0.05,
                                                                0.95,
                                                                1.0,
                                                              ],
                                                            ).createShader(
                                                              bounds,
                                                            );
                                                          },
                                                      blendMode:
                                                          BlendMode.dstIn,
                                                      child: SingleChildScrollView(
                                                        physics:
                                                            BouncingScrollPhysics(),
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                vertical: 6.h,
                                                              ),
                                                          child: Text(
                                                            widget
                                                                .photo
                                                                .caption!,
                                                            style: captionStyle
                                                                .copyWith(
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : FirstLineEllipsisText(
                                                      text:
                                                          widget.photo.caption!,
                                                      style: captionStyle
                                                          .copyWith(
                                                            color: Colors.white,
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
                              // 댓글 아이콘 영역
                              SizedBox(
                                width: 60.w,
                                child:
                                    (widget.photoComments[widget.photo.id] ??
                                            [])
                                        .isNotEmpty
                                    ? Center(
                                        child: IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _isShowingComments =
                                                  !_isShowingComments;
                                            });
                                          },
                                          icon: Image.asset(
                                            "assets/comment_profile_icon.png",
                                            width: 25.w,
                                            height: 25.h,
                                          ),
                                        ),
                                      )
                                    : Container(),
                              ),
                            ],
                          ),
                        ),

                      // 모든 댓글의 드롭된 프로필 이미지들 표시
                      ..._buildCommentAvatars(),
                      // Pending 마커 표시
                      if (_isShowingComments && _buildPendingMarker() != null)
                        _buildPendingMarker()!,
                      // 삭제 액션 팝업
                      if (_buildDeleteActionPopup() != null)
                        _buildDeleteActionPopup()!,
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
