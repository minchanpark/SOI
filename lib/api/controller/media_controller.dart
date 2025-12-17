import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;

import '../services/media_service.dart';

/// 미디어 컨트롤러
///
/// 미디어 업로드 관련 UI 상태 관리 및 비즈니스 로직을 담당합니다.
/// MediaService를 내부적으로 사용하며, API 변경 시 Service만 수정하면 됩니다.
///
/// 사용 예시:
/// ```dart
/// final controller = Provider.of<MediaController>(context, listen: false);
///
/// // Presigned URL 발급
/// final urls = await controller.getPresignedUrls(['image1.jpg']);
///
/// // 이미지 업로드
/// final key = await controller.uploadPostImage(
///   file: imageFile,
///   userId: 1,
///   refId: 1,
/// );
/// ```
class MediaController extends ChangeNotifier {
  final MediaService _mediaService;

  bool _isLoading = false;
  String? _errorMessage;
  double? _uploadProgress;

  // 추가: presigned URL은 1시간 유효하지만, 매번 새로 발급받으면 URL이 바뀌어
  // 이미지 캐시(CachedNetworkImage)가 새 이미지로 인식 → placeholder(쉬머)가 다시 보일 수 있습니다.
  // 그래서 key -> presignedUrl을 메모리에 캐시해서, 이미 본 이미지는 즉시 렌더링되도록 합니다.
  final Map<String, _PresignedUrlCacheEntry> _presignedUrlCache = {};
  final Map<String, Future<String?>> _inFlightPresignRequests = {};

  /// 생성자
  ///
  /// [mediaService]를 주입받아 사용합니다. 테스트 시 MockMediaService를 주입할 수 있습니다.
  MediaController({MediaService? mediaService})
    : _mediaService = mediaService ?? MediaService();

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  /// 업로드 진행률 (0.0 ~ 1.0)
  double? get uploadProgress => _uploadProgress;

  // ============================================
  // Presigned URL
  // ============================================

  /// 여러 개의 presigned URL 발급
  ///
  /// Parameters:
  /// - [keys]: 미디어 키 목록
  ///
  /// Returns: presigned URL 목록 (List of String)
  /// - 발급 실패 시 빈 목록 반환
  Future<List<String>> getPresignedUrls(List<String> keys) async {
    _setLoading(true);
    _clearError();

    try {
      final urls = await _mediaService.getPresignedUrls(
        keys,
      ); // API 호출하여서 presigned URL 요청
      _setLoading(false);

      // 응답이 요청 key 순서와 동일하다는 전제 하에 캐시 채우기(길이 일치할 때만)
      if (urls.length == keys.length) {
        final now = DateTime.now();
        for (var i = 0; i < keys.length; i++) {
          // 캐시 저장 (55분 후 만료)
          _presignedUrlCache[keys[i]] = _PresignedUrlCacheEntry(
            url: urls[i],
            expiresAt: now.add(const Duration(minutes: 55)),
          );
        }
      }

      return urls;
    } catch (e) {
      _setError('URL 발급 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  /// 캐시에 있는 presigned URL을 즉시 반환 (없거나 만료면 null)
  ///
  /// Parameters:
  /// - [key]: 미디어 키
  ///
  /// Returns:
  /// - success: presigned URL (캐시에 있고 만료되지 않은 경우)
  /// - fail: null (캐시에 없거나 만료된 경우)
  String? peekPresignedUrl(String key) {
    final entry = _presignedUrlCache[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _presignedUrlCache.remove(key);
      return null;
    }
    return entry.url;
  }

  Future<String?> getPresignedUrl(String key) async {
    // 캐시 hit면 네트워크 없이 즉시 반환
    final cached = peekPresignedUrl(key); // 캐시를 확인하여서 바로 반환
    if (cached != null) return cached;

    // 같은 key에 대한 동시 요청은 1번만 보내고 공유합니다.
    final inflight = _inFlightPresignRequests[key];
    if (inflight != null) return inflight;

    _setLoading(true);
    _clearError();

    // 네트워크 요청 --> 캐시가 miss된 경우에만 호출됩니다.
    try {
      final future = _mediaService.getPresignedUrl(
        key,
      ); // API 호출하여서 presigned URL 요청
      _inFlightPresignRequests[key] = future; // 진행 중인 요청으로 등록
      final url = await future; // 결과 대기

      if (url != null) {
        // MediaService 주석 기준 1시간 유효 → 55분만 캐싱(여유)
        _presignedUrlCache[key] = _PresignedUrlCacheEntry(
          url: url,
          expiresAt: DateTime.now().add(const Duration(minutes: 55)),
        );
      }

      _setLoading(false);
      return url;
    } catch (e) {
      _setError('URL 발급 실패: $e');
      _setLoading(false);
      return null;
    } finally {
      _inFlightPresignRequests.remove(key);
    }
  }

  // ============================================
  // 미디어 업로드
  // ============================================

  /// 미디어 파일 업로드
  ///
  /// Parameters:
  /// - [files]: 업로드할 파일 목록 (MultipartFile 형식)
  /// - [types]: 각 파일의 미디어 타입 목록 (MediaType 형식)
  /// - [usageTypes]: 각 파일의 사용 용도 목록 (MediaUsageType 형식)
  /// - [userId]: 업로드하는 사용자 ID
  /// - [refId]: 참조 ID (예: 게시물 ID)
  /// - [usageCount]: 사용 횟수
  ///
  /// Returns: 업로드된 미디어의 키 목록 (List of String)
  /// - 업로드 실패 시 빈 목록 반환
  Future<List<String>> uploadMedia({
    required List<http.MultipartFile> files,
    required List<MediaType> types,
    required List<MediaUsageType> usageTypes,
    required int userId,
    required int refId,
    required int usageCount,
  }) async {
    _setLoading(true);
    _setUploadProgress(0.0);
    _clearError();

    try {
      // service 호출
      final keys = await _mediaService.uploadMedia(
        files: files,
        types: types,
        usageTypes: usageTypes,
        userId: userId,
        refId: refId,
        usageCount: usageCount,
      );
      _setUploadProgress(1.0);
      _setLoading(false);
      return keys;
    } catch (e) {
      _setError('파일 업로드 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  /// 프로필 이미지 업로드
  ///
  /// Parameters:
  /// - [file]: 업로드할 파일 (MultipartFile 형식)
  /// - [userId]: 업로드하는 사용자 ID
  ///
  /// Returns: 업로드된 프로필 이미지의 키 (String)
  /// - 업로드 실패 시 null 반환
  Future<String?> uploadProfileImage({
    required http.MultipartFile file,
    required int userId,
  }) async {
    _setLoading(true);
    _setUploadProgress(0.0);
    _clearError();

    try {
      // service 호출
      final key = await _mediaService.uploadProfileImage(
        file: file,
        userId: userId,
      );
      _setUploadProgress(1.0); // 업로드률을 100%로 설정
      _setLoading(false);
      return key;
    } catch (e) {
      _setError('프로필 이미지 업로드 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  /// 댓글 오디오 업로드
  ///
  /// Parameters:
  /// - [file]: 업로드할 오디오 파일 (MultipartFile 형식)
  /// - [userId]: 업로드하는 사용자 ID
  /// - [postId]: 댓글이 달릴 게시물 ID
  ///
  /// Returns: 업로드된 오디오의 키 (String)
  /// - 업로드 실패 시 null 반환
  Future<String?> uploadCommentAudio({
    required http.MultipartFile file,
    required int userId,
    required int postId,
  }) async {
    _setLoading(true); // 로딩 상태 설정
    _setUploadProgress(0.0); // 업로드 진행률 초기화
    _clearError();

    try {
      // service 호출
      final key = await _mediaService.uploadCommentAudio(
        file: file,
        userId: userId,
        postId: postId,
      );
      _setUploadProgress(1.0); // 업로드률을 100%로 설정
      _setLoading(false); // 로딩 상태 해제
      return key;
    } catch (e) {
      _setError('댓글 오디오 업로드 실패: $e');
      _setLoading(false); // 로딩 상태 해제
      return null;
    }
  }

  // ============================================
  // 파일 변환 헬퍼
  // ============================================

  Future<http.MultipartFile> fileToMultipart(
    File file, {
    String fieldName = 'files',
  }) async {
    return MediaService.fileToMultipart(file, fieldName: fieldName);
  }

  Future<List<http.MultipartFile>> filesToMultipart(
    List<File> files, {
    String fieldName = 'files',
  }) async {
    return MediaService.filesToMultipart(files, fieldName: fieldName);
  }

  // ============================================
  // 에러 처리
  // ============================================

  void clearError() {
    if (_errorMessage == null) return;
    _scheduleNotify(() => _errorMessage = null);
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _scheduleNotify(() => _isLoading = value);
  }

  void _setError(String message) {
    if (_errorMessage == message) return;
    _scheduleNotify(() => _errorMessage = message);
  }

  void _clearError() {
    _errorMessage = null;
  }

  void _setUploadProgress(double? value) {
    if (_uploadProgress == value) return;
    _scheduleNotify(() => _uploadProgress = value);
  }

  void _scheduleNotify(VoidCallback updater) {
    void runUpdate() {
      updater();
      notifyListeners();
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      runUpdate();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        runUpdate();
      });
    }
  }
}

/// Presigned URL 캐시 엔트리
/// Presigned URL과 만료 시각을 함께 저장합니다.
///
/// Parameters:
/// - [ url ]: presigned URL
/// - [ expiresAt ]: 만료 시각
class _PresignedUrlCacheEntry {
  final String url;
  final DateTime expiresAt;

  const _PresignedUrlCacheEntry({required this.url, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
