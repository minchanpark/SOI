import 'dart:io';

import 'package:http/http.dart' as http;

import '../services/media_service.dart';
import 'media_controller.dart';

/// REST API 기반 미디어 컨트롤러 구현체
///
/// MediaService를 사용하여 미디어 업로드 관련 기능을 구현합니다.
/// MediaController를 상속받아 구현합니다.
///   - MediaController: 미디어 관련 기능 정의
///   - ApiMediaController: REST API 기반 구현체
///
/// 사용 예시:
/// ```dart
/// final controller = ApiMediaController();
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
class ApiMediaController extends MediaController {
  final MediaService _mediaService;

  bool _isLoading = false;
  String? _errorMessage;
  double? _uploadProgress;

  ApiMediaController({MediaService? mediaService})
    : _mediaService = mediaService ?? MediaService();

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  @override
  double? get uploadProgress => _uploadProgress;

  // ============================================
  // Presigned URL
  // ============================================

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
  Future<http.MultipartFile> fileToMultipart(
    File file, {
    String fieldName = 'files',
  }) async {
    return MediaService.fileToMultipart(file, fieldName: fieldName);
  }

  @override
  Future<List<http.MultipartFile>> filesToMultipart(
    List<File> files, {
    String fieldName = 'files',
  }) async {
    return MediaService.filesToMultipart(files, fieldName: fieldName);
  }

  // ============================================
  // 에러 처리
  // ============================================

  @override
  void clearError() {
    _clearError();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void _setUploadProgress(double? value) {
    _uploadProgress = value;
    notifyListeners();
  }
}
