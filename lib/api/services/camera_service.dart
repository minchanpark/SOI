import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

// 네이티브 카메라 & 오디오 서비스
// Android CameraX와 MediaRecorder를 Flutter MethodChannel로 연동
class CameraService {
  static const MethodChannel _cameraChannel = MethodChannel('com.soi.camera');
  static const Duration _defaultVideoMaxDuration = Duration(seconds: 30);

  CameraService._internal() {
    _cameraChannel.setMethodCallHandler(_handleNativeMethodCall);
  }

  static final CameraService instance = CameraService._internal();
  static bool debugTimings = false; // 성능 타이밍 디버그 플래그

  // 카메라 세션 상태 추적
  bool _isSessionActive = false;
  bool get isSessionActive => _isSessionActive;

  // 현재 카메라 타입 추적 (전면/후면)
  bool _isFrontCamera = false;
  bool get isFrontCamera => _isFrontCamera;

  bool _supportsLiveSwitch = false;
  bool _capabilitiesLoaded = false;
  bool get supportsLiveSwitch => _supportsLiveSwitch;

  // 사용 가능한 줌 레벨 캐시
  List<double> _availableZoomLevels = [1.0];
  List<double> get availableZoomLevels => _availableZoomLevels;

  // 추가: 드래그(연속) 줌을 위해 네이티브가 지원하는 min/max 줌 범위를 캐시합니다.
  // Android에서 미구현이면 availableZoomLevels 기반으로 fallback 합니다.
  double _minZoomFactor = 1.0;
  double _maxZoomFactor = 1.0;
  bool _zoomRangeLoaded = false;

  double get minZoomFactor => _minZoomFactor;
  double get maxZoomFactor => _maxZoomFactor;
  bool get hasZoomRange => _zoomRangeLoaded && _maxZoomFactor > _minZoomFactor;

  // 갤러리 미리보기 상태 관리
  String? _latestGalleryImagePath;
  bool _isLoadingGalleryImage = false;

  // 갤러리 첫 이미지 캐싱 (O(1) 최적화)
  AssetEntity? _cachedFirstGalleryImage;
  DateTime? _firstGalleryImageCacheTime;
  static const Duration _galleryCacheDuration = Duration(seconds: 5);

  // 권한 상태 캐싱
  PermissionState? _cachedPermissionState;
  DateTime? _permissionCacheTime;
  static const Duration _permissionCacheDuration = Duration(seconds: 10);

  // 오디오 녹음 상태 관리
  final bool _isRecording = false;
  String? _currentRecordingPath;

  // 비디오 녹화 상태 관리
  bool _isVideoRecording = false;

  // 녹화된 비디오 경로 및 이벤트 스트림
  String? _currentVideoPath;
  final StreamController<String> _videoRecordedController =
      StreamController<String>.broadcast();
  final StreamController<String> _videoErrorController =
      StreamController<String>.broadcast();

  // Getters
  String? get latestGalleryImagePath => _latestGalleryImagePath;
  bool get isLoadingGalleryImage => _isLoadingGalleryImage;
  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;
  bool get isVideoRecording => _isVideoRecording;
  String? get currentVideoPath => _currentVideoPath;
  Stream<String> get onVideoRecorded => _videoRecordedController.stream;
  Stream<String> get onVideoError => _videoErrorController.stream;

  /// 카메라 세션 준비 (권한 확인 포함)
  Future<void> prepareSessionIfPermitted() async {
    final status = await Permission.camera.status; // 카메라 권한 상태 확인
    if (!status.isGranted) {
      return;
    }

    try {
      // 네이티브 메서드 호출로 카메라 세션 준비
      await _cameraChannel.invokeMethod('prepareCamera');
    } on PlatformException {
      return;
    }
  }

  /// 네이티브 메서드 호출 처리
  Future<void> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onVideoRecorded': // 비디오 녹화 완료 콜백
        final Map<dynamic, dynamic>? args =
            call.arguments as Map<dynamic, dynamic>?;
        final String? path = args?['path'] as String?;
        _isVideoRecording = false;
        if (path != null && path.isNotEmpty) {
          _currentVideoPath = path;
          if (!_videoRecordedController.isClosed) {
            _videoRecordedController.add(path);
          }
        }
        break;
      case 'onVideoError': // 비디오 녹화 오류 콜백
        final Map<dynamic, dynamic>? args =
            call.arguments as Map<dynamic, dynamic>?;
        final String message =
            (args?['message'] as String?) ?? 'Unknown video error';
        _isVideoRecording = false;
        _currentVideoPath = null;
        if (!_videoErrorController.isClosed) {
          _videoErrorController.add(message);
        }
        break;
    }
  }

  // ==================== 갤러리 및 파일 관리 ====================

  // 갤러리에서 이미지를 선택할 때 사용할 필터 옵션
  // 이 필터는 이미지 크기 제약을 무시하고 모든 이미지를 선택할 수 있도록 설정합니다.
  final PMFilter filter = FilterOptionGroup(
    imageOption: const FilterOption(
      sizeConstraint: SizeConstraint(ignoreSize: true),
    ),
  );

  // 갤러리 미리보기 이미지 로드 (Service 로직)
  // 최신 갤러리 이미지를 캐시하여 성능 향상
  Future<void> loadLatestGalleryImage() async {
    // 이미 로딩 중이면 중복 실행 방지
    if (_isLoadingGalleryImage) {
      return;
    }

    _isLoadingGalleryImage = true;

    try {
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        onlyAll: true,
        filterOption: filter,
      );

      if (paths.isNotEmpty) {
        final List<AssetEntity> assets = await paths.first.getAssetListPaged(
          page: 0,
          size: 1,
        );

        if (assets.isNotEmpty) {
          // 실제 파일 경로를 캐시에 저장
          final File? file = await assets.first.file;
          _latestGalleryImagePath = file?.path;
        } else {
          _latestGalleryImagePath = null;
        }
      } else {
        _latestGalleryImagePath = null;
      }
    } catch (e) {
      _latestGalleryImagePath = null;
    } finally {
      _isLoadingGalleryImage = false;
    }
  }

  // 갤러리 미리보기 캐시 새로고침 (사진 촬영 후 호출)
  Future<void> refreshGalleryPreview() async {
    await loadLatestGalleryImage();
  }

  // O(1) 최적화된 갤러리 첫 번째 이미지 로딩 (캐싱 적용)
  Future<AssetEntity?> getFirstGalleryImage() async {
    try {
      // 캐시 유효성 체크 - O(1) 반환
      if (_cachedFirstGalleryImage != null &&
          _firstGalleryImageCacheTime != null &&
          DateTime.now().difference(_firstGalleryImageCacheTime!) <
              _galleryCacheDuration) {
        return _cachedFirstGalleryImage;
      }

      // 1. 갤러리 접근 권한 체크 (캐싱 적용)

      // 권한상태를 저장하는 변수
      PermissionState permissionState;

      // 권한 캐시 확인
      // _cachedPermissionState != null: 이전에 권한 허용이 되어있는 지 확인. 권한 허용 캐시를 체크
      // _permissionCacheTime != null: 캐시된 시간이 있는지 확인
      // DateTime.now().difference(...) < _permissionCacheDuration: 캐시된 시간이 유효한지 확인
      // _cachedPermissionState!.hasAccess: 캐시된 권한 상태가 실제로 접근 권한이 있는지 확인
      if (_cachedPermissionState != null &&
          _permissionCacheTime != null &&
          DateTime.now().difference(_permissionCacheTime!) <
              _permissionCacheDuration &&
          _cachedPermissionState!.hasAccess) {
        // 권한 캐시 히트 - O(1)
        // 이미 권한이 허용된 상태이므로 바로 사용가능
        permissionState = _cachedPermissionState!;
      } else {
        // 권한 캐시 미스 - 네이티브 호출
        // 권한 요청 시 네이티브 호출이 발생하므로 캐싱 무효화 가능성 있음
        permissionState = await PhotoManager.requestPermissionExtend();

        // 권한이 있을 때만 캐싱 (거부 상태는 사용자가 변경할 수 있으므로 캐싱 안 함)
        // 갤러리 권한을 가지고 있으면, 캐시를 갱신한다.
        if (permissionState.hasAccess) {
          _cachedPermissionState = permissionState;
          _permissionCacheTime = DateTime.now();
        }
      }

      if (!permissionState.hasAccess) {
        return null;
      }

      // 2. 갤러리 경로 가져오기 (이미지만 조회)
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        onlyAll: true,

        // 이미지만 조회하여 필터링 오버헤드 제거
        type: RequestType.image,
      );

      if (paths.isEmpty) {
        return null;
      }

      // 3. 첫 번째 경로에서 첫 번째 이미지 가져오기
      final List<AssetEntity> assets = await paths.first.getAssetListPaged(
        page: 0,
        size: 1,
      );

      if (assets.isEmpty) {
        return null;
      }

      // 결과 캐싱
      _cachedFirstGalleryImage = assets.first;
      _firstGalleryImageCacheTime = DateTime.now();

      return assets.first;
    } catch (e) {
      return null;
    }
  }

  // 갤러리 캐시 무효화 (새 사진/비디오 촬영 시 호출)
  void _invalidateGalleryCache() {
    _cachedFirstGalleryImage = null;
    _firstGalleryImageCacheTime = null;
  }

  // AssetEntity를 File로 변환
  Future<File?> assetToFile(AssetEntity asset) async {
    try {
      final File? file = await asset.file;
      return file;
    } catch (e) {
      return null;
    }
  }

  Widget buildCameraView() {
    // 플랫폼에 따라 다른 카메라 프리뷰 위젯 생성
    if (Platform.isAndroid) {
      return AndroidView(
        viewType: 'com.soi.camera',
        creationParams: <String, dynamic>{
          'useSRGBColorSpace': true,
          // 첫 프레임은 경량으로 시작하고 최적화 단계에서 품질 향상
          'useHighQuality': false,
          'resumeExistingSession': true,
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (Platform.isIOS) {
      return UiKitView(
        viewType: 'com.soi.camera/preview',
        creationParams: <String, dynamic>{
          'useSRGBColorSpace': true,
          // 첫 프레임은 경량으로 시작하고 최적화 단계에서 품질 향상
          'useHighQuality': false,
          'resumeExistingSession': true,
        },
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return Center(
        child: Text('지원되지 않는 플랫폼입니다', style: TextStyle(color: Colors.white)),
      );
    }
  }

  // 개선된 세션 활성화 (SurfaceProvider 준비 대기)
  Future<void> activateSession() async {
    await _ensureCapabilitiesLoaded();
    try {
      // 안전한 세션 상태 확인
      bool needsReactivation = false;

      try {
        final result = await _cameraChannel.invokeMethod('isSessionActive');
        bool nativeSessionActive = result ?? false;
        // 네이티브 세션 상태와 서비스 상태 확인

        needsReactivation = !nativeSessionActive || !_isSessionActive;
      } catch (e) {
        if (e.toString().contains('unimplemented') ||
            e.toString().contains('MissingPluginException')) {
          needsReactivation = !_isSessionActive;
        } else {
          needsReactivation = true;
        }
      }

      // 재활성화가 필요한 경우에만 실행
      if (needsReactivation) {
        await _cameraChannel.invokeMethod('resumeCamera');
        _isSessionActive = true;
        unawaited(optimizeCamera()); // 카메라 최적화 함수를 비동기로 호출하여서 UI 스레드 차단 방지
      } else {
        _isSessionActive = true;
        unawaited(optimizeCamera()); // 카메라 최적화 함수를 비동기로 호출하여서 UI 스레드 차단 방지
      }
    } on PlatformException {
      _isSessionActive = false;

      // 오류 발생 시 세션 상태 강제 리셋
      await _forceResetSession();
    }
  }

  Future<void> _ensureCapabilitiesLoaded() async {
    if (_capabilitiesLoaded) {
      return;
    }

    try {
      final bool? supported = await _cameraChannel.invokeMethod<bool>(
        'supportsLiveSwitch',
      );
      _supportsLiveSwitch = supported ?? false;
    } catch (_) {
      _supportsLiveSwitch = false;
    } finally {
      _capabilitiesLoaded = true;
    }
  }

  // 세션 상태 강제 리셋 메서드 추가
  Future<void> _forceResetSession() async {
    try {
      _isSessionActive = false;

      // 네이티브 세션 완전 종료 후 재시작
      await _cameraChannel.invokeMethod('pauseCamera');
      await Future.delayed(Duration(milliseconds: 100));
      await _cameraChannel.invokeMethod('resumeCamera');

      _isSessionActive = true;
    } catch (e) {
      _isSessionActive = false;
    }
  }

  Future<void> deactivateSession() async {
    // 이미 비활성화된 세션은 다시 비활성화하지 않음
    if (!_isSessionActive) {
      return;
    }

    try {
      await _cameraChannel.invokeMethod('pauseCamera');
      _isSessionActive = false;
    } on PlatformException catch (e) {
      if (debugTimings) {
        debugPrint('deactivateSession failed: ${e.code}');
      }
    }
  }

  Future<void> pauseCamera() async {
    // 이미 비활성화된 세션은 다시 일시중지하지 않음
    if (!_isSessionActive) {
      return;
    }

    try {
      await _cameraChannel.invokeMethod('pauseCamera');
    } on PlatformException catch (e) {
      if (debugTimings) {
        debugPrint('pauseCamera failed: ${e.code}');
      }
    }
  }

  Future<void> resumeCamera() async {
    try {
      await _cameraChannel.invokeMethod('resumeCamera');
      _isSessionActive = true;
      unawaited(optimizeCamera()); // 카메라 최적화 함수를 비동기로 호출하여서 UI 스레드 차단 방지
    } on PlatformException {
      _isSessionActive = false;
    }
  }

  Future<void> optimizeCamera() async {
    try {
      // 기존 네이티브 구현에 optimizeCamera 메서드가 없을 수 있으므로
      // 안전하게 처리하거나 필요한 경우 네이티브에서 구현 필요
      await _cameraChannel.invokeMethod('optimizeCamera', {
        'autoFocus': true,
        'highQuality': true,
        'stabilization': true,
      });
    } on PlatformException catch (e) {
      // optimizeCamera 메서드가 구현되지 않은 경우 무시
      if (e.code == 'unimplemented') {
      } else {}
    }
  }

  Future<void> setFlash(bool isOn) async {
    try {
      await _cameraChannel.invokeMethod('setFlash', {'isOn': isOn});
    } on PlatformException catch (e) {
      debugPrint("플래시 설정 오류: ${e.message}");
    }
  }

  // 줌 배율 설정
  Future<void> setZoom(double zoomValue) async {
    try {
      await _cameraChannel.invokeMethod('setZoom', {'zoomValue': zoomValue});
    } on PlatformException {
      // debugPrint("줌 설정 오류: ${e.message}");
      rethrow; // 에러를 다시 던져서 UI에서 처리할 수 있도록 함
    }
  }

  // 사용 가능한 줌 레벨 가져오기
  Future<List<double>> getAvailableZoomLevels() async {
    try {
      final result = await _cameraChannel.invokeMethod(
        'getAvailableZoomLevels',
      );
      if (result is List) {
        _availableZoomLevels = result.cast<double>();
        return _availableZoomLevels;
      }
      return [1.0]; // 기본값
    } on PlatformException catch (e) {
      debugPrint("줌 레벨 가져오기 오류: ${e.message}");
      return [1.0]; // 오류 시 기본값
    }
  }

  // 추가: 디바이스가 지원하는 줌 범위(min/max)를 가져옵니다. (iOS 구현됨)
  Future<void> refreshZoomRange() async {
    try {
      final result = await _cameraChannel.invokeMethod('getZoomRange');
      if (result is Map) {
        final minZoom = (result['minZoom'] as num?)?.toDouble();
        final maxZoom = (result['maxZoom'] as num?)?.toDouble();
        if (minZoom != null && maxZoom != null && maxZoom >= minZoom) {
          _minZoomFactor = minZoom;
          _maxZoomFactor = maxZoom;
          _zoomRangeLoaded = true;
          return;
        }
      }
    } on PlatformException catch (e) {
      // 플랫폼에서 미구현이면 조용히 fallback
      if (debugTimings) {
        debugPrint('getZoomRange not available: ${e.code}');
      }
    } catch (e) {
      // 기타 예외도 fallback (앱 크래시 방지)
      if (debugTimings) {
        debugPrint('getZoomRange error: $e');
      }
    }

    // fallback: availableZoomLevels가 있으면 그 범위로 설정
    if (_availableZoomLevels.isNotEmpty) {
      final sorted = [..._availableZoomLevels]..sort();
      _minZoomFactor = sorted.first;
      _maxZoomFactor = sorted.last;
      _zoomRangeLoaded = true;
    }
  }

  Future<void> setBrightness(double value) async {
    try {
      await _cameraChannel.invokeMethod('setBrightness', {'value': value});
    } on PlatformException catch (e) {
      debugPrint("밝기 설정 오류: ${e.message}");
    }
  }

  // 개선된 카메라 초기화 (타이밍 이슈 해결)
  Future<bool> initCamera() async {
    try {
      bool result = false; // 초기화 결과 변수
      int retryCount = 0; // 재시도 횟수
      const maxRetries = 3; // 최대 재시도 횟수
      const retryDelay = Duration(
        milliseconds: 80,
      ); // 재시도 간격 --> 80ms 간격으로 재시도함

      while (!result && retryCount < maxRetries) {
        try {
          result = await _cameraChannel.invokeMethod('initCamera');
          if (result) {
            break;
          }
        } catch (e) {
          debugPrint('카메라 초기화 실패 (시도 ${retryCount + 1}/$maxRetries): $e');
        }

        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(retryDelay);
        }
      }

      _isSessionActive = result;

      // 카메라 초기화 성공 시 사용 가능한 줌 레벨 가져오기
      if (result) {
        await getAvailableZoomLevels();
        // 추가: 드래그 줌을 위해 min/max 줌 범위도 함께 준비
        await refreshZoomRange();
      }

      return result;
    } on PlatformException {
      _isSessionActive = false;
      return false;
    }
  }

  // 개선된 사진 촬영 (안정성 강화 + 전면 카메라 좌우반전은 네이티브에서 처리)
  Future<String> takePicture() async {
    final stopwatch = Stopwatch()..start();
    try {
      // 카메라가 초기화되지 않았으면 먼저 초기화
      if (!_isSessionActive) {
        final initialized = await initCamera();
        if (!initialized) {
          return '';
        }
      }

      final String result = await _cameraChannel.invokeMethod('takePicture');

      if (result.isNotEmpty) {
        // 캐시 무효화 (새 사진 추가됨)
        _invalidateGalleryCache();
        // 갤러리 미리보기 새로고침 (비동기)
        Future.microtask(() => refreshGalleryPreview());

        if (debugTimings) {
          debugPrint(
            'CameraService.takePicture total=${stopwatch.elapsedMilliseconds}ms',
          );
        }
        return result;
      }

      if (debugTimings) {
        debugPrint(
          'CameraService.takePicture empty total=${stopwatch.elapsedMilliseconds}ms',
        );
      }
      return result;
    } on PlatformException {
      if (debugTimings) {
        debugPrint(
          'CameraService.takePicture error total=${stopwatch.elapsedMilliseconds}ms',
        );
      }
      return '';
    }
  }

  // ==================== 비디오 녹화 ====================

  Future<bool> startVideoRecording({
    Duration maxDuration = _defaultVideoMaxDuration,
  }) async {
    if (_isVideoRecording) {
      return true;
    }

    _currentVideoPath = null;

    // 카메라가 초기화되지 않았으면 먼저 초기화
    if (!_isSessionActive) {
      final initialized = await initCamera();
      if (!initialized) {
        return false;
      }
    }

    try {
      // 비디오 녹화를 위한 네이티브 메서드 호출
      // 녹화 시작이 성공하면 true 반환
      final bool? started = await _cameraChannel.invokeMethod<bool>(
        'startVideoRecording',
        {'maxDurationMs': maxDuration.inMilliseconds},
      );

      if (started == true) {
        _isVideoRecording = true;
        return true;
      }
    } on PlatformException catch (e) {
      debugPrint("비디오 녹화 시작 실패: ${e.message}");
    }

    _isVideoRecording = false;
    return false;
  }

  // 비디오 녹화 중지
  Future<String?> stopVideoRecording() async {
    try {
      // 비디오 녹화 중지를 위한 네이티브 메서드 호출
      final String? path = await _cameraChannel.invokeMethod<String>(
        'stopVideoRecording',
      );
      _isVideoRecording = false;

      if (path != null && path.isNotEmpty) {
        // 캐시 무효화 (새 비디오 추가됨)
        _invalidateGalleryCache();
        _currentVideoPath = path;
        return path;
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint("비디오 녹화 중지 실패: ${e.message}");
      _isVideoRecording = false;
      return null;
    }
  }

  // 비디오 녹화 취소
  Future<bool> cancelVideoRecording() async {
    try {
      // 비디오 녹화 취소를 위한 네이티브 메서드 호출
      await _cameraChannel.invokeMethod<String>('cancelVideoRecording');
      _isVideoRecording = false;
      _currentVideoPath = null;
      return true;
    } on PlatformException catch (e) {
      debugPrint("비디오 녹화 취소 실패: ${e.message}");
      return false;
    }
  }

  // 개선된 카메라 전환 (안정성 강화 + 전면/후면 상태 추적)

  Future<void> switchCamera() async {
    try {
      await _ensureCapabilitiesLoaded();
      // 카메라가 초기화되지 않았으면 먼저 초기화
      if (!_isSessionActive) {
        final initialized = await initCamera();
        if (!initialized) {
          return;
        }
      }

      await _cameraChannel.invokeMethod('switchCamera');

      // 카메라 전환 후 상태 토글
      _isFrontCamera = !_isFrontCamera;
    } on PlatformException {
      return;
    }
  }

  Future<void> dispose() async {
    try {
      await _cameraChannel.invokeMethod('disposeCamera');
      // _cameraView = null;

      // 상태 리셋
      _isSessionActive = false;
      _isFrontCamera = false;
      _capabilitiesLoaded = false;
      _supportsLiveSwitch = false;
    } on PlatformException {
      // 에러가 나도 상태는 리셋
      _isSessionActive = false;
      _isFrontCamera = false;
      _capabilitiesLoaded = false;
      _supportsLiveSwitch = false;
    }
  }
}
