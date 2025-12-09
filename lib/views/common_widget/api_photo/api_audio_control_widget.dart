import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/media_controller.dart';

import '../../../api/models/post.dart';
import '../../../api/controller/audio_controller.dart';
import '../../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';

/// API 기반 오디오 컨트롤 위젯
///
/// post의 audioUrl이 null이 아니면 재생 가능
///
/// Parameters:
///   - [post]: 오디오가 포함된 Post 객체 (필수)
///   - [waveformData]: 오디오 파형 데이터 (선택적)
///   - [onPressed]: 커스텀 재생/일시정지 콜백 (선택적)
class ApiAudioControlWidget extends StatefulWidget {
  final Post post;
  final List<double>? waveformData;
  final VoidCallback? onPressed;

  const ApiAudioControlWidget({
    super.key,
    required this.post,
    this.waveformData,
    this.onPressed,
  });

  @override
  State<ApiAudioControlWidget> createState() => _ApiAudioControlWidgetState();
}

class _ApiAudioControlWidgetState extends State<ApiAudioControlWidget> {
  String? _profileImageUrl;
  bool _isProfileLoading = false;
  String? _audioUrl;
  bool _isAudioLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileImage(widget.post.userProfileImageKey);
    _fetchAudioUrl(widget.post.audioUrl);
  }

  @override
  void didUpdateWidget(covariant ApiAudioControlWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.userProfileImageKey != widget.post.userProfileImageKey) {
      _fetchProfileImage(widget.post.userProfileImageKey);
    }
    if (oldWidget.post.audioUrl != widget.post.audioUrl) {
      _fetchAudioUrl(widget.post.audioUrl);
    }
  }

  /// 프로필 이미지 URL을 비동기로 가져오는 메소드
  Future<void> _fetchProfileImage(String? profileKey) async {
    if (!mounted) return;

    if (profileKey == null || profileKey.isEmpty) {
      setState(() {
        _profileImageUrl = null;
        _isProfileLoading = false;
      });
      return;
    }

    setState(() => _isProfileLoading = true);

    try {
      // MediaController 인스턴스 가져오기
      final mediaController = Provider.of<MediaController>(
        context,
        listen: false,
      );

      // Presigned URL 가져오기
      final profileImageUrl = await mediaController.getPresignedUrl(profileKey);
      if (!mounted) return;
      setState(() {
        _profileImageUrl = profileImageUrl;
        _isProfileLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _profileImageUrl = null;
        _isProfileLoading = false;
      });
    }
  }

  Future<void> _fetchAudioUrl(String? audioKey) async {
    if (!mounted) return;

    if (audioKey == null || audioKey.isEmpty) {
      setState(() {
        _audioUrl = null;
        _isAudioLoading = false;
      });
      return;
    }

    final parsed = Uri.tryParse(audioKey);
    if (parsed != null && parsed.hasScheme) {
      setState(() {
        _audioUrl = audioKey;
        _isAudioLoading = false;
      });
      return;
    }

    setState(() => _isAudioLoading = true);
    try {
      final mediaController = Provider.of<MediaController>(
        context,
        listen: false,
      );
      final resolved = await mediaController.getPresignedUrl(audioKey);
      if (!mounted) return;
      setState(() {
        _audioUrl = resolved;
        _isAudioLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _audioUrl = null;
        _isAudioLoading = false;
      });
    }
  }

  String? get _effectiveAudioUrl {
    if (_audioUrl != null && _audioUrl!.isNotEmpty) {
      return _audioUrl;
    }
    final original = widget.post.audioUrl;
    final parsed = original != null ? Uri.tryParse(original) : null;
    if (parsed != null && parsed.hasScheme) {
      return original;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // AudioController Provider가 존재하는 경우 --> 오디오 재생/일시정지 기능 활성화
    if (_hasAudioController(context)) {
      return Consumer<AudioController>(
        builder: (context, audioController, child) {
          final audioSource = _effectiveAudioUrl;
          final isPlaying = audioSource != null &&
              audioController.currentAudioUrl == audioSource;
          final progress =
              isPlaying && audioController.totalDuration.inMilliseconds > 0
              ? (audioController.currentPosition.inMilliseconds /
                        audioController.totalDuration.inMilliseconds)
                    .clamp(0.0, 1.0)
              : 0.0;

          return _AudioControlSurface(
            isPlaying: isPlaying,
            progress: progress,
            waveformData: widget.waveformData,
            duration: Duration(seconds: widget.post.durationInSeconds),
            post: widget.post,
            profileImageUrl: _profileImageUrl,
            isProfileLoading: _isProfileLoading,
            isAudioLoading: _isAudioLoading,

            onTap: () {
              final url = _effectiveAudioUrl;
              if (url == null || url.isEmpty) return;
              if (widget.onPressed != null) {
                widget.onPressed!();
              } else if (widget.post.hasAudio) {
                audioController.togglePlayPause(url);
              }
            },
          );
        },
      );
    }

    // AudioController Provider가 존재하지 않는 경우 --> 재생 불가 UI 표시
    return _AudioControlSurface(
      isPlaying: false,
      progress: 0,
      waveformData: widget.waveformData,
      duration: Duration(seconds: widget.post.durationInSeconds),
      post: widget.post,
      profileImageUrl: _profileImageUrl,
      isProfileLoading: _isProfileLoading,
      isAudioLoading: _isAudioLoading,
      onTap: () {
        if (widget.onPressed != null) {
          widget.onPressed!();
        }
      },
    );
  }

  // AudioController Provider 존재 여부를 확인하는 메소드
  // 존재하지 않으면 예외 발생
  bool _hasAudioController(BuildContext context) {
    try {
      Provider.of<AudioController>(context, listen: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  /*String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }*/
}

// 오디오 컨트롤 UI 서피스
class _AudioControlSurface extends StatelessWidget {
  final bool isPlaying;
  final double progress;
  final List<double>? waveformData;
  final Duration duration;
  final VoidCallback? onTap;
  final Post post;
  final String? profileImageUrl;
  final bool isProfileLoading;
  final bool isAudioLoading;

  _AudioControlSurface({
    required this.isPlaying,
    required this.progress,
    required this.waveformData,
    required this.duration,
    required this.post,
    required this.profileImageUrl,
    required this.isProfileLoading,
    required this.isAudioLoading,

    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool disableTap = isAudioLoading;
    return GestureDetector(
      onTap: disableTap ? null : onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProfileImage(),
            SizedBox(width: 8.w),
            Expanded(
              child: SizedBox(
                height: 30.h,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (waveformData != null)
                      CustomWaveformWidget(
                        waveformData: waveformData!,
                        progress: progress,
                        activeColor: Colors.white,
                        color: Colors.grey[600]!,
                      )
                    else
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[600],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    if (isAudioLoading)
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              _format(duration),
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                fontFamily: 'Pretendard',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 시간 형식 변환 (mm:ss)
  static String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // 프로필 이미지 빌드
  Widget _buildProfileImage() {
    if (isProfileLoading) {
      return SizedBox(
        width: 30.w,
        height: 30.w,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade500),
        ),
      );
    }

    if (profileImageUrl == null || profileImageUrl!.isEmpty) {
      return _placeholderAvatar();
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: profileImageUrl!,
        width: 30.w,
        height: 30.w,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _placeholderAvatar() {
    return Container(
      width: 30.w,
      height: 30.w,
      decoration: const BoxDecoration(
        color: Colors.grey,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, color: Colors.white, size: 16.sp),
    );
  }
}
