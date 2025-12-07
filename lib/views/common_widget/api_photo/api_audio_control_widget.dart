import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../api/models/post.dart';
import '../../../api/controller/audio_controller.dart';
import '../../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';

/// API 기반 오디오 컨트롤 위젯
///
/// Firebase 버전의 AudioControlWidget과 동일한 디자인을 유지하면서
/// Post 모델을 사용합니다.
class ApiAudioControlWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (_hasAudioController(context)) {
      return Consumer<AudioController>(
        builder: (context, audioController, child) {
          final isPlaying =
              audioController.currentAudioUrl == post.audioUrl;
          final progress = isPlaying && audioController.totalDuration.inMilliseconds > 0
              ? (audioController.currentPosition.inMilliseconds /
                        audioController.totalDuration.inMilliseconds)
                    .clamp(0.0, 1.0)
              : 0.0;

          return _AudioControlSurface(
            isPlaying: isPlaying,
            progress: progress,
            waveformData: waveformData,
            duration: Duration(seconds: post.durationInSeconds),
            onTap: () {
              if (onPressed != null) {
                onPressed!();
              } else if (post.hasAudio) {
                audioController.togglePlayPause(post.audioUrl!);
              }
            },
          );
        },
      );
    }

    // Provider가 없는 경우에도 UI가 깨지지 않도록 기본 컨트롤 표출
    return _AudioControlSurface(
      isPlaying: false,
      progress: 0,
      waveformData: waveformData,
      duration: Duration(seconds: post.durationInSeconds),
      onTap: () {
        if (onPressed != null) {
          onPressed!();
        }
      },
    );
  }

  bool _hasAudioController(BuildContext context) {
    try {
      Provider.of<AudioController>(context, listen: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _AudioControlSurface extends StatelessWidget {
  final bool isPlaying;
  final double progress;
  final List<double>? waveformData;
  final Duration duration;
  final VoidCallback? onTap;

  const _AudioControlSurface({
    required this.isPlaying,
    required this.progress,
    required this.waveformData,
    required this.duration,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 20.w,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: SizedBox(
                height: 30.h,
                child: waveformData != null
                    ? CustomWaveformWidget(
                        waveformData: waveformData!,
                        progress: progress,
                        activeColor: Colors.white,
                        color: Colors.grey[600]!,
                      )
                    : LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[600],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
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

  static String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
