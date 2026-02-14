import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/views/about_archiving/screens/archive_detail/api_photo_detail_screen.dart';
import '../../../api/models/post.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../api/controller/media_controller.dart';
import '../../../utils/video_thumbnail_cache.dart';
import 'wave_form_widget/custom_waveform_widget.dart';

/// 카테고리 내에서 사진 그리드 아이템을 표시하는 위젯
///
/// Parameters:
/// - [postUrl]: 게시물 이미지 URL
/// - [post]: 단일 게시물 정보를 담은 Post 모델
/// - [allPosts]: 모든 게시물 정보를 담은 Post 모델 리스트
/// - [currentIndex]: 현재 인덱스
/// - [categoryName]: 카테고리 이름
/// - [categoryId]: 카테고리 ID
/// - [onPostsDeleted]: 사진 삭제 후 콜백 함수
///
/// Returns: 사진 그리드 아이템 위젯
class ApiPhotoGridItem extends StatefulWidget {
  final String postUrl; // post 이미지 url -> post사진을 띄우기 위한 파라미터입니다.
  final Post post; // Post 모델 -> 단일 게시물 정보를 담고 있습니다.
  final List<Post> allPosts; // 모든 Post 모델 리스트 -> 상세 화면으로 전달하기 위해 받아옵니다.
  final int currentIndex; // 현재 인덱스 -> 상세 화면으로 전달하기 위해 받아옵니다.
  final String categoryName; // 카테고리 이름 -> 상세 화면으로 전달하기 위해 받아옵니다.
  final int categoryId; // 카테고리 ID -> 상세 화면으로 전달하기 위해 받아옵니다.
  final int initialCommentCount; // 상위에서 프리패치된 댓글 개수
  final ValueChanged<List<int>>?
  onPostsDeleted; // 사진 삭제 후 콜백 --> 삭제된 게시물 ID 리스트를 전달하는 이유는 상위 위젯에서 해당 게시물을 제거하기 위함입니다.

  const ApiPhotoGridItem({
    super.key,
    required this.post,
    required this.postUrl,
    required this.allPosts,
    required this.currentIndex,
    required this.categoryName,
    required this.categoryId,
    required this.initialCommentCount,
    this.onPostsDeleted,
  });

  @override
  State<ApiPhotoGridItem> createState() => _ApiPhotoGridItemState();
}

class _ApiPhotoGridItemState extends State<ApiPhotoGridItem> {
  // 오디오 관련 상태
  bool _hasAudio = false;
  List<double>? _waveformData;
  String? _audioUrl;
  bool _isAudioLoading = false;

  // 프로필 이미지 캐시
  String? _profileImageUrl;
  bool _isLoadingProfile = true;
  late final MediaController _mediaController;
  Uint8List? _videoThumbnailBytes;
  bool _isVideoThumbnailLoading = false;

  // 댓글 개수
  int _commentCount = 0;

  @override
  void initState() {
    super.initState();
    _commentCount = widget.initialCommentCount;
    _initializeWaveformData();
    _mediaController = Provider.of<MediaController>(context, listen: false);
    // _loadAudioUrl(widget.post.audioUrl);
    _loadVideoThumbnailIfNeeded();
    // 빌드 완료 후 프로필 이미지 로드 (notifyListeners 충돌 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileImage(widget.post.userProfileImageKey);
    });
  }

  @override
  void didUpdateWidget(covariant ApiPhotoGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.userProfileImageKey != widget.post.userProfileImageKey ||
        oldWidget.post.userProfileImageUrl != widget.post.userProfileImageUrl) {
      _loadProfileImage(widget.post.userProfileImageKey);
    }
    if (oldWidget.post.audioUrl != widget.post.audioUrl) {
      _loadAudioUrl(widget.post.audioUrl);
    }
    if (oldWidget.postUrl != widget.postUrl ||
        oldWidget.post.postFileKey != widget.post.postFileKey) {
      _loadVideoThumbnailIfNeeded(forceReload: true);
    }
    if (oldWidget.initialCommentCount != widget.initialCommentCount) {
      setState(() {
        _commentCount = widget.initialCommentCount;
      });
    }
  }

  /// 비디오 썸네일 로드
  Future<void> _loadVideoThumbnailIfNeeded({bool forceReload = false}) async {
    if (!widget.post.isVideo) {
      if (!mounted) return;
      if (_videoThumbnailBytes == null && !_isVideoThumbnailLoading) return;
      setState(() {
        _videoThumbnailBytes = null;
        _isVideoThumbnailLoading = false;
      });
      return;
    }

    if (!forceReload &&
        (_videoThumbnailBytes != null || _isVideoThumbnailLoading)) {
      return;
    }

    final url = widget.postUrl;
    if (url.isEmpty) return;

    final cacheKey = widget.post.postFileKey ?? url;

    // 동기적 메모리 캐시 확인 (즉시 반영)
    if (!forceReload) {
      final memHit = VideoThumbnailCache.getFromMemory(cacheKey);
      if (memHit != null) {
        if (!mounted) return;
        setState(() {
          _videoThumbnailBytes = memHit;
          _isVideoThumbnailLoading = false;
        });
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isVideoThumbnailLoading = true);

    // 3-tier 조회: Memory → Disk → Generate
    final bytes = await VideoThumbnailCache.getThumbnail(
      videoUrl: url,
      cacheKey: cacheKey,
    );

    if (!mounted) return;
    setState(() {
      _videoThumbnailBytes = bytes;
      _isVideoThumbnailLoading = false;
    });
  }

  /// waveformData String을 `List<double>`로 파싱
  void _initializeWaveformData() {
    // 넘겨 받은 오디오 URL을 가지고 온다.
    final audioUrl = widget.post.audioUrl;

    // 오디오 URL이 없으면 오디오 없음 처리
    if (audioUrl == null || audioUrl.isEmpty) {
      setState(() {
        _hasAudio = false;
      });
      return;
    }

    // 넘겨 받은 waveformData 문자열을 가지고 온다.
    final waveformString = widget.post.waveformData;
    debugPrint('[ApiPhotoGridItem] waveformString: $waveformString');

    // waveformData가 있으면 파싱 시도
    if (waveformString != null && waveformString.isNotEmpty) {
      final parsedData = _parseWaveformString(waveformString);
      if (parsedData != null) {
        setState(() {
          _hasAudio = true;
          _waveformData = parsedData;
        });
        return;
      }
      debugPrint('[ApiPhotoGridItem] waveformData 파싱 실패: $waveformString');
    }

    setState(() {
      _hasAudio = true;
      _waveformData = null;
    });
  }

  /// waveformData 문자열을 `List<double>`로 파싱
  ///
  /// Parameters:
  /// - [raw]: 파싱할 문자열
  ///
  /// Returns: 파싱된 `List<double>` 또는 null
  List<double>? _parseWaveformString(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded.map((e) => (e as num).toDouble()).toList();
      }
    } catch (_) {
      final sanitized = trimmed.replaceAll('[', '').replaceAll(']', '');
      final parts = sanitized
          .split(RegExp(r'[,\s]+'))
          .where((p) => p.isNotEmpty);
      try {
        final values = parts.map((p) => double.parse(p)).toList();
        return values.isEmpty ? null : values;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// 프로필 이미지 URL 설정 (서버에서 직접 제공)
  void _loadProfileImage(String? profileKey) {
    if (!mounted) return;
    final url = widget.post.userProfileImageUrl;
    setState(() {
      _profileImageUrl = (url != null && url.isNotEmpty) ? url : null;
      _isLoadingProfile = false;
    });
  }

  Future<void> _loadAudioUrl(String? audioKey) async {
    if (audioKey == null || audioKey.isEmpty) {
      setState(() {
        _audioUrl = null;
        _isAudioLoading = false;
      });
      return;
    }

    final uri = Uri.tryParse(audioKey);
    if (uri != null && uri.hasScheme) {
      setState(() {
        _audioUrl = audioKey;
        _isAudioLoading = false;
      });
      return;
    }

    setState(() => _isAudioLoading = true);
    try {
      final url = await _mediaController.getPresignedUrl(audioKey);
      if (!mounted) return;
      setState(() {
        _audioUrl = url;
        _isAudioLoading = false;
      });
    } catch (e) {
      debugPrint('[ApiPhotoGridItem] 오디오 URL 발급 실패: $e');
      if (!mounted) return;
      setState(() {
        _audioUrl = null;
        _isAudioLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // API 버전의 PhotoDetailScreen으로 이동
        Navigator.push<List<int>>(
          context,
          MaterialPageRoute(
            builder: (_) => ApiPhotoDetailScreen(
              allPosts: widget.allPosts,
              initialIndex: widget.currentIndex,
              categoryName: widget.categoryName,
              categoryId: widget.categoryId,
            ),
          ),
        ).then((deletedPostIds) {
          if (deletedPostIds == null || deletedPostIds.isEmpty) return;
          widget.onPostsDeleted?.call(deletedPostIds);
        });
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 미디어(사진/비디오 썸네일)
          SizedBox(
            width: 170.sp,
            height: 204.sp,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: widget.post.isVideo
                  ? _buildVideoThumbnail()
                  : (widget.postUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.postUrl,
                            // presigned URL이 바뀌어도 같은 파일이면 디스크 캐시 재사용
                            cacheKey: widget.post.postFileKey,
                            useOldImageOnUrlChange: true,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            memCacheWidth: (170 * 2).round(),
                            maxWidthDiskCache: (170 * 2).round(),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey.shade800,
                              highlightColor: Colors.grey.shade700,
                              period: const Duration(milliseconds: 1500),
                              child: Container(color: Colors.grey.shade800),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade800,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.image,
                                color: Colors.grey.shade600,
                                size: 32.sp,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade800,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.image,
                              color: Colors.grey.shade600,
                              size: 32.sp,
                            ),
                          )),
            ),
          ),

          // 댓글 개수 (우측 하단)
          Positioned(
            bottom: 8.h,
            right: 8.w,
            child: Row(
              children: [
                Text(
                  '$_commentCount',
                  style: TextStyle(
                    color: const Color(0xFFF8F8F8),
                    fontSize: 14,
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.40,
                  ),
                ),
                SizedBox(width: (5.96).w),
                Image.asset(
                  'assets/comment_icon.png',
                  width: (15.75),
                  height: (15.79),
                  color: Color(0xfff9f9f9),
                ),
                SizedBox(width: (10.29)),
              ],
            ),
          ),

          // 하단 프로필 + 파형
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  SizedBox(width: 8.w),
                  // 프로필 이미지
                  Container(
                    width: 28.w,
                    height: 28.h,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: _buildProfileImage(),
                  ),
                  SizedBox(width: 7.w),
                  // 파형 위젯
                  Expanded(
                    child:
                        (!_hasAudio ||
                            _waveformData == null ||
                            _waveformData!.isEmpty)
                        ? Container()
                        : GestureDetector(
                            onTap: () => _toggleAudioPlayback(),
                            child: Container(
                              width: 140.w,
                              height: 21.h,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xff171717,
                                ).withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: _buildWaveformWidget(),
                            ),
                          ),
                  ),
                  SizedBox(width: 5.w),
                ],
              ),
              SizedBox(height: 5.h),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoThumbnail() {
    if (_videoThumbnailBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _videoThumbnailBytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // 메모리 최적화: 디코딩 시 크기 제한
            cacheWidth: 262, // 175 * 1.5
          ),
          // 비디오 재생 아이콘 표시
          Center(
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow, color: Colors.white, size: 24.sp),
            ),
          ),
        ],
      );
    }

    if (_isVideoThumbnailLoading) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey.shade800,
            highlightColor: Colors.grey.shade700,
            period: const Duration(milliseconds: 1500),
            child: Container(color: Colors.grey.shade800),
          ),
          // ✨ 로딩 중에도 비디오 아이콘 표시
          Center(
            child: Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.videocam,
                color: Colors.white.withValues(alpha: 0.7),
                size: 24.sp,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      color: Colors.grey.shade800,
      alignment: Alignment.center,
      child: Icon(Icons.videocam, color: Colors.grey.shade600, size: 32.sp),
    );
  }

  /// 프로필 이미지 빌드
  Widget _buildProfileImage() {
    if (_isLoadingProfile) {
      return Shimmer.fromColors(
        baseColor: Colors.grey.shade800,
        highlightColor: Colors.grey.shade700,
        period: const Duration(milliseconds: 1500),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    if (_profileImageUrl == null || _profileImageUrl!.isEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xffd9d9d9),
        child: Icon(Icons.person, color: Colors.white, size: 18.sp),
      );
    }

    return CachedNetworkImage(
      key: ValueKey(
        'profile_${widget.post.nickName}_${widget.post.userProfileImageKey}',
      ),
      imageUrl: _profileImageUrl!,
      cacheKey: widget.post.userProfileImageKey,
      useOldImageOnUrlChange: true,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: (28 * 5).round(),
      maxWidthDiskCache: (28 * 5).round(),
      imageBuilder: (context, imageProvider) =>
          CircleAvatar(radius: 14, backgroundImage: imageProvider),
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey.shade800,
        highlightColor: Colors.grey.shade700,
        period: const Duration(milliseconds: 1500),
        child: CircleAvatar(radius: 14, backgroundColor: Colors.grey.shade800),
      ),
      errorWidget: (context, url, error) => Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFd9d9d9),
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 26),
      ),
    );
  }

  /// 오디오 재생/일시정지 토글
  void _toggleAudioPlayback() async {
    if (!_hasAudio || _audioUrl == null || _audioUrl!.isEmpty) return;

    final audioController = Provider.of<AudioController>(
      context,
      listen: false,
    );

    audioController.togglePlayPause(_audioUrl!);
  }

  /// 파형 위젯 빌드
  Widget _buildWaveformWidget() {
    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isCurrentAudio =
            audioController.isPlaying &&
            _audioUrl != null &&
            audioController.currentAudioUrl == _audioUrl;

        double progress = 0.0;
        if (isCurrentAudio &&
            audioController.totalDuration.inMilliseconds > 0) {
          progress =
              (audioController.currentPosition.inMilliseconds /
                      audioController.totalDuration.inMilliseconds)
                  .clamp(0.0, 1.0);
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 21,
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: CustomWaveformWidget(
                waveformData: _waveformData!,
                color: isCurrentAudio
                    ? const Color(0xff5a5a5a)
                    : const Color(0xffffffff),
                activeColor: Colors.white,
                progress: progress,
              ),
            ),
            if (_isAudioLoading)
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        );
      },
    );
  }
}
