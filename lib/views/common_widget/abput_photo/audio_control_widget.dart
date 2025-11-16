import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../api_firebase/controllers/auth_controller.dart';
import '../../../api_firebase/controllers/audio_controller.dart';
import '../../../api_firebase/models/photo_data_model.dart';
import '../../../utils/format_utils.dart';
import '../../about_archiving/widgets/wave_form_widget/custom_waveform_widget.dart';

/// 오디오 컨트롤 위젯 (프로필 - 파형 - 시간)
/// 단일 책임: 오디오 재생 제어 및 상태 표시
class AudioControlWidget extends StatelessWidget {
  final MediaDataModel photo;
  final VoidCallback onAudioTap;
  final VoidCallback? onCommentIconTap;
  final bool hasComments;

  const AudioControlWidget({
    super.key,
    required this.photo,
    required this.onAudioTap,
    this.onCommentIconTap,
    this.hasComments = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50.h,
      child: Row(
        children: [
          // 오디오 영역 (고정 width)
          SizedBox(
            width: 278.w,
            child: GestureDetector(
              onTap: onAudioTap,
              child: Container(
                width: 278.w,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(0xff000000).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 왼쪽 프로필 이미지 (작은 버전)
                    Container(
                      width: 27,
                      height: 27,
                      decoration: BoxDecoration(shape: BoxShape.circle),
                      child: ClipOval(child: _buildUserProfileWidget(context)),
                    ),
                    SizedBox(width: 17.w),

                    // 가운데 파형 (progress 포함)
                    SizedBox(
                      width: 144.62.w,
                      height: 32.h,
                      child: _buildWaveformWidgetWithProgress(context),
                    ),

                    SizedBox(width: 17.w),

                    // 오른쪽 재생 시간 (실시간 업데이트)
                    SizedBox(
                      width: 45.w,
                      child: Consumer<AudioController>(
                        builder: (context, audioController, child) {
                          // 현재 사진의 오디오가 재생 중인지 확인
                          final isCurrentAudio =
                              audioController.isPlaying &&
                              audioController.currentPlayingAudioUrl ==
                                  photo.audioUrl;

                          // 실시간 재생 시간 사용
                          Duration displayDuration = Duration.zero;
                          if (isCurrentAudio) {
                            displayDuration = audioController.currentPosition;
                          }

                          return Text(
                            FormatUtils.formatDuration(
                              isCurrentAudio ? displayDuration : photo.duration,
                            ),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 댓글 아이콘 영역 (고정 width)
          SizedBox(
            width: 60.w,
            child: hasComments
                ? Center(
                    child: IconButton(
                      onPressed: onCommentIconTap,
                      icon: Image.asset(
                        "assets/comment_profile_icon.png",
                        width: 25.w,
                        height: 25.h,
                      ),
                    ),
                  )
                : Container(),
          ),
        ],
      ),
    );
  }

  /// 사용자 프로필 이미지 위젯 빌드
  Widget _buildUserProfileWidget(BuildContext context) {
    final userId = photo.userID;
    final screenWidth = MediaQuery.of(context).size.width;
    final profileSize = screenWidth * 0.085;

    return Consumer<AuthController>(
      builder: (context, authController, child) {
        return StreamBuilder<String>(
          stream: authController.getUserProfileImageUrlStream(userId),
          builder: (context, snapshot) {
            final profileImageUrl = snapshot.data ?? '';

            return ClipOval(
              child: profileImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: profileImageUrl,
                      fit: BoxFit.cover,

                      memCacheWidth: (profileSize * 4).round(),
                      maxWidthDiskCache: (profileSize * 4).round(),

                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: const Color(0xFF2A2A2A),
                        highlightColor: const Color(0xFF3A3A3A),
                        child: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF2A2A2A),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFd9d9d9),
                        ),
                        child: Icon(Icons.person, size: 20),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFd9d9d9),
                      ),
                      child: Icon(Icons.person, size: 20),
                    ),
            );
          },
        );
      },
    );
  }

  /// 커스텀 파형 위젯을 빌드하는 메서드 (실시간 progress 포함)
  Widget _buildWaveformWidgetWithProgress(BuildContext context) {
    if (photo.audioUrl.isEmpty ||
        photo.waveformData == null ||
        photo.waveformData!.isEmpty) {
      return Container(
        height: 32,
        alignment: Alignment.center,
        child: const Text(
          '오디오 없음',
          style: TextStyle(color: Colors.white70, fontSize: 10),
        ),
      );
    }

    return Consumer<AudioController>(
      builder: (context, audioController, child) {
        final isCurrentAudio =
            audioController.isPlaying &&
            audioController.currentPlayingAudioUrl == photo.audioUrl;

        double progress = 0.0;
        if (isCurrentAudio &&
            audioController.currentDuration.inMilliseconds > 0) {
          progress =
              (audioController.currentPosition.inMilliseconds /
                      audioController.currentDuration.inMilliseconds)
                  .clamp(0.0, 1.0);
        }

        return Container(
          alignment: Alignment.center,
          child: CustomWaveformWidget(
            waveformData: photo.waveformData!,
            color: isCurrentAudio ? Color(0xff5a5a5a) : Color(0xffffffff),
            activeColor: Colors.white,
            progress: progress,
          ),
        );
      },
    );
  }
}
