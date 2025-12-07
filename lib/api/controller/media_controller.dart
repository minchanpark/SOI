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

  Future<List<String>> getPresignedUrls(List<String> keys) async {
    _setLoading(true);
    _clearError();

    try {
      final urls = await _mediaService.getPresignedUrls(keys);
      _setLoading(false);
      return urls;
    } catch (e) {
      _setError('URL 발급 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  Future<String?> getPresignedUrl(String key) async {
    _setLoading(true);
    _clearError();

    try {
      final url = await _mediaService.getPresignedUrl(key);
      _setLoading(false);
      return url;
    } catch (e) {
      _setError('URL 발급 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  // ============================================
  // 미디어 업로드
  // ============================================

  Future<List<String>> uploadMedia({
    required List<http.MultipartFile> files,
    required List<MediaType> types,
    required List<MediaUsageType> usageTypes,
    required int userId,
    required int refId,
  }) async {
    _setLoading(true);
    _setUploadProgress(0.0);
    _clearError();

    try {
      final keys = await _mediaService.uploadMedia(
        files: files,
        types: types,
        usageTypes: usageTypes,
        userId: userId,
        refId: refId,
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

  Future<String?> uploadPostImage({
    required http.MultipartFile file,
    required int userId,
    required int refId,
  }) async {
    _setLoading(true);
    _setUploadProgress(0.0);
    _clearError();

    try {
      final key = await _mediaService.uploadPostImage(
        file: file,
        userId: userId,
        refId: refId,
      );
      _setUploadProgress(1.0);
      _setLoading(false);
      return key;
    } catch (e) {
      _setError('이미지 업로드 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  Future<String?> uploadPostAudio({
    required http.MultipartFile file,
    required int userId,
    required int refId,
  }) async {
    _setLoading(true);
    _setUploadProgress(0.0);
    _clearError();

    try {
      final key = await _mediaService.uploadPostAudio(
        file: file,
        userId: userId,
        refId: refId,
      );
      _setUploadProgress(1.0);
      _setLoading(false);
      return key;
    } catch (e) {
      _setError('오디오 업로드 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  Future<String?> uploadProfileImage({
    required http.MultipartFile file,
    required int userId,
  }) async {
    _setLoading(true);
    _setUploadProgress(0.0);
    _clearError();

    try {
      final key = await _mediaService.uploadProfileImage(
        file: file,
        userId: userId,
      );
      _setUploadProgress(1.0);
      _setLoading(false);
      return key;
    } catch (e) {
      _setError('프로필 이미지 업로드 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  Future<String?> uploadCommentAudio({
    required http.MultipartFile file,
    required int userId,
    required int postId,
  }) async {
    _setLoading(true);
    _setUploadProgress(0.0);
    _clearError();

    try {
      final key = await _mediaService.uploadCommentAudio(
        file: file,
        userId: userId,
        postId: postId,
      );
      _setUploadProgress(1.0);
      _setLoading(false);
      return key;
    } catch (e) {
      _setError('댓글 오디오 업로드 실패: $e');
      _setLoading(false);
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
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      runUpdate();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        runUpdate();
      });
    }
  }
}
