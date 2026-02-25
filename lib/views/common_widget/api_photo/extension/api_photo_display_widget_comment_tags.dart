// ignore_for_file: invalid_use_of_protected_member

part of '../api_photo_display_widget.dart';

/// 댓글 태그 관련 확장 메서드
/// 댓글 위치에 맞게 아바타 태그를 배치하고,
/// 댓글이 미디어(사진) 타입인 경우 확장된 미디어 오버레이를 표시하는 기능을 담당합니다.
///
/// 댓글 액션(삭제, 시트 열기 등)은 [api_photo_display_widget_comment_actions.dart]에서 처리합니다.
extension _ApiPhotoDisplayWidgetCommentTagsExtension
    on _ApiPhotoDisplayWidgetState {
  Offset _clampTagAnchor(
    Offset anchor,
    Size containerSize,
    double contentSize,
  ) {
    final diameter = TagBubble.diameterForContent(contentSize: contentSize);
    final tipOffset = TagBubble.pointerTipOffset(contentSize: contentSize);
    final minX = diameter / 2;
    final maxX = containerSize.width - diameter / 2;
    final minY = tipOffset.dy;
    final maxY = containerSize.height;

    return Offset(anchor.dx.clamp(minX, maxX), anchor.dy.clamp(minY, maxY));
  }

  /// 태그의 포인터 끝점(anchor) 좌표를 원(circle) 중심 좌표로 변환
  /// 확장/축소 시 같은 중심점을 유지하기 위한 계산입니다.
  Offset _tagCircleCenterFromTipAnchor(Offset tipAnchor, double contentSize) {
    final tipOffset = TagBubble.pointerTipOffset(contentSize: contentSize);
    final diameter = TagBubble.diameterForContent(contentSize: contentSize);
    final left = tipAnchor.dx - tipOffset.dx;
    final top = tipAnchor.dy - tipOffset.dy;
    return Offset(left + (diameter / 2), top + (diameter / 2));
  }

  /// 태그 포인터 끝점(anchor) 좌표로부터 TagBubble 좌상단 좌표를 계산합니다.
  Offset _tagTopLeftFromTipAnchor(Offset tipAnchor, double contentSize) {
    final tipOffset = TagBubble.pointerTipOffset(contentSize: contentSize);
    return Offset(tipAnchor.dx - tipOffset.dx, tipAnchor.dy - tipOffset.dy);
  }

  void _notifyExpandedMediaOverlay(ExpandedMediaTagOverlayData? data) {
    widget.onExpandedMediaOverlayChanged?.call(data);
  }

  void _clearExpandedMediaOverlay() {
    _notifyExpandedMediaOverlay(null);
  }

  void _emitExpandedMediaOverlay({
    required String tagKey,
    required Comment comment,
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

  void _showExpandedMediaOverlay({
    required String tagKey,
    required Comment comment,
    required Offset tipAnchor,
    VoidCallback? onLongPress,
  }) {
    final localCircleCenter = _tagCircleCenterFromTipAnchor(
      tipAnchor,
      _ApiPhotoDisplayWidgetState._avatarSize,
    );
    _emitExpandedMediaOverlay(
      tagKey: tagKey,
      comment: comment,
      localCircleCenter: localCircleCenter,
      collapsedContentSize: _ApiPhotoDisplayWidgetState._avatarSize,
      expandedContentSize: _ApiPhotoDisplayWidgetState._expandedAvatarSize,
      onLongPress: onLongPress,
    );
  }

  /// 댓글의 프로필 이미지를 위치에 맞게 배치
  /// 댓글이 위치 정보를 가지고 있고, 댓글 표시가 활성화된 경우에만 아바타를 표시합니다.
  List<Widget> _buildCommentAvatars() {
    if (!_isShowingComments) return const [];

    final filteredComments = _postComments
        .where((c) => c.type != CommentType.emoji && c.hasLocation)
        .toList();

    final actualSize = _imageSize;

    return List<Widget>.generate(filteredComments.length, (index) {
      final comment = filteredComments[index];
      final key = '${index}_${comment.hashCode}';
      final canExpandMedia = _canExpandMediaComment(comment);
      final relative = Offset(
        comment.locationX ?? 0.5,
        comment.locationY ?? 0.5,
      );
      final absolute = PositionConverter.toAbsolutePosition(
        relative,
        actualSize,
      );
      final clampedSmallTip = _clampTagAnchor(
        absolute,
        actualSize,
        _ApiPhotoDisplayWidgetState._avatarSize,
      );
      final topLeft = _tagTopLeftFromTipAnchor(
        clampedSmallTip,
        _ApiPhotoDisplayWidgetState._avatarSize,
      );
      final hideOther =
          _showActionOverlay &&
          _selectedCommentKey != null &&
          key != _selectedCommentKey;
      final hideExpandedTag = _expandedMediaTagKey == key && canExpandMedia;
      if (hideOther || hideExpandedTag) {
        return const SizedBox.shrink();
      }

      final isSelected = _selectedCommentKey == key;
      final tagBody = _buildCircleAvatar(
        key: ValueKey('avatar_$key'),
        imageUrl: comment.userProfileUrl,
        size: _ApiPhotoDisplayWidgetState._avatarSize,
        showBorder: isSelected,
        borderColor: Colors.white,
      );

      return Positioned(
        left: topLeft.dx,
        top: topLeft.dy,
        child: GestureDetector(
          onTap: () => _handleCommentTap(
            comment: comment,
            key: key,
            tipAnchor: clampedSmallTip,
          ),
          onLongPress: () => _handleCommentLongPress(
            key: key,
            commentId: comment.id,
            position: clampedSmallTip,
          ),
          child: TagBubble(
            contentSize: _ApiPhotoDisplayWidgetState._avatarSize,
            child: tagBody,
          ),
        ),
      );
    });
  }

  /// 댓글이 미디어(사진) 타입이고, 미디어 프리뷰가 가능한지 여부를 판단하는 메서드
  bool _canExpandMediaComment(Comment comment) {
    if (comment.type != CommentType.photo) {
      // 사진 타입이 아닌 경우 미디어 프리뷰 불가능
      return false;
    }

    final fileUrl = (comment.fileUrl ?? '').trim();
    if (fileUrl.isNotEmpty) {
      return true;
    }

    final fileKey = (comment.fileKey ?? '').trim();
    return fileKey.isNotEmpty;
  }

  /// 댓글을 탭했을 때의 처리 메서드
  void _handleCommentTap({
    required Comment comment,
    required String key,
    required Offset tipAnchor,
  }) {
    if (comment.type == CommentType.photo) {
      if (!_canExpandMediaComment(comment)) {
        _openCommentSheet(key); // 미디어 프리뷰가 불가능한 경우, 바로 댓글 시트 오픈
        return;
      }
      if (widget.onExpandedMediaOverlayChanged == null) {
        _openCommentSheet(key);
        return;
      }

      if (_expandedMediaTagKey == key) {
        _collapseExpandedMediaTag();
        return;
      }

      setState(() {
        _expandedMediaTagKey = key;
      });
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
      _collapseExpandedMediaTag();
    }
    _openCommentSheet(key);
  }

  /// 업로드 중인 음성 댓글 마커 빌드
  /// 대기 중인 음성 댓글이 있으면 해당 위치에 마커를 표시합니다.
  /// 업로드 되기 전에, 댓글이 UI에 미리 보이도록 합니다.
  Widget? _buildPendingMarker() {
    final pending = widget.pendingVoiceComments[widget.post.id];
    if (pending == null) {
      return null;
    }

    final actualSize = _imageSize;
    final absolute = PositionConverter.toAbsolutePosition(
      pending.relativePosition,
      actualSize,
    );
    final clamped = _clampTagAnchor(
      absolute,
      actualSize,
      _ApiPhotoDisplayWidgetState._avatarSize,
    );
    final tagTipOffset = TagBubble.pointerTipOffset(
      contentSize: _ApiPhotoDisplayWidgetState._avatarSize,
    );

    return Positioned(
      left: clamped.dx - tagTipOffset.dx,
      top: clamped.dy - tagTipOffset.dy,
      child: IgnorePointer(
        child: _buildPendingProgressAvatar(
          imageUrl: pending.profileImageUrlKey,
          size: _ApiPhotoDisplayWidgetState._avatarSize,
          progress: pending.progress,
          opacity: 0.85,
        ),
      ),
    );
  }

  /// 원형 아바타 위젯 빌드
  /// : 프로필 이미지를 원형 아바타로 표시하는 위젯을 빌드합니다.
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
    return TagBubble(
      contentSize: size,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress?.clamp(0.0, 2.0),
                strokeWidth: 2.0,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
                backgroundColor: Colors.transparent,
              ),
            ),
            _buildCircleAvatar(
              imageUrl: imageUrl,
              size: size,
              opacity: opacity,
            ),
          ],
        ),
      ),
    );
  }
}
