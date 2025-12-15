import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';

import 'camera_recording_indicator.dart';
import 'camera_shimmer_box.dart';

/// 카메라 프리뷰를 감싸는 컨테이너 위젯
/// 카메라 화면을 띄우는 위젯입니다.s
class CameraPreviewContainer extends StatelessWidget {
  const CameraPreviewContainer({
    required this.initialization,
    required this.isLoading,
    required this.cameraView,
    required this.showZoomControls,
    required this.zoomControls,
    required this.isVideoRecording,
    required this.isFlashOn,
    required this.onToggleFlash,
    this.width,
    this.height,
    this.recordingIndicator = const CameraRecordingIndicator(),
    super.key,
  });

  final Future<void>? initialization;
  final bool isLoading;
  final Widget cameraView;
  final bool showZoomControls;
  final Widget zoomControls;
  final bool isVideoRecording;
  final bool isFlashOn;
  final VoidCallback onToggleFlash;
  final double? width;
  final double? height;
  final Widget recordingIndicator;

  @override
  Widget build(BuildContext context) {
    final double previewWidth = width ?? 354.w;
    final double previewHeight = height ?? 500.h;

    return Center(
      child: FutureBuilder<void>(
        future: initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Container(
              constraints: const BoxConstraints(maxHeight: double.infinity),
              width: previewWidth,
              height: previewHeight,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  '카메라를 시작할 수 없습니다.\n앱을 다시 시작해 주세요.',
                  style: TextStyle(color: Colors.white, fontSize: 18.sp),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Stack(
            alignment: Alignment.topCenter,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: previewWidth,
                  height: previewHeight,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      cameraView,
                      if (showZoomControls)
                        Padding(
                          padding: EdgeInsets.only(bottom: 26.h),
                          child: zoomControls,
                        ),
                      if (isLoading)
                        Positioned.fill(
                          child: CameraShimmerBox(
                            width: previewWidth,
                            height: previewHeight,
                            borderRadius: 16,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!isLoading && isVideoRecording)
                Positioned(top: 12.h, child: recordingIndicator),
              if (!isLoading && !isVideoRecording)
                IconButton(
                  onPressed: onToggleFlash,
                  icon: Icon(
                    isFlashOn ? EvaIcons.flash : EvaIcons.flashOff,
                    color: Colors.white,
                    size: 28.sp,
                  ),
                  padding: EdgeInsets.zero,
                ),
            ],
          );
        },
      ),
    );
  }
}
