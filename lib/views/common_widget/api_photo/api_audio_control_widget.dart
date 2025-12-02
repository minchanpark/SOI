import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../api/models/post.dart';
import '../../../api_firebase/controllers/audio_controller.dart';
import '../../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';

/// API 기반 오디오 컨트롤 위젯
///
/// Firebase 버전의 AudioControlWidget과 동일한 디자인을 유지하면서
/// Post 모델을 사용합니다.
class ApiAudioControlWidget extends StatelessWidget {
  final Post post;
  final List<double>? waveformData;

  const ApiAudioControlWidget({
    super.key,
    required this.post,
    this.waveformData,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isPlaying =
            audioController.currentPlayingAudioUrl == post.audioUrl;
        final progress = isPlaying && audioController.playbackDuration > 0
            ? (audioController.playbackPosition /
                      audioController.playbackDuration)
                  .clamp(0.0, 1.0)
            : 0.0;

        return GestureDetector(
          onTap: () {
            if (post.hasAudio) {
              audioController.toggleAudio(post.audioUrl!);
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 재생/일시정지 아이콘
                Icon(
                  isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 20.w,
                ),
                SizedBox(width: 8.w),

                // 파형 표시
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

                // 재생 시간
                Text(
                  _formatDuration(Duration(seconds: post.durationInSeconds)),
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
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
