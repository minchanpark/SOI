part of '../voice_comment_widget.dart';

/// 음성 댓글 위젯의 프로필 배치 및 저장 관련 로직
/// - recorded 상태에서 placing 상태로 전환하는 진입점
/// - 프로필 드래그 시 부모 스크롤 잠금/해제
/// - 배치 완료 시 저장 요청 및 상태 전환
extension _VoiceCommentWidgetProfileDragExtension on _VoiceCommentWidgetState {
  /// 파형 위에 드래그 가능한 프로필 이미지 오버레이
  /// recorded 상태에서 placing 상태로 전환하는 진입점
  /// 파형을 감싸서 프로필 이미지를 드래그할 수 있게 함
  Widget _buildWaveformDraggable({required Widget child}) {
    if (widget.onProfileImageDragged == null ||
        _waveformData == null ||
        _waveformData!.isEmpty) {
      return child;
    }

    final profileWidget = _buildProfileAvatar(
      size: _VoiceCommentWidgetState._placementAvatarSize,
    );
    final dragWidget = TagBubble(
      contentSize: _VoiceCommentWidgetState._placementAvatarSize,
      child: profileWidget,
    );

    return Draggable<String>(
      key: _profileDraggableKey,
      data: 'profile_image',
      dragAnchorStrategy: _tagPointerDragAnchor,
      feedback: Transform.scale(
        scale: 1.2,
        child: Opacity(opacity: 0.8, child: dragWidget),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: dragWidget),
      onDragStarted: _beginPlacementFromWaveform,
      child: child,
    );
  }

  /// 프로필 아바타를 드래그 가능한 위젯으로 생성
  /// isPlacementMode에 따라 배치 완료/취소 로직 실행
  /// placing/saved 상태에서 사용
  Widget _buildProfileDraggable({required bool isPlacementMode}) {
    final avatarSize = isPlacementMode
        ? _VoiceCommentWidgetState._placementAvatarSize
        : _VoiceCommentWidgetState._defaultAvatarSize;
    final profileWidget = _buildProfileAvatar(size: avatarSize);
    final dragWidget = isPlacementMode
        ? TagBubble(contentSize: avatarSize, child: profileWidget)
        : profileWidget;

    if (widget.onProfileImageDragged == null) {
      return dragWidget;
    }

    return Draggable<String>(
      key: isPlacementMode ? _profileDraggableKey : null,
      data: 'profile_image',
      dragAnchorStrategy: isPlacementMode
          ? _tagPointerDragAnchor
          : pointerDragAnchorStrategy,
      feedback: Transform.scale(
        scale: 1.2,
        child: Opacity(opacity: 0.8, child: dragWidget),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: dragWidget),
      onDragStarted: isPlacementMode ? _holdParentScroll : null,
      onDraggableCanceled: (velocity, offset) {
        if (!isPlacementMode) {
          return;
        }
        _cancelPlacement();
      },
      onDragEnd: (details) {
        if (!isPlacementMode) {
          return;
        }

        if (details.wasAccepted) {
          _finalizePlacement();
        }
      },
      child: dragWidget,
    );
  }

  Offset _tagPointerDragAnchor(
    Draggable<Object> draggable,
    BuildContext context,
    Offset position,
  ) {
    return TagBubble.pointerTipOffset(
      contentSize: _VoiceCommentWidgetState._placementAvatarSize,
    );
  }

  /// 프로필 아바타 위젯 생성
  /// profileImageUrl이 있으면 CachedNetworkImage 사용, 없으면 기본 아이콘 표시
  Widget _buildProfileAvatar({required double size}) {
    return Consumer2<UserController, MediaController>(
      builder: (context, userController, mediaController, _) {
        final profileSource =
            userController.currentUser?.profileImageUrlKey ??
            widget.profileImageUrl;
        final future = _getResolvedProfileImageUrl(
          profileSource,
          mediaController,
        );
        return FutureBuilder<String?>(
          future: future,
          builder: (context, snapshot) {
            final resolvedUrl = snapshot.data ?? widget.profileImageUrl;
            return _buildAvatarFromUrl(resolvedUrl, size: size);
          },
        );
      },
    );
  }

  Future<String?> _getResolvedProfileImageUrl(
    String? profileKey,
    MediaController mediaController,
  ) {
    if (profileKey == null || profileKey.isEmpty) {
      return Future.value(null);
    }

    final uri = Uri.tryParse(profileKey);
    if (uri != null && uri.hasScheme) {
      return Future.value(profileKey);
    }

    final cachedFuture = _profileUrlFutures[profileKey];
    if (cachedFuture != null) {
      return cachedFuture;
    }

    final future = mediaController.getPresignedUrl(profileKey);
    _profileUrlFutures[profileKey] = future;
    return future;
  }

  Widget _buildAvatarFromUrl(String? imageUrl, {required double size}) {
    // 3D: 프로필 태그가 떠 보이도록 원형 그림자 + 하이라이트
    final avatar3dShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.55),
        offset: const Offset(0, 10),
        blurRadius: 18,
        spreadRadius: -10,
      ),
      BoxShadow(
        color: Colors.white.withValues(alpha: 0.06),
        offset: const Offset(0, -2),
        blurRadius: 6,
        spreadRadius: -4,
      ),
    ];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: avatar3dShadow,
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
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: size,
                height: size,
                memCacheWidth: (size * 2).round(),
                maxWidthDiskCache: (size * 2).round(),
                fit: BoxFit.cover,
                placeholder: (context, url) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      shape: BoxShape.circle,
                    ),
                  );
                },
                errorWidget: (context, url, error) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.red[700],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error,
                      color: Colors.white,
                      size: 14,
                    ),
                  );
                },
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xffd9d9d9),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 14),
            ),
    );
  }
}
