import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/views/about_archiving/screens/archive_detail/api_photo_detail_screen.dart';
import '../../../api/models/post.dart';
import '../../../api/controller/api_user_controller.dart';
import '../../../api_firebase/controllers/audio_controller.dart';
import 'wave_form_widget/custom_waveform_widget.dart';

/// REST API 기반 사진 그리드 아이템 위젯
///
/// Firebase 버전의 PhotoGridItem과 동일한 UI를 유지하면서
/// Post 모델을 사용합니다.
class ApiPhotoGridItem extends StatefulWidget {
  final Post post;
  final List<Post> allPosts;
  final int currentIndex;
  final String categoryName;
  final int categoryId;

  const ApiPhotoGridItem({
    super.key,
    required this.post,
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

  // 프로필 이미지 캐시
  String? _profileImageUrl;
  bool _isLoadingProfile = true;

  ApiUserController? userController;

  @override
  void initState() {
    super.initState();
    _initializeWaveformData();
    userController = Provider.of<ApiUserController>(context, listen: false);
    // 빌드 완료 후 프로필 이미지 로드 (notifyListeners 충돌 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileImage();
    });
  }

  /// waveformData String을 List<double>로 파싱
  void _initializeWaveformData() {
    final audioUrl = widget.post.audioUrl;

    if (audioUrl == null || audioUrl.isEmpty) {
      setState(() {
        _hasAudio = false;
      });
      return;
    }

    final waveformString = widget.post.waveformData;
    if (waveformString != null && waveformString.isNotEmpty) {
      try {
        // JSON 문자열을 List<double>로 파싱
        final List<dynamic> decoded = jsonDecode(waveformString);
        setState(() {
          _hasAudio = true;
          _waveformData = decoded.map((e) => (e as num).toDouble()).toList();
        });
      } catch (e) {
        debugPrint('[ApiPhotoGridItem] waveformData 파싱 실패: $e');
        setState(() {
          _hasAudio = true;
          _waveformData = null;
        });
      }
    } else {
      setState(() {
        _hasAudio = true;
        _waveformData = null;
      });
    }
  }

  /// 프로필 이미지 로드
  Future<void> _loadProfileImage() async {
    try {
      userController = Provider.of<ApiUserController>(context, listen: false);
      final user = await userController!.getUser(
        userController!.currentUser!.id,
      );

      if (mounted) {
        setState(() {
          _profileImageUrl = user?.profileImageUrl;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('[ApiPhotoGridItem] 프로필 이미지 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
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
              posts: widget.allPosts,
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
              child: widget.post.hasImage
                  ? CachedNetworkImage(
                      imageUrl: widget.post.imageUrl!,
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
        'profile_${widget.post.userId}_${_profileImageUrl.hashCode}',
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
    if (!_hasAudio || widget.post.audioUrl == null) return;

    final audioController = Provider.of<AudioController>(
      context,
      listen: false,
    );

    audioController.toggleAudio(widget.post.audioUrl!);
  }

  /// 파형 위젯 빌드
  Widget _buildWaveformWidget() {
    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isCurrentAudio =
            audioController.isPlaying &&
            audioController.currentPlayingAudioUrl == widget.post.audioUrl;

        double progress = 0.0;
        if (isCurrentAudio &&
            audioController.currentDuration.inMilliseconds > 0) {
          progress =
              (audioController.currentPosition.inMilliseconds /
                      audioController.currentDuration.inMilliseconds)
                  .clamp(0.0, 1.0);
        }

        return Container(
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
        );
      },
    );
  }
}
