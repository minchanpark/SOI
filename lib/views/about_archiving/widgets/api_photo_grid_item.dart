import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/views/about_archiving/screens/archive_detail/api_photo_detail_screen.dart';
import '../../../api/models/post.dart';
import '../../../api/controller/audio_controller.dart';
import '../../../api/controller/media_controller.dart';
import 'wave_form_widget/custom_waveform_widget.dart';

/// REST API 기반 사진 그리드 아이템 위젯
///
/// Firebase 버전의 PhotoGridItem과 동일한 UI를 유지하면서
/// Post 모델을 사용합니다.
class ApiPhotoGridItem extends StatefulWidget {
  final String postUrl; // post 이미지 url -> post사진을 띄우기 위한 파라미터입니다.
  final Post post; // Post 모델 -> 단일 게시물 정보를 담고 있습니다.
  final List<Post> allPosts; // 모든 Post 모델 리스트 -> 상세 화면으로 전달하기 위해 받아옵니다.
  final int currentIndex; // 현재 인덱스 -> 상세 화면으로 전달하기 위해 받아옵니다.
  final String categoryName; // 카테고리 이름 -> 상세 화면으로 전달하기 위해 받아옵니다.
  final int categoryId; // 카테고리 ID -> 상세 화면으로 전달하기 위해 받아옵니다.

  const ApiPhotoGridItem({
    super.key,
    required this.post,
    required this.postUrl,
    required this.allPosts,
    required this.currentIndex,
    required this.categoryName,
    required this.categoryId,
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

  @override
  void initState() {
    super.initState();
    _initializeWaveformData();
    _mediaController = Provider.of<MediaController>(context, listen: false);
    _loadAudioUrl(widget.post.audioUrl);
    // 빌드 완료 후 프로필 이미지 로드 (notifyListeners 충돌 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileImage(widget.post.userProfileImageKey);
    });
  }

  @override
  void didUpdateWidget(covariant ApiPhotoGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.userProfileImageKey != widget.post.userProfileImageKey) {
      _loadProfileImage(widget.post.userProfileImageKey);
    }
    if (oldWidget.post.audioUrl != widget.post.audioUrl) {
      _loadAudioUrl(widget.post.audioUrl);
    }
  }

  /// waveformData String을 List<double>로 파싱
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

  /// waveformData 문자열을 List<double>로 파싱
  ///
  /// Parameters:
  /// - [raw]: 파싱할 문자열
  ///
  /// Returns: 파싱된 List<double> 또는 null
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

  /// 프로필 이미지 로드
  Future<void> _loadProfileImage(String? profileKey) async {
    if (profileKey == null || profileKey.isEmpty) {
      if (!mounted) return;
      setState(() {
        _profileImageUrl = null;
        _isLoadingProfile = false;
      });
      return;
    }

    setState(() => _isLoadingProfile = true);
    try {
      final url = await _mediaController.getPresignedUrl(profileKey);
      if (!mounted) return;
      setState(() {
        _profileImageUrl = url;
        _isLoadingProfile = false;
      });
    } catch (e) {
      debugPrint('[ApiPhotoGridItem] 프로필 이미지 로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _profileImageUrl = null;
        _isLoadingProfile = false;
      });
    }
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ApiPhotoDetailScreen(
              allPosts: widget.allPosts,
              initialIndex: widget.currentIndex,
              categoryName: widget.categoryName,
              categoryId: widget.categoryId,
            ),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 사진 이미지
          SizedBox(
            width: 175,
            height: 232,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.postUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.postUrl,
                      memCacheWidth: (175 * 2).round(),
                      maxWidthDiskCache: (175 * 2).round(),
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
                    ),
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
        'profile_${widget.post.nickName}_${_profileImageUrl.hashCode}',
      ),
      imageUrl: _profileImageUrl!,
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
