import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:video_player/video_player.dart';

// 이미지를 표시하는 위젯
// 로컬 이미지 경로나 Firebase Storage URL을 기반으로 이미지를 표시합니다.
class PhotoDisplayWidget extends StatefulWidget {
  // 로컬 파일 경로
  final String? filePath;

  // 다운로드 URL (Firebase Storage 등)
  final String? downloadUrl;
  final bool useLocalImage;
  final double width;
  final double height;

  // 미디어가 비디오인지 여부를 체크하는 플래그
  final bool isVideo;
  final Future<void> Function()? onCancel;
  final ImageProvider? initialImage;

  // 미디어가 카메라에서 촬영된 것인지 여부를 나타내는 플래그
  final bool isFromCamera;

  const PhotoDisplayWidget({
    super.key,
    this.filePath,
    this.downloadUrl,
    required this.useLocalImage,
    this.width = 354,
    this.height = 471,
    this.isVideo = false,
    this.onCancel,
    this.initialImage,
    this.isFromCamera = false,
  });

  @override
  State<PhotoDisplayWidget> createState() => _PhotoDisplayWidgetState();
}

class _PhotoDisplayWidgetState extends State<PhotoDisplayWidget> {
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoPlayerFuture;
  bool _isInitialized = false;
  bool _isMuted = false; // 음소거 상태 추가

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    // 중복 초기화 방지
    if (_isInitialized) {
      return;
    }

    // 비디오인 경우에만 VideoPlayerController 초기화
    if (widget.isVideo && widget.filePath != null) {
      _isInitialized = true;
      _videoController = VideoPlayerController.file(File(widget.filePath!));
      _initializeVideoPlayerFuture = _videoController!
          .initialize()
          .then((_) {
            // 초기화 완료 후 자동 재생 및 루프 설정
            _videoController!.setLooping(true);
            _videoController!.play();
            if (mounted) setState(() {});
          })
          .catchError((error) {
            debugPrint("비디오 초기화 에러: $error");
          });
    }
  }

  @override
  void dispose() {
    // 이미지 캐시에서 해당 이미지 제거
    try {
      if (widget.filePath != null) {
        PaintingBinding.instance.imageCache.evict(
          FileImage(File(widget.filePath!)),
        );
      }
      if (widget.downloadUrl != null) {
        PaintingBinding.instance.imageCache.evict(
          NetworkImage(widget.downloadUrl!),
        );
      }
    } catch (e) {
      // 캐시 제거 실패해도 계속 진행
      debugPrint('Error evicting image from cache: $e');
    }

    // 비디오 컨트롤러가 초기화된 경우에만 dispose
    _videoController?.dispose();
    super.dispose();
  }

  // 음소거 토글 메서드
  void _toggleMute() {
    if (_videoController != null) {
      setState(() {
        _isMuted = !_isMuted;
        _videoController!.setVolume(_isMuted ? 0.0 : 1.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),

        // 미디어 유형에 따라 이미지 또는 비디오 표시
        child: (widget.isVideo)
            ? _buildVideoPlayer()
            : _buildImageWidget(context),
      ),
    );
  }

  /// 이미지 위젯을 결정하는 메소드
  Widget _buildImageWidget(BuildContext context) {
    if (widget.initialImage != null) {
      return Stack(
        alignment: Alignment.topLeft,
        children: [
          Image(
            image: widget.initialImage!,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
          _buildCancelButton(),
        ],
      );
    }

    // 로컬 이미지를 우선적으로 사용
    if (widget.useLocalImage && widget.filePath != null) {
      return Stack(
        alignment: Alignment.topLeft,
        children: [
          Image.file(
            File(widget.filePath!),
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // 메모리 최적화: 이미지 캐시 크기 제한
            cacheWidth: (widget.width * 2).round(),

            // 사진을 제대로 가지고 오지 못한 경우, 에러 아이콘 표시
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Color(0xffc1c1c1), size: 50.sp),
                    SizedBox(height: 10.h),
                    Text(
                      'camera.photo_load_failed',
                      style: TextStyle(
                        color: Color(0xffc1c1c1),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Pretendard",
                      ),
                    ).tr(),
                  ],
                ),
              );
            },
          ),
          _buildCancelButton(),
        ],
      );
    }
    // 둘 다 없는 경우 에러 메시지 표시
    else {
      return Center(
        child: Text(
          "camera.photo_unavailable",
          style: TextStyle(color: Colors.white),
        ).tr(),
      );
    }
  }

  Widget _buildCancelButton() {
    return IconButton(
      onPressed: () async {
        await _handleCancel(doublePop: true);
      },
      icon: Icon(Icons.cancel, color: Color(0xff1c1b1f), size: 35.sp),
    );
  }

  Widget _buildVideoPlayer() {
    // 비디오 컨트롤러가 없으면 에러 표시
    if (_videoController == null || _initializeVideoPlayerFuture == null) {
      return Center(
        child: Text(
          "camera.video_unavailable",
          style: TextStyle(color: Colors.white),
        ).tr(),
      );
    }

    return Stack(
      alignment: Alignment.topLeft,
      children: [
        FutureBuilder(
          future: _initializeVideoPlayerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              debugPrint("isFromCamera: ${widget.isFromCamera}");
              return (widget.isFromCamera)
                  ? SizedBox(
                      width: widget.width,
                      height: widget.height,
                      child: FittedBox(
                        fit: BoxFit.fill,
                        child: SizedBox(
                          width: _videoController!.value.size.width,
                          height: _videoController!.value.size.height,
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                    )
                  : Center(
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    );
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
        // 취소 버튼
        Positioned(top: 0, left: 0, child: _buildCancelButton()),
        // 음소거 버튼 추가
        Positioned(
          bottom: 0,
          right: 2,
          child: IconButton(
            onPressed: _toggleMute,
            icon: SvgPicture.asset(
              _isMuted ? 'assets/sound_mute.svg' : 'assets/sound_on.svg',
              width: 24.sp,
              height: 24.sp,
              colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleCancel({required bool doublePop}) async {
    if (widget.onCancel != null) {
      await widget.onCancel!();
    }

    if (!mounted) return;

    final navigator = Navigator.of(context);
    navigator.pop();

    if (doublePop && navigator.canPop()) {
      navigator.pop();
    }
  }
}
