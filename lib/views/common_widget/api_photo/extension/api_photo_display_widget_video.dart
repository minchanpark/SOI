part of '../api_photo_display_widget.dart';

/// 비디오 관련 확장 메서드
/// 비디오 컨트롤러 초기화, 재생/일시정지, 해제 등을 담당합니다.
/// 비디오가 아닌 경우에는 컨트롤러를 해제하여 리소스를 정리합니다.
extension _ApiPhotoDisplayWidgetVideoExtension on _ApiPhotoDisplayWidgetState {
  /// 비디오 컨트롤러 초기화 및 갱신
  ///
  /// Parameters:
  ///   - [forceRecreate]: 강제로 컨트롤러를 재생성할지 여부
  void _ensureVideoController({bool forceRecreate = false}) {
    // 비디오가 아닌 경우
    if (!widget.post.isVideo) {
      // 기존 비디오 컨트롤러 해제
      _disposeVideoController();
      return;
    }

    // 비디오 URL 가져오기
    final url = postImageUrl;
    if (url == null || url.isEmpty) return;

    // 현재 비디오 컨트롤러의 데이터 소스 가져오기
    final currentUrl = _videoController?.dataSource;

    // 같은 URL이고 강제 재생성이 아닌 경우 리턴
    if (!forceRecreate && _videoController != null && currentUrl == url) {
      return;
    }

    // 기존 비디오 컨트롤러 해제
    _disposeVideoController();

    // 새로운 비디오 컨트롤러 생성
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));

    // 새로운 비디오 컨트롤러 설정 및 초기화
    _videoController = controller;

    // 비디오 초기화 Future 설정
    _videoInitialization = controller.initialize().then((_) async {
      // video 초기화 완료 후 반복 재생 설정
      await controller.setLooping(true);
      // 비디오가 보이는 상태라면 재생 시작
      if (_isVideoVisible) {
        await controller.play();
      }
      // 상태 업데이트
      _safeSetState(() {});
    });
  }

  /// 비디오 컨트롤러 해제
  /// 비디오 컨트롤러를 해제하고 관련 리소스를 정리합니다.
  void _disposeVideoController() {
    _videoController?.dispose();
    _videoController = null;
    _videoInitialization = null;
  }

  /// 비디오 일시정지
  void _pauseVideo() {
    final controller = _videoController;
    if (controller == null) return;
    if (!controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    }
  }

  /// 비디오 재생
  void _playVideoIfReady() {
    final controller = _videoController;
    if (controller == null) return;
    if (!controller.value.isInitialized) return;
    if (!controller.value.isPlaying) {
      controller.play();
    }
  }
}
