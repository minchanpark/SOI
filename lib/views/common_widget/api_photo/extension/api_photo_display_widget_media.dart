// ignore_for_file: invalid_use_of_protected_member

part of '../api_photo_display_widget.dart';

/// 미디어(사진/비디오) 관련 확장 메서드
/// 미디어 콘텐츠 빌드, 프로필 이미지 로드, 웨이브폼 데이터 파싱 등을 담당합니다.
///
/// 댓글 태그 관련 메서드는 [api_photo_display_widget_comment_tags.dart]에 있습니다.
extension _ApiPhotoDisplayWidgetMediaExtension on _ApiPhotoDisplayWidgetState {
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

  /// 프로필 이미지 설정 (서버에서 제공하는 URL 직접 사용)
  void _loadProfileImage(String? key) {
    final url = widget.post.userProfileImageUrl;
    _safeSetState(() {
      _uploaderProfileImageUrl = (url != null && url.isNotEmpty) ? url : null;
      _isProfileLoading = false;
    });
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
    // text-only 게시물인 경우, 미디어 대신 텍스트 콘텐츠 빌드
    if (_isTextOnlyPost) {
      return _buildTextOnlyContent();
    }

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
                width: _imageSize.width,
                height: _imageSize.height,
                //clipBehavior: Clip.antiAlias, // BoxFit.cover 시 overflow 방지
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
                    fit: _isVideoCoverMode ? BoxFit.contain : BoxFit.cover,
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
            width: _imageSize.width,
            height: _imageSize.height,
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
          width: _imageSize.width,
          height: _imageSize.height,
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
              // presigned URL이 바뀌어도(쿼리스트링 변경 등) 같은 파일 key면 같은 캐시를 쓰게 함
              cacheKey: widget.post.postFileKey,
              useOldImageOnUrlChange: true, // URL 변경 시에도 이전 이미지 유지(체감 깜빡임 감소)
              fadeInDuration: Duration.zero, // 로드 후 페이드 제거(체감 쉬머 감소)
              fadeOutDuration: Duration.zero,
              width: _imageSize.width,
              height: _imageSize.height,
              fit: _isImageCoverMode
                  ? BoxFit.contain
                  : BoxFit.cover, // 더블탭으로 전환
              memCacheWidth: ((354.w * dpr).round()),
              maxWidthDiskCache: (354.w * dpr).round(),
              placeholder: (context, _) => Shimmer.fromColors(
                baseColor: Colors.grey[800]!,
                highlightColor: Colors.grey[600]!,
                child: Container(
                  width: _imageSize.width,
                  height: _imageSize.height,
                  color: Colors.grey[800],
                ),
              ),
              errorWidget: (context, _, __) => Container(
                width: _imageSize.width,
                height: _imageSize.height,
                color: Colors.grey[800],
                child: Icon(
                  Icons.broken_image,
                  color: Colors.grey[600],
                  size: 50.w,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _buildUnsupportedMedia();
  }

  /// text-only 게시물 콘텐츠 빌드
  Widget _buildTextOnlyContent() {
    final text = widget.post.content?.trim() ?? '';
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: const Color(0xff2b2b2b), width: 2.0),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18.0),
        child: Container(
          color: const Color(0xff1e1e1e),
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xfff8f8f8),
                        fontSize: 30.sp,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 지원되지 않는 미디어 표시 위젯 빌드
  Widget _buildUnsupportedMedia() {
    return Container(
      width: _imageSize.width,
      height: _imageSize.height,
      color: Colors.grey[800],
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[600],
        size: 50.w,
      ),
    );
  }

  /// 미디어를 로딩할 때 보여줄 플레이스홀더 빌드
  Widget _buildMediaPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: Container(
        width: _imageSize.width,
        height: _imageSize.height,
        color: Colors.grey[800],
      ),
    );
  }
}
