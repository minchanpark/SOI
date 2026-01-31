import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../../api/services/camera_service.dart';
import 'widgets/camera_app_bar.dart';
import 'widgets/camera_capture_button.dart';
import 'widgets/camera_preview_container.dart';
import 'widgets/camera_zoom_controls.dart';
import 'widgets/gallery_thumbnail.dart';
import 'photo_editor_screen.dart';

enum _PendingVideoAction { none, stop, cancel }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  // Swift와 통신할 플랫폼 채널
  final CameraService _cameraService = CameraService.instance;

  // 플래시 상태 추적
  bool isFlashOn = false;

  // 추가: 줌 레벨 관리
  // 기본 줌 레벨
  String currentZoom = '1x';
  double currentZoomValue = 1.0;

  // 주석 처리: Flutter(UI) 세로 드래그로 줌 조절 기능은 일단 비활성화합니다.
  // (현재는 iOS 네이티브 핀치 줌만 사용)

  // 동적 줌 레벨 (디바이스별로 결정됨)
  List<Map<String, dynamic>> zoomLevels = [
    {'label': '1x', 'value': 1.0}, // 기본값
  ];
  bool _zoomLevelsFetchInProgress = false;

  // 카메라 초기화 Future 추가
  Future<void>? _cameraInitialization;
  bool _isInitialized = false;

  // 카메라 로딩 중 상태
  bool _isLoading = true;

  // 갤러리 미리보기 상태 관리
  AssetEntity? _firstGalleryImage;
  bool _isLoadingGallery = false;
  String? _galleryError;

  // 비디오 녹화 상태 관리
  bool _isVideoRecording = false;
  bool _supportsLiveSwitch = false;

  // 비디오 녹화 후 처리
  StreamSubscription<String>? _videoRecordedSubscription;

  // 비디오 녹화 오류 처리
  StreamSubscription<String>? _videoErrorSubscription;

  // 비디오 녹화 중 상태 관리
  _PendingVideoAction _pendingVideoAction = _PendingVideoAction.none;

  // 비디오 녹화 중 상태 관리
  bool _videoStartInFlight = false;

  // 비디오 녹화 Progress 관리
  Timer? _videoProgressTimer;

  String? _videoPath;
  bool _isNavigatingToEditor = false;
  bool _cameraSwitchInFlight = false; // 카메라 전환 중 상태
  double _cameraSwitchTurns = 0; // 카메라 전환 애니메이션 회전 값

  // 0.0 ~ 1.0을 기준으로 두고, 30초로 나누어 증가시킴
  // ValueNotifier로 변경하여 Progress 업데이트 시 전체 위젯 리빌드 방지
  final ValueNotifier<double> _videoProgress = ValueNotifier<double>(0.0);

  // 최대 녹화 시간 --> 30초
  static const int _maxVideoDurationSeconds = 30;

  // IndexedStack에서 상태 유지
  @override
  bool get wantKeepAlive => true;

  // 개선: 지연 초기화로 성능 향상
  @override
  void initState() {
    super.initState();

    _setupVideoListeners();

    // 앱 라이프사이클 옵저버 등록
    WidgetsBinding.instance.addObserver(this);

    if (widget.isActive) {
      // iOS 플랫폼뷰가 붙기 전에 초기화를 시작하면 레이스가 발생할 수 있어
      // 첫 프레임 이후로 초기화 타이밍을 지연합니다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cameraInitialization ??= _initializeCameraAsync();
      });
    } else {
      // 비활성 상태에서는 세션만 준비
      unawaited(_cameraService.prepareSessionIfPermitted());
    }
  }

  @override
  void didUpdateWidget(covariant CameraScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isActive && widget.isActive) {
      if (_isInitialized) {
        // 초기화되면 카메라 세션 재개
        unawaited(_cameraService.resumeCamera());
      } else {
        // 아직 초기화되지 않은 경우 초기화 시작
        _cameraInitialization ??= _initializeCameraAsync();
      }
      return;
    }

    if (oldWidget.isActive && !widget.isActive) {
      unawaited(_cameraService.pauseCamera());
    }
  }

  /// 비동기 카메라 초기화
  Future<void> _initializeCameraAsync() async {
    if (_isInitialized || !mounted) {
      return;
    }

    try {
      // iOS에서 초기 진입 타이밍 레이스 방지 (플랫폼뷰 준비 대기)
      if (Platform.isIOS) {
        await Future.delayed(const Duration(milliseconds: 150));
      }
      // 앱 설정의 권한 상태만 확인하고, 리소스/세션 실패는 조용히 무시합니다.
      final cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
      final bool alreadyActive = _cameraService.isSessionActive;

      if (!alreadyActive) {
        // 세션만 우선 활성화하여 화면을 즉시 표시
        await _cameraService.activateSession();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isInitialized = true;
        _supportsLiveSwitch = _cameraService.supportsLiveSwitch;
      });

      // 갤러리 및 줌 레벨 로딩을 동시에 비동기 실행하여 O(1) 초기화 유지
      unawaited(
        Future.wait([_loadFirstGalleryImage(), _loadAvailableZoomLevels()]),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 디바이스별 사용 가능한 줌 레벨 로드
  Future<void> _loadAvailableZoomLevels() async {
    if (!mounted) {
      return;
    }

    final cachedLevels = _cameraService.availableZoomLevels;
    if (cachedLevels.isNotEmpty) {
      _applyZoomLevels(cachedLevels);
      // 이미 네이티브 값이 준비된 경우 즉시 종료
      if (cachedLevels.length > 1) {
        return;
      }
    }

    if (_zoomLevelsFetchInProgress) {
      return;
    }

    _zoomLevelsFetchInProgress = true;

    // 비동기로 네이티브 줌 레벨을 갱신해 UI 응답성을 유지
    unawaited(_refreshZoomLevels());
  }

  Future<void> _refreshZoomLevels() async {
    try {
      final availableLevels = await _cameraService.getAvailableZoomLevels();

      // 가져온 줌 레벨을 UI에 적용
      _applyZoomLevels(availableLevels);

      // 주석 처리: 드래그 줌 비활성화로 인해 min/max 줌 범위 갱신은 사용하지 않습니다.
    } catch (_) {
      // 줌 레벨 로드 실패 시 기본값 유지
    } finally {
      _zoomLevelsFetchInProgress = false;
    }
  }

  /// 줌 레벨을 UI에 적용
  void _applyZoomLevels(List<double> availableLevels) {
    if (!mounted) {
      return;
    }

    setState(() {
      zoomLevels = availableLevels.map((level) {
        if (level == 0.5) {
          return {'label': '.5x', 'value': level};
        } else if (level == 1.0) {
          return {'label': '1x', 'value': level};
        } else if (level == 2.0) {
          return {'label': '2x', 'value': level};
        } else if (level == 3.0) {
          return {'label': '3x', 'value': level};
        } else {
          return {'label': '${level.toStringAsFixed(1)}x', 'value': level};
        }
      }).toList();
    });
  }

  /// 비디오 녹화 이벤트 리스너 설정
  void _setupVideoListeners() {
    // 비디오 녹화 시에 처리
    _videoRecordedSubscription = _cameraService.onVideoRecorded.listen((
      String path,
    ) {
      if (!mounted) return;

      setState(() {
        _isVideoRecording = false;
      });
      _videoStartInFlight = false;
      _pendingVideoAction = _PendingVideoAction.none;

      if (path.isNotEmpty) {
        _videoPath = path;
        // 동영상 저장 후 처리
        Future.microtask(() => _cameraService.refreshGalleryPreview());

        _openVideoEditor(path);

        _showSnackBar(tr('camera.video_saved', context: context));
      }
    });

    // 비디오 녹화 오류시에 처리
    _videoErrorSubscription = _cameraService.onVideoError.listen((
      String message,
    ) {
      if (!mounted) return;

      setState(() {
        _isVideoRecording = false;
      });
      _videoStartInFlight = false;
      _pendingVideoAction = _PendingVideoAction.none;
      _showSnackBar(message, backgroundColor: const Color(0xFFD9534F));
    });
  }

  /// 개선된 갤러리 첫 번째 이미지 로딩
  Future<void> _loadFirstGalleryImage() async {
    // 비디오 녹화 중에는 갤러리 이미지 로드하지 않음
    if (_isLoadingGallery || _isVideoRecording) return;

    setState(() {
      _isLoadingGallery = true;
      _galleryError = null;
    });

    try {
      final AssetEntity? firstImage = await _cameraService
          .getFirstGalleryImage();

      if (mounted) {
        setState(() {
          _firstGalleryImage = firstImage;
          _isLoadingGallery = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _galleryError = tr('camera.gallery_access_failed', context: context);
          _isLoadingGallery = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // 앱 라이프사이클 옵저버 해제
    WidgetsBinding.instance.removeObserver(this);

    unawaited(_cameraService.pauseCamera());

    _videoRecordedSubscription?.cancel();
    _videoErrorSubscription?.cancel();

    // Progress 타이머 정리
    _videoProgressTimer?.cancel();
    _videoProgress.dispose();

    if (_isVideoRecording) {
      unawaited(_cameraService.cancelVideoRecording());
    }
    _videoStartInFlight = false;
    _pendingVideoAction = _PendingVideoAction.none;

    // (배포버전 프리즈 방지) 전역 imageCache.clear()는 캐시가 큰 실사용 환경에서
    // dispose 타이밍에 수 초 프리즈를 만들 수 있어 제거합니다.

    super.dispose();
  }

  /// 앱 라이프사이클 상태 변화 감지
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 활성화될 때 카메라 세션 복구
    if (state == AppLifecycleState.resumed) {
      if (_isInitialized && widget.isActive) {
        _cameraService.resumeCamera();

        // 갤러리 미리보기 새로고침 (다른 앱에서 사진을 찍었을 수 있음)
        _loadFirstGalleryImage();
      }
    }
    // 앱이 완전히 백그라운드로 갈 때만 비디오 녹화 중지
    // inactive는 일시적 상태이므로 무시 (알림 센터, 화면 전환 등)
    else if (state == AppLifecycleState.paused) {
      // paused: 앱이 완전히 백그라운드로 갔을 때만 녹화 중지
      if (_isVideoRecording ||
          _videoStartInFlight ||
          _pendingVideoAction != _PendingVideoAction.none) {
        unawaited(_stopVideoRecording(isCancelled: true));
      }
      _cameraService.pauseCamera();
    }
    // inactive 상태에서는 카메라만 일시 정지 (비디오 녹화는 유지)
    else if (state == AppLifecycleState.inactive) {
      // inactive: 일시적 비활성화 (알림, 전화 등)
      // 비디오 녹화는 중지하지 않고 카메라만 일시 정지
      if (!_isVideoRecording) {
        _cameraService.pauseCamera();
      }
    }
  }

  /// cameraservice에 플래시 토글 요청
  Future<void> _toggleFlash() async {
    try {
      final bool newFlashState = !isFlashOn;
      await _cameraService.setFlash(newFlashState);

      setState(() {
        isFlashOn = newFlashState;
      });
    } on PlatformException {
      // Flash toggle error occurred: ${e.message}
    }
  }

  /// cameraservice에 사진 촬영 요청
  Future<void> _takePicture() async {
    if (_isNavigatingToEditor) {
      return;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final String result = await _cameraService.takePicture();

      if (result.isEmpty || !mounted) {
        return;
      }
      final fileImage = FileImage(File(result));

      // 무거운 이미지 디코딩은 백그라운드에서 수행하여 UI 응답성 확보
      unawaited(precacheImage(fileImage, context).catchError((_) {}));

      _isNavigatingToEditor = true;

      // 즉시 편집 화면으로 이동 (갤러리 새로고침과 독립적)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PhotoEditorScreen(filePath: result, initialImage: fileImage),
        ),
      ).whenComplete(() {
        if (mounted) {
          setState(() {
            _isNavigatingToEditor = false;
          });
        } else {
          _isNavigatingToEditor = false;
        }
      });

      // 사진 촬영 후 갤러리 미리보기 새로고침 (백그라운드에서)
      Future.microtask(() => _loadFirstGalleryImage());
      debugPrint(
        'CameraScreen._takePicture end-to-end=${stopwatch.elapsedMilliseconds}ms',
      );
    } on PlatformException catch (e) {
      // iOS에서 "Cannot Record" 오류가 발생한 경우 추가 정보 제공
      if (e.message?.contains("Cannot Record") == true) {
        _showSnackBar(tr('camera.capture_error_stop_audio', context: context));
      }
    } catch (e) {
      // 추가 예외 처리
      rethrow;
    }
  }

  /// cameraservice에 비디오 녹화 시작 요청
  Future<void> _startVideoRecording() async {
    if (_isVideoRecording) {
      return;
    }

    _videoStartInFlight = true;
    final bool started = await _cameraService.startVideoRecording();
    if (!mounted) {
      _videoStartInFlight = false;
      return;
    }

    _videoStartInFlight = false;
    if (started) {
      setState(() {
        _isVideoRecording = true;
      });

      // Progress 타이머 시작
      _startVideoProgressTimer();

      if (_pendingVideoAction != _PendingVideoAction.none) {
        final nextAction = _pendingVideoAction;
        _pendingVideoAction = _PendingVideoAction.none;

        if (nextAction == _PendingVideoAction.stop) {
          await _stopVideoRecording();
        } else if (nextAction == _PendingVideoAction.cancel) {
          await _stopVideoRecording(isCancelled: true);
        }
      }
    } else {
      setState(() {
        _isVideoRecording = false;
      });
      _pendingVideoAction = _PendingVideoAction.none;
      _showSnackBar(
        tr('camera.video_record_start_failed', context: context),
        backgroundColor: const Color(0xFFD9534F),
      );
    }
  }

  /// cameraservice에 비디오 녹화 중지 요청
  Future<void> _stopVideoRecording({bool isCancelled = false}) async {
    if (!_isVideoRecording) {
      if (!_videoStartInFlight) {
        return;
      }
      _pendingVideoAction = isCancelled
          ? _PendingVideoAction.cancel
          : _PendingVideoAction.stop;
      return;
    }

    if (isCancelled) {
      await _cameraService.cancelVideoRecording();
      _videoPath = null;
    } else {
      _videoPath = await _cameraService.stopVideoRecording();
    }

    if (!mounted) return;
    setState(() {
      _isVideoRecording = false;
    });
    _pendingVideoAction = _PendingVideoAction.none;

    // Progress 타이머 중지
    _stopVideoProgressTimer();

    // 비디오 녹화 성공 시 편집 화면으로 이동
    if (!isCancelled &&
        _videoPath != null &&
        _videoPath!.isNotEmpty &&
        mounted) {
      _openVideoEditor(_videoPath!);
      // 갤러리 미리보기 새로고침
      Future.microtask(() => _loadFirstGalleryImage());
    }
  }

  void _openVideoEditor(String path) {
    if (!mounted || path.isEmpty || _isNavigatingToEditor) {
      return;
    }

    _isNavigatingToEditor = true;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoEditorScreen(
          filePath: path,
          isVideo: true,
          isFromCamera: true,
        ),
      ),
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isNavigatingToEditor = false;
        });
      } else {
        _isNavigatingToEditor = false;
      }
    });
  }

  /// 비디오 녹화 Progress 타이머 시작
  void _startVideoProgressTimer() {
    _videoProgress.value = 0.0;
    _videoProgressTimer?.cancel();

    _videoProgressTimer = Timer.periodic(
      const Duration(milliseconds: 100), // 0.1초마다 업데이트
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        // ValueNotifier 사용으로 전체 위젯 리빌드 방지
        _videoProgress.value += 0.1 / _maxVideoDurationSeconds;

        // 30초 도달 시 자동으로 녹화 중지
        if (_videoProgress.value >= 1.0) {
          _videoProgress.value = 1.0;
          _stopVideoProgressTimer();
        }
      },
    );
  }

  /// 비디오 녹화 Progress 타이머 중지
  void _stopVideoProgressTimer() {
    _videoProgressTimer?.cancel();
    _videoProgressTimer = null;
    _videoProgress.value = 0.0;
  }

  /// 스낵바 표시
  ///
  /// Parameters:
  ///   - [message]: 스낵바에 표시할 메시지
  ///   - [backgroundColor]: 스낵바 배경색 (기본값: 어두운 회색)
  ///   - [duration]: 스낵바 표시 시간 (기본값: 2초)
  void _showSnackBar(
    String message, {
    Color backgroundColor = const Color(0xFF5A5A5A),
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }

  /// cameraservice에 카메라 전환 요청
  Future<void> _switchCamera() async {
    if (_isVideoRecording && !_supportsLiveSwitch) {
      _showSnackBar(
        tr('camera.switch_not_supported_while_recording', context: context),
      );
      return;
    }

    try {
      await _cameraService.switchCamera();

      // 카메라 전환 후 줌 레벨 다시 로드 (전면/후면 카메라별 지원 줌이 다름)
      await _loadAvailableZoomLevels();

      // 현재 줌이 새 카메라에서 지원되지 않으면 1x로 리셋
      final supportedValues = zoomLevels
          .map((z) => z['value'] as double)
          .toList();
      if (!supportedValues.contains(currentZoomValue)) {
        setState(() {
          currentZoomValue = 1.0;
          currentZoom = '1x';
        });
      }
    } on PlatformException catch (e) {
      debugPrint('Camera switch error occurred: ${e.message}');
    }
  }

  /// 카메라 전환 버튼 눌렀을 때 처리
  Future<void> _onSwitchCameraPressed() async {
    // `!_cameraSwitchInFlight` 토글 방식은 상태가 꼬여 true로 고정될 수 있어
    // 이후 버튼이 비활성화(전환 불가)되는 원인이 됩니다.
    if (_cameraSwitchInFlight) return;

    setState(() {
      _cameraSwitchInFlight = true;
      _cameraSwitchTurns += 1;
    });

    try {
      await _switchCamera();
    } finally {
      if (mounted) {
        setState(() {
          _cameraSwitchInFlight = false;
        });
      }
    }
  }

  /// 줌 레벨 설정
  ///
  /// Parameters:
  ///   - [zoomValue]: 설정할 줌 값 (예: 1.0, 2.0 등)
  ///   - [zoomLabel]: 설정할 줌 레벨의 라벨 (예: '1x', '2x' 등)
  Future<void> _setZoomLevel(double zoomValue, String zoomLabel) async {
    try {
      await _cameraService.setZoom(zoomValue);
      setState(() {
        currentZoomValue = zoomValue;
        currentZoom = zoomLabel;
      });
    } on PlatformException catch (e) {
      final message = e.message;
      if (message == null || message.isEmpty) {
        _showSnackBar(tr('camera.zoom_set_error', context: context));
        return;
      }
      _showSnackBar(
        tr(
          'camera.zoom_set_error_with_reason',
          context: context,
          namedArgs: {'error': message},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final zoomControls = CameraZoomControls(
      zoomLevels: zoomLevels,
      currentZoomValue: currentZoomValue,
      onZoomSelected: (value, label) => _setZoomLevel(value, label),
    );

    return Scaffold(
      backgroundColor: Color(0xff000000),
      appBar: CameraAppBar(
        onContactsTap: () => Navigator.pushNamed(context, '/contact_manager'),
        onNotificationsTap: () =>
            Navigator.pushNamed(context, '/notifications'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 카메라 프리뷰를 띄우는 위젯 컨태이너
            CameraPreviewContainer(
              initialization: _cameraInitialization,
              isLoading: _isLoading,
              cameraView: _cameraService.buildCameraView(),
              showZoomControls: zoomLevels.isNotEmpty && !_isVideoRecording,
              zoomControls: zoomControls,
              isVideoRecording: _isVideoRecording,
              isFlashOn: isFlashOn,
              onToggleFlash: _toggleFlash,
              // 주석 처리: Flutter(UI) 드래그로 줌 조절 기능 비활성화 (두 손가락 핀치 줌만 사용)
            ),
            SizedBox(height: 20.h),
            // 수정: 하단 버튼 레이아웃 변경 - 반응형
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 갤러리 미리보기 버튼 (Service 상태 사용) - 반응형
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: InkWell(
                      onTap: () async {
                        try {
                          final stopwatch = Stopwatch()..start();
                          debugPrint('[GalleryPick] tap');
                          final permissionState =
                              await PhotoManager.requestPermissionExtend();
                          if (!permissionState.hasAccess) {
                            if (!context.mounted) {
                              return;
                            }
                            _showSnackBar(
                              tr(
                                'camera.gallery_access_failed',
                                context: context,
                              ),
                            );
                            return;
                          }
                          final List<AssetEntity>? pickedAssets =
                              await AssetPicker.pickAssets(
                                context,
                                pickerConfig: AssetPickerConfig(
                                  maxAssets: 1,
                                  requestType: RequestType.common,
                                  textDelegate:
                                      EnglishAssetPickerTextDelegate(),
                                ),
                              );
                          debugPrint(
                            '[GalleryPick] picker done: ${stopwatch.elapsedMilliseconds}ms',
                          );
                          // 수정: async gap 이후 context 사용(Navigator.push) 안전장치
                          if (pickedAssets == null ||
                              pickedAssets.isEmpty ||
                              !context.mounted) {
                            debugPrint('[GalleryPick] cancelled or unmounted');
                            return;
                          }

                          final AssetEntity pickedAsset = pickedAssets.first;
                          final bool isVideo =
                              pickedAsset.type == AssetType.video;

                          debugPrint(
                            '[GalleryPick] push editor (isVideo=$isVideo) at ${stopwatch.elapsedMilliseconds}ms',
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PhotoEditorScreen(
                                asset: pickedAsset,
                                isVideo: isVideo,
                                isFromCamera: false,
                              ),
                            ),
                          );
                        } catch (e) {
                          _showSnackBar(
                            tr('camera.gallery_pick_failed', context: context),
                          );
                        }
                      },
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.76),
                        ),
                        // 갤러리 썸네일을 위젯 형태로 표시
                        child: GalleryThumbnail(
                          isLoading: _isLoadingGallery,
                          asset: _firstGalleryImage,
                          errorMessage: _galleryError,
                          size: 46,
                          borderRadius: 8.76,
                        ),
                      ),
                    ),
                  ),
                ),

                // 촬영 버튼 위젯 - 반응형
                CameraCaptureButton(
                  isVideoRecording: _isVideoRecording,
                  videoProgress: _videoProgress,
                  onTakePicture: _takePicture,
                  onStartVideoRecording: _startVideoRecording,
                  onStopVideoRecording: _stopVideoRecording,
                ),

                // 카메라 전환 버튼 - 개선된 반응형
                Expanded(
                  child: IconButton(
                    onPressed:
                        (_isVideoRecording && !_supportsLiveSwitch) ||
                            _cameraSwitchInFlight
                        ? null
                        : _onSwitchCameraPressed,
                    color: Color(0xffd9d9d9),
                    icon: AnimatedRotation(
                      turns: _cameraSwitchTurns,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOut,
                      child: Image.asset(
                        "assets/switch.png",
                        width: 67.w,
                        height: 56.h,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 30.h),
          ],
        ),
      ),
    );
  }
}
