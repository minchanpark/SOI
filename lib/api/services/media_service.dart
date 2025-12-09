import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';

/// 미디어 타입
///
/// 업로드할 파일의 미디어 타입입니다.
enum MediaType {
  /// 이미지 파일
  image('IMAGE'),

  /// 오디오 파일
  audio('AUDIO'),

  /// 비디오 파일
  video('VIDEO');

  final String value;
  const MediaType(this.value);
}

/// 미디어 사용 용도
///
/// 미디어 파일의 사용 용도입니다.
/// 서버 API 스펙: USER_PROFILE, CATEGORY_PROFILE, POST
enum MediaUsageType {
  /// 사용자 프로필 이미지
  userProfile('USER_PROFILE'),

  /// 카테고리 프로필 이미지
  categoryProfile('CATEGORY_PROFILE'),

  /// 댓글 오디오를 넣을 때 사용
  comment('COMMENT'),

  /// 게시물 관련 미디어
  post('POST');

  final String value;
  const MediaUsageType(this.value);
}

/// 미디어 관련 API 래퍼 서비스
///
/// 미디어 업로드, Presigned URL 발급 등 미디어 관련 기능을 제공합니다.
/// Provider를 통해 주입받아 사용합니다.
///
/// 사용 예시:
/// ```dart
/// final mediaService = Provider.of<MediaService>(context, listen: false);
///
/// // Presigned URL 발급
/// final urls = await mediaService.getPresignedUrls(['image1.jpg', 'audio1.mp3']);
///
/// // 이미지 업로드
/// final keys = await mediaService.uploadImage(
///   file: imageFile,
///   userId: 1,
///   refId: 1,
/// );
/// ```
class MediaService {
  final APIApi _mediaApi;

  MediaService({APIApi? mediaApi})
    : _mediaApi = mediaApi ?? SoiApiClient.instance.mediaApi;

  // ============================================
  // Presigned URL
  // ============================================

  /// Presigned URL 발급
  ///
  /// S3에 저장된 파일에 접근할 수 있는 1시간 유효한 URL을 발급받습니다.
  ///
  /// Parameters:
  /// - [keys]: S3 파일 키 목록
  ///
  /// Returns: Presigned URL 목록 (List<String>)
  ///
  /// Throws:
  /// - [BadRequestException]: 잘못된 키 형식
  /// - [NotFoundException]: 파일을 찾을 수 없음
  Future<List<String>> getPresignedUrls(List<String> keys) async {
    try {
      final response = await _mediaApi.getPresignedUrl(keys);

      if (response == null) {
        return [];
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? 'URL 발급 실패');
      }

      return response.data;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: 'URL 발급 실패: $e', originalException: e);
    }
  }

  /// 단일 파일 Presigned URL 발급 (편의 메서드)
  Future<String?> getPresignedUrl(String key) async {
    final urls = await getPresignedUrls([key]);
    return urls.isNotEmpty ? urls.first : null;
  }

  // ============================================
  // 미디어 업로드
  // ============================================

  /// 미디어 파일 업로드
  ///
  /// 파일을 S3에 업로드합니다.
  ///
  /// Parameters:
  /// - [files]: 업로드할 파일 목록 (MultipartFile)
  /// - [types]: 각 파일의 미디어 타입 목록
  /// - [usageTypes]: 각 파일의 사용 용도 목록
  /// - [userId]: 업로드 사용자 ID
  /// - [refId]: 참조 ID (게시물 ID 등)
  ///
  /// Returns: 업로드된 파일의 S3 키 목록 (List<String>)
  Future<List<String>> uploadMedia({
    required List<http.MultipartFile> files,
    required List<MediaType> types,
    required List<MediaUsageType> usageTypes,
    required int userId,
    required int refId,
    required int usageCount,
  }) async {
    try {
      final typeStrings = types.map((t) => t.value).toList();
      final usageTypeStrings = usageTypes.map((t) => t.value).toList();

      debugPrint('[MediaService] uploadMedia 호출:');
      debugPrint('  - types: $typeStrings');
      debugPrint('  - usageTypes: $usageTypeStrings');
      debugPrint('  - userId: $userId');
      debugPrint('  - refId: $refId');
      debugPrint('  - files: ${files.length}개');
      for (final file in files) {
        debugPrint('    - filename: ${file.filename}, length: ${file.length}');
      }

      final response = await _mediaApi.uploadMedia(
        typeStrings,
        usageTypeStrings,
        userId,
        refId,
        usageCount,
        files,
      );

      if (response == null) {
        throw const DataValidationException(message: '업로드 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '업로드 실패');
      }

      return response.data;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '파일 업로드 실패: $e', originalException: e);
    }
  }

  /// 이미지 파일 업로드 (편의 메서드)
  ///
  /// 게시물용 이미지를 업로드합니다.
  /*Future<String?> uploadPostImage({
    required http.MultipartFile file,
    required int userId,
    required int refId,
  }) async {
    final keys = await uploadMedia(
      files: [file],
      types: [MediaType.image],
      usageTypes: [MediaUsageType.post],
      userId: userId,
      refId: refId,
    );
    return keys.isNotEmpty ? keys.first : null;
  }*/

  /// 오디오 파일 업로드 (편의 메서드)
  ///
  /// 게시물용 음성메모를 업로드합니다.
  /* Future<String?> uploadPostAudio({
    required http.MultipartFile file,
    required int userId,
    required int refId,
  }) async {
    final keys = await uploadMedia(
      files: [file],
      types: [MediaType.audio],
      usageTypes: [MediaUsageType.post],
      userId: userId,
      refId: refId,
    );
    return keys.isNotEmpty ? keys.first : null;
  }*/

  /// 프로필 이미지 업로드 (편의 메서드)
  Future<String?> uploadProfileImage({
    required http.MultipartFile file,
    required int userId,
  }) async {
    final keys = await uploadMedia(
      files: [file],
      types: [MediaType.image],
      usageTypes: [MediaUsageType.userProfile],
      userId: userId,
      refId: userId, // 프로필은 userId를 refId로 사용
      usageCount: 1,
    );
    return keys.isNotEmpty ? keys.first : null;
  }

  /// 댓글 오디오 업로드 (편의 메서드)
  ///
  /// 음성 댓글을 업로드합니다.
  Future<String?> uploadCommentAudio({
    required http.MultipartFile file,
    required int userId,
    required int postId,
  }) async {
    final keys = await uploadMedia(
      files: [file],
      types: [MediaType.audio],
      usageTypes: [MediaUsageType.post],
      userId: userId,
      refId: postId,
      usageCount: 1,
    );
    return keys.isNotEmpty ? keys.first : null;
  }

  // ============================================
  // 파일 -> MultipartFile 변환 헬퍼
  // ============================================

  /// File을 MultipartFile로 변환
  ///
  /// dart:io의 File을 http 패키지의 MultipartFile로 변환합니다.
  ///
  /// Parameters:
  /// - [file]: 변환할 파일
  /// - [fieldName]: 폼 필드 이름 (기본값: 'files')
  static Future<http.MultipartFile> fileToMultipart(
    File file, {
    String fieldName = 'files',
  }) async {
    return http.MultipartFile.fromPath(fieldName, file.path);
  }

  /// 여러 File을 MultipartFile 목록으로 변환
  static Future<List<http.MultipartFile>> filesToMultipart(
    List<File> files, {
    String fieldName = 'files',
  }) async {
    final multipartFiles = <http.MultipartFile>[];
    for (final file in files) {
      multipartFiles.add(await fileToMultipart(file, fieldName: fieldName));
    }
    return multipartFiles;
  }

  // ============================================
  // 에러 핸들링 헬퍼
  // ============================================

  SoiApiException _handleApiException(ApiException e) {
    debugPrint('🔴 API Error [${e.code}]: ${e.message}');

    switch (e.code) {
      case 400:
        return BadRequestException(
          message: e.message ?? '잘못된 요청입니다.',
          originalException: e,
        );
      case 401:
        return AuthException(
          message: e.message ?? '인증이 필요합니다.',
          originalException: e,
        );
      case 403:
        return ForbiddenException(
          message: e.message ?? '접근 권한이 없습니다.',
          originalException: e,
        );
      case 404:
        return NotFoundException(
          message: e.message ?? '파일을 찾을 수 없습니다.',
          originalException: e,
        );
      case 413:
        return BadRequestException(
          message: '파일 크기가 너무 큽니다.',
          originalException: e,
        );
      case >= 500:
        return ServerException(
          statusCode: e.code,
          message: e.message ?? '서버 오류가 발생했습니다.',
          originalException: e,
        );
      default:
        return SoiApiException(
          statusCode: e.code,
          message: e.message ?? '알 수 없는 오류가 발생했습니다.',
          originalException: e,
        );
    }
  }
}
