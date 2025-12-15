import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'circular_video_progress_indicator.dart';
import 'pressable_container.dart';

/// 카메라 촬영 버튼 위젯
///
/// 사진 촬영 및 비디오 녹화 기능을 제공하는 버튼입니다.
///
/// Parameters:
/// - [isVideoRecording]: 현재 비디오 녹화 상태를 나타내는 불리언 값입니다.
/// - [videoProgress]: 비디오 녹화 진행 상황을 나타내는 ValueListenable 객체입니다.
/// - [onTakePicture]: 사진 촬영 시 호출되는 콜백 함수입니다.
/// - [onStartVideoRecording]: 비디오 녹화 시작 시 호출되는 콜백 함수입니다.
/// - [onStopVideoRecording]: 비디오 녹화 중지 시 호출되는 콜백 함수입니다.
class CameraCaptureButton extends StatelessWidget {
  const CameraCaptureButton({
    required this.isVideoRecording,
    required this.videoProgress,
    required this.onTakePicture,
    required this.onStartVideoRecording,
    required this.onStopVideoRecording,
    super.key,
  });

  final bool isVideoRecording;
  final ValueListenable<double> videoProgress;
  final VoidCallback onTakePicture;
  final Future<void> Function() onStartVideoRecording;
  final VoidCallback onStopVideoRecording;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90.w,
      child: Center(
        child: isVideoRecording
            ? SizedBox(
                height: 90.h,
                child: ValueListenableBuilder<double>(
                  valueListenable: videoProgress,
                  builder: (context, progress, child) {
                    return GestureDetector(
                      onTap: onStopVideoRecording,
                      child: CircularVideoProgressIndicator(
                        progress: progress,
                        innerSize: 40.42,
                        gap: 15.29,
                        strokeWidth: 3.0,
                      ),
                    );
                  },
                ),
              )
            : PressableContainer(
                onTap: onTakePicture,
                onLongPress: () => unawaited(onStartVideoRecording()),
                padding: EdgeInsets.zero,
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                child: Image.asset(
                  "assets/take_picture.png",
                  width: 65,
                  height: 65,
                ),
              ),
      ),
    );
  }
}
