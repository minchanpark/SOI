import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../../../api/services/camera_service.dart';
import '../../../utils/video_thumbnail_cache.dart';
import '../../about_camera/widgets/about_camera/camera_capture_button.dart';

class CommentCameraSheetResult {
  final String localFilePath;
  final bool isVideo;
  final int durationMs;

  const CommentCameraSheetResult({
    required this.localFilePath,
    required this.isVideo,
    required this.durationMs,
  });
}

enum _PendingVideoAction { none, stop, cancel }

class CommentCameraRecordingBottomSheetWidget extends StatefulWidget {
  const CommentCameraRecordingBottomSheetWidget({super.key});

  @override
  State<CommentCameraRecordingBottomSheetWidget> createState() =>
      _CommentCameraRecordingBottomSheetWidgetState();
}

class _CommentCameraRecordingBottomSheetWidgetState
    extends State<CommentCameraRecordingBottomSheetWidget> {
  static const double _sheetHeight = 320;
  static const double _previewMaxSize = 170;
  static const int _maxVideoDurationSeconds = 30;

  final CameraService _cameraService = CameraService.instance;
  final ValueNotifier<double> _videoProgress = ValueNotifier<double>(0.0);

  bool _isLoading = true;
  bool _isFlashOn = false;
  bool _isVideoRecording = false;
  bool _supportsLiveSwitch = false;
  bool _cameraSwitchInFlight = false;
  double _cameraSwitchTurns = 0.0;
  bool _videoStartInFlight = false;
  bool _videoStopInFlight = false;
  _PendingVideoAction _pendingVideoAction = _PendingVideoAction.none;

  String? _capturedPath;
  bool _capturedIsVideo = false;
  int _capturedDurationMs = 0;
  bool _showCapturedVideoPlayOverlay = true;
  bool _capturedVideoLoadFailed = false;
  VideoPlayerController? _capturedVideoController;
  Future<void>? _capturedVideoInitialization;

  DateTime? _recordingStartedAt;
  int _recordingDurationMs = 0;
  bool _confirmInFlight = false;

  Timer? _videoProgressTimer;
  StreamSubscription<String>? _videoRecordedSubscription;
  StreamSubscription<String>? _videoErrorSubscription;

  bool get _hasCapturedMedia => (_capturedPath ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    _setupVideoListeners();
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    _videoRecordedSubscription?.cancel();
    _videoErrorSubscription?.cancel();
    _stopVideoProgressTimer();
    if (_isVideoRecording || _videoStartInFlight) {
      unawaited(_cameraService.cancelVideoRecording());
    }
    _videoStartInFlight = false;
    _videoStopInFlight = false;
    _pendingVideoAction = _PendingVideoAction.none;
    _disposeCapturedVideoController();
    unawaited(_cameraService.pauseCamera());
    _videoProgress.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final hasPermission = await _ensureCameraPermission();
    if (!hasPermission) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    await _cameraService.activateSession();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _supportsLiveSwitch = _cameraService.supportsLiveSwitch;
    });
  }

  Future<bool> _ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }
    status = await Permission.camera.request();
    return status.isGranted;
  }

  void _setupVideoListeners() {
    _videoRecordedSubscription = _cameraService.onVideoRecorded.listen((path) {
      if (!mounted || path.isEmpty) {
        return;
      }
      _videoStartInFlight = false;
      _videoStopInFlight = false;
      _pendingVideoAction = _PendingVideoAction.none;
      _applyCapturedResult(
        path: path,
        isVideo: true,
        durationMs: _recordingDurationMs,
      );
    });

    _videoErrorSubscription = _cameraService.onVideoError.listen((message) {
      if (!mounted) {
        return;
      }
      _stopVideoProgressTimer();
      setState(() {
        _isVideoRecording = false;
      });
      _videoStartInFlight = false;
      _videoStopInFlight = false;
      _pendingVideoAction = _PendingVideoAction.none;
      _showSnackBar(message);
    });
  }

  void _applyCapturedResult({
    required String path,
    required bool isVideo,
    required int durationMs,
  }) {
    if (!mounted || path.isEmpty) {
      return;
    }

    _stopVideoProgressTimer();
    setState(() {
      _isVideoRecording = false;
      _capturedPath = path;
      _capturedIsVideo = isVideo;
      _capturedDurationMs = durationMs;
      _recordingDurationMs = 0;
      _recordingStartedAt = null;
      _showCapturedVideoPlayOverlay = true;
      _capturedVideoLoadFailed = false;
    });

    if (isVideo) {
      unawaited(_prepareCapturedVideoController(path));
    } else {
      _disposeCapturedVideoController();
    }
  }

  Future<void> _takePicture() async {
    if (_isLoading || _isVideoRecording || _hasCapturedMedia) {
      return;
    }

    final path = await _cameraService.takePicture();
    if (!mounted) {
      return;
    }

    if (path.isEmpty) {
      return;
    }

    _applyCapturedResult(path: path, isVideo: false, durationMs: 0);
  }

  Future<void> _startVideoRecording() async {
    if (_isLoading ||
        _isVideoRecording ||
        _videoStartInFlight ||
        _hasCapturedMedia) {
      return;
    }

    _videoStartInFlight = true;
    _recordingStartedAt = DateTime.now();
    _recordingDurationMs = 0;
    final started = await _cameraService.startVideoRecording();

    if (!mounted) {
      _videoStartInFlight = false;
      return;
    }

    _videoStartInFlight = false;
    if (!started) {
      _pendingVideoAction = _PendingVideoAction.none;
      _showSnackBar(tr('camera.video_record_start_failed'));
      return;
    }

    setState(() {
      _isVideoRecording = true;
    });
    _startVideoProgressTimer();

    if (_pendingVideoAction != _PendingVideoAction.none) {
      final nextAction = _pendingVideoAction;
      _pendingVideoAction = _PendingVideoAction.none;
      if (nextAction == _PendingVideoAction.stop) {
        await _stopVideoRecording();
      } else if (nextAction == _PendingVideoAction.cancel) {
        await _cancelVideoRecording();
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_videoStopInFlight) {
      return;
    }
    if (!_isVideoRecording) {
      if (_videoStartInFlight) {
        _pendingVideoAction = _PendingVideoAction.stop;
      }
      return;
    }

    _videoStopInFlight = true;
    final path = await _cameraService.stopVideoRecording();
    if (!mounted) {
      _videoStopInFlight = false;
      return;
    }
    _videoStopInFlight = false;

    if (path != null && path.isNotEmpty) {
      _applyCapturedResult(
        path: path,
        isVideo: true,
        durationMs: _recordingDurationMs,
      );
      return;
    }

    _stopVideoProgressTimer();
    setState(() {
      _isVideoRecording = false;
    });
    _pendingVideoAction = _PendingVideoAction.none;
  }

  Future<void> _cancelVideoRecording() async {
    if (_videoStopInFlight) {
      return;
    }
    if (!_isVideoRecording) {
      if (_videoStartInFlight) {
        _pendingVideoAction = _PendingVideoAction.cancel;
      }
      return;
    }

    _videoStopInFlight = true;
    await _cameraService.cancelVideoRecording();
    if (!mounted) {
      _videoStopInFlight = false;
      return;
    }
    _videoStopInFlight = false;
    _stopVideoProgressTimer();
    setState(() {
      _isVideoRecording = false;
    });
    _pendingVideoAction = _PendingVideoAction.none;
  }

  void _startVideoProgressTimer() {
    _videoProgress.value = 0.0;
    _videoProgressTimer?.cancel();
    _videoProgressTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted || !_isVideoRecording) {
        timer.cancel();
        return;
      }

      final startedAt = _recordingStartedAt;
      if (startedAt != null) {
        setState(() {
          _recordingDurationMs = DateTime.now()
              .difference(startedAt)
              .inMilliseconds;
        });
      }

      final next = _videoProgress.value + (0.1 / _maxVideoDurationSeconds);
      if (next >= 1.0) {
        _videoProgress.value = 1.0;
        timer.cancel();
        unawaited(_stopVideoRecording());
        return;
      }
      _videoProgress.value = next;
    });
  }

  void _stopVideoProgressTimer() {
    _videoProgressTimer?.cancel();
    _videoProgressTimer = null;
    _videoProgress.value = 0.0;
  }

  Future<void> _toggleFlash() async {
    if (_isLoading) {
      return;
    }
    final newFlashState = !_isFlashOn;
    await _cameraService.setFlash(newFlashState);
    if (!mounted) {
      return;
    }
    setState(() {
      _isFlashOn = newFlashState;
    });
  }

  Future<void> _onSwitchCameraPressed() async {
    if (_cameraSwitchInFlight || _isLoading || _videoStartInFlight) {
      return;
    }
    if (_isVideoRecording && !_supportsLiveSwitch) {
      _showSnackBar(tr('camera.switch_not_supported_while_recording'));
      return;
    }

    setState(() {
      _cameraSwitchInFlight = true;
      _cameraSwitchTurns += 1;
    });

    try {
      await _cameraService.switchCamera();
    } finally {
      if (mounted) {
        setState(() {
          _cameraSwitchInFlight = false;
        });
      }
    }
  }

  void _resetCapturedState() {
    _disposeCapturedVideoController();
    if (!mounted) {
      return;
    }
    setState(() {
      _capturedPath = null;
      _capturedIsVideo = false;
      _capturedDurationMs = 0;
      _showCapturedVideoPlayOverlay = true;
      _capturedVideoLoadFailed = false;
    });
  }

  Future<void> _closeSheet() async {
    if (_isVideoRecording ||
        _videoStartInFlight ||
        _pendingVideoAction != _PendingVideoAction.none) {
      await _cancelVideoRecording();
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmCaptured() async {
    if (_confirmInFlight) {
      return;
    }
    final path = _capturedPath;
    if (path == null || path.isEmpty) {
      return;
    }

    _confirmInFlight = true;
    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(
      CommentCameraSheetResult(
        localFilePath: path,
        isVideo: _capturedIsVideo,
        durationMs: _capturedIsVideo ? _capturedDurationMs : 0,
      ),
    );
  }

  void _disposeCapturedVideoController() {
    _capturedVideoController?.pause();
    _capturedVideoController?.dispose();
    _capturedVideoController = null;
    _capturedVideoInitialization = null;
  }

  Future<void> _prepareCapturedVideoController(String path) async {
    _disposeCapturedVideoController();

    final file = File(path);
    if (!await file.exists()) {
      if (!mounted) return;
      setState(() {
        _capturedVideoLoadFailed = true;
      });
      return;
    }

    final controller = VideoPlayerController.file(file);
    _capturedVideoController = controller;
    _capturedVideoInitialization = controller
        .initialize()
        .then((_) async {
          await controller.setLooping(true);
          await controller.setVolume(1.0); // 영상의 음량을 최대치로 설정
          if (!mounted) return;
          setState(() {
            _capturedVideoLoadFailed = false;
            _showCapturedVideoPlayOverlay = true;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() {
            _capturedVideoLoadFailed = true;
          });
        });

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleCapturedVideoPlayback() async {
    final controller = _capturedVideoController;
    final initialization = _capturedVideoInitialization;
    if (controller == null || initialization == null) {
      return;
    }

    try {
      if (!controller.value.isInitialized) {
        await initialization;
      }
      if (!mounted || !controller.value.isInitialized) {
        return;
      }

      if (controller.value.isPlaying) {
        await controller.pause();
        if (!mounted) return;
        setState(() {
          _showCapturedVideoPlayOverlay = true;
        });
      } else {
        await controller.play();
        if (!mounted) return;
        setState(() {
          _showCapturedVideoPlayOverlay = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _capturedVideoLoadFailed = true;
      });
    }
  }

  Widget _buildTopBar() {
    if (_hasCapturedMedia) {
      return Row(
        children: [
          IconButton(
            onPressed: _resetCapturedState,
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          ),
          const Spacer(),
          TextButton(
            onPressed: _confirmCaptured,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            ),
            child: Text(
              tr('common.confirm'),
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        IconButton(
          onPressed: _closeSheet,
          icon: const Icon(Icons.close, color: Color(0xFF8A8A8A), size: 28),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildCircularPreview() {
    final path = _capturedPath;
    if (_isLoading) {
      return _buildPreviewShell(
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (path != null && path.isNotEmpty) {
      if (_capturedIsVideo) {
        return _buildPreviewShell(child: _buildVideoPreview(path));
      }
      return _buildPreviewShell(child: _buildImagePreview(path));
    }

    return _buildPreviewShell(
      child: ClipOval(
        child: SizedBox.expand(child: _cameraService.buildCameraView()),
      ),
    );
  }

  Widget _buildPreviewShell({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF505050),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildImagePreview(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return const Center(
        child: Icon(Icons.image_not_supported, color: Colors.white70, size: 34),
      );
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return const Center(
          child: Icon(Icons.broken_image, color: Colors.white70, size: 34),
        );
      },
    );
  }

  Widget _buildVideoPreview(String path) {
    final controller = _capturedVideoController;
    final initialization = _capturedVideoInitialization;
    final canUsePlayer =
        !_capturedVideoLoadFailed &&
        controller != null &&
        initialization != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleCapturedVideoPlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (canUsePlayer)
            FutureBuilder<void>(
              future: initialization,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done ||
                    !controller.value.isInitialized) {
                  return _buildVideoThumbnailFallback(path);
                }

                final width = controller.value.size.width;
                final height = controller.value.size.height;
                if (width <= 0 || height <= 0) {
                  return _buildVideoThumbnailFallback(path);
                }

                return FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: VideoPlayer(controller),
                  ),
                );
              },
            )
          else
            _buildVideoThumbnailFallback(path),
          if (_showCapturedVideoPlayOverlay)
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 42,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoThumbnailFallback(String path) {
    return FutureBuilder<Uint8List?>(
      future: VideoThumbnailCache.getThumbnail(videoUrl: path, cacheKey: path),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(bytes, fit: BoxFit.cover);
        }
        return const ColoredBox(color: Color(0xFF5A5A5A));
      },
    );
  }

  Widget _buildDurationLabel() {
    if (_isVideoRecording) {
      return Text(
        _formatDuration(Duration(milliseconds: _recordingDurationMs)),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w400,
        ),
      );
    }

    if (_hasCapturedMedia && _capturedIsVideo) {
      return Text(
        _formatDuration(Duration(milliseconds: _capturedDurationMs)),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w400,
        ),
      );
    }

    return const SizedBox(height: 20);
  }

  Widget _buildControls() {
    if (_hasCapturedMedia) {
      return const SizedBox(height: 56);
    }

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: IconButton(
            onPressed: _toggleFlash,
            icon: Icon(
              _isFlashOn ? EvaIcons.flash : EvaIcons.flashOff,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        Expanded(
          child: CameraCaptureButton(
            isVideoRecording: _isVideoRecording,
            videoProgress: _videoProgress,
            onTakePicture: _takePicture,
            onStartVideoRecording: _startVideoRecording,
            onStopVideoRecording: _stopVideoRecording,
          ),
        ),
        SizedBox(
          width: 70,
          child: IconButton(
            onPressed:
                (_isVideoRecording && !_supportsLiveSwitch) ||
                    _cameraSwitchInFlight
                ? null
                : _onSwitchCameraPressed,
            icon: AnimatedRotation(
              turns: _cameraSwitchTurns,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              child: Image.asset('assets/switch.png', width: 32, height: 32),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF5A5A5A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: _sheetHeight,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xFF1F1F1F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 8),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _previewMaxSize,
                              maxHeight: _previewMaxSize,
                            ),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: _buildCircularPreview(),
                            ),
                          ),
                        ),
                      ),
                      _buildDurationLabel(),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 65,
                        child: Align(
                          alignment: Alignment.center,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 56,
                              maxHeight: 65,
                            ),
                            child: _buildControls(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
