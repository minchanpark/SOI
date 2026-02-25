// ignore_for_file: invalid_use_of_protected_member

part of '../api_photo_display_widget.dart';

/// 댓글 액션 관련 확장 메서드
/// 댓글 삭제, 댓글 시트 열기, 액션 오버레이 표시 등을 담당합니다.
/// 댓글 태그 관련 메서드는 [api_photo_display_widget_comment_tags.dart]에 있습니다.
extension _ApiPhotoDisplayWidgetCommentActionsExtension
    on _ApiPhotoDisplayWidgetState {
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
    final imageWidth = _imageSize.width;

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
                      cacheKey: widget.post.userProfileImageKey,
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
    Key? key, // 위젯 키
    required String? imageUrl,
    double size = 32.0,
    bool showBorder = false,
    Color? borderColor,
    double borderWidth = 1.5,
    double opacity = 1.0,
    bool? isCaption,
    String? cacheKey,
  }) {
    Widget avatarContent;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      avatarContent = ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          cacheKey: cacheKey,
          useOldImageOnUrlChange: cacheKey != null,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          width: size,
          height: size,
          fit: BoxFit.cover,

          // 아바타는 실제 표시 크기만큼만 디코딩하면 충분합니다.
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

    final resolved = opacity < 1.0
        ? Opacity(opacity: opacity, child: avatarContent)
        : avatarContent;
    if (key == null) {
      return resolved;
    }
    return KeyedSubtree(key: key, child: resolved);
  }

  /// 기본 영역 탭 처리
  void _handleBaseTap() {
    if (_showActionOverlay) {
      _dismissOverlay();
      return;
    }
    if (_expandedMediaTagKey != null) {
      _collapseExpandedMediaTag();
      return;
    }
    if (_hasComments || _hasPendingMarker) {
      setState(() {
        _isShowingComments = !_isShowingComments;
        if (!_isShowingComments) {
          _expandedMediaTagKey = null; // 댓글 숨길 때 미디어 태그 확장 해제
        }
      });
      if (!_isShowingComments) {
        _clearExpandedMediaOverlay();
      }
    }
  }

  /// 액션 오버레이 닫기
  /// 액션 오버레이란, 댓글 삭제 팝업 등을 의미합니다.
  void _dismissOverlay() {
    setState(() {
      _showActionOverlay = false; // 액션 오버레이 숨기기
      _selectedCommentKey = null; // 선택된 댓글 키 초기화
      _expandedMediaTagKey = null; // 확장 미디어 태그 초기화
      _selectedCommentId = null; // 선택된 댓글 ID 초기화
      _selectedCommentPosition = null; // 선택된 댓글 위치 초기화
    });
    _clearExpandedMediaOverlay();
  }

  /// 댓글 시트 열기
  ///
  /// Parameters:
  ///  - [selectedKey]: 선택된 댓글의 고유 키
  void _openCommentSheet(String selectedKey) {
    final comments = _postComments;
    if (_expandedMediaTagKey != null) {
      setState(() {
        _expandedMediaTagKey = null; // 댓글 시트 열 때 미디어 태그 확장 해제
      });
      _clearExpandedMediaOverlay();
    }
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
      _expandedMediaTagKey = null;

      // 댓글 ID와 위치 저장
      _selectedCommentId = commentId;

      // 댓글 아바타의 위치 저장
      _selectedCommentPosition = position;

      // 액션 오버레이 표시
      _showActionOverlay = true;
    });
    _clearExpandedMediaOverlay();
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
        if (!mounted) return;
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
}
