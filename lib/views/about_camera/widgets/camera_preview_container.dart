import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'camera_recording_indicator.dart';
import 'camera_shimmer_box.dart';

/// 카메라 프리뷰를 감싸는 컨테이너 위젯
/// 카메라 화면을 띄우는 위젯입니다.
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

    // 추가: Flutter(UI)에서 드래그로 줌을 조절할 수 있도록 콜백을 받습니다.
    this.onZoomDragStart, // 줌 드래그를 시작할 때 호출
    this.onZoomDragUpdate, // 줌 드래그 중에 호출
    this.onZoomDragEnd, // 줌 드래그가 끝났을 때 호출
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

  // 추가: 프리뷰 위에 GestureDetector 오버레이를 올려 세로 드래그로 줌을 제어합니다.
  final GestureDragStartCallback? onZoomDragStart;
  final GestureDragUpdateCallback? onZoomDragUpdate;
  final GestureDragEndCallback? onZoomDragEnd;
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
                  'camera.preview_start_failed',
                  style: TextStyle(color: Colors.white, fontSize: 18.sp),
                  textAlign: TextAlign.center,
                ).tr(),
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
                      // 카메라 프리뷰를 상위 위젯에서 전달받아 표시합니다.
                      cameraView,

                      // 추가: 플랫폼뷰(카메라 프리뷰) 위에 투명 레이어를 올려 Flutter가 드래그를 받을 수 있게 합니다.
                      if (onZoomDragStart != null ||
                          onZoomDragUpdate != null ||
                          onZoomDragEnd != null)
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onVerticalDragStart: onZoomDragStart,
                            onVerticalDragUpdate: onZoomDragUpdate,
                            onVerticalDragEnd: onZoomDragEnd,
                          ),
                        ),
                      /* if (showZoomControls)
                        Padding(
                          padding: EdgeInsets.only(bottom: 26.h),
                          child: zoomControls,
                        ),*/

                      // 로딩 중일 때 카메라 프리뷰 위에 Shimmer 효과 오버레이를 준다.
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
              /*  if (!isLoading && isVideoRecording)
                Positioned(top: 12.h, child: recordingIndicator),*/
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
