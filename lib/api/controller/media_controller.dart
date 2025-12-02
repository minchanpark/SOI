import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/media_service.dart';

/// 미디어 컨트롤러 추상 클래스
///
/// 미디어 업로드 및 URL 발급 관련 기능을 정의하는 인터페이스입니다.
/// 구현체를 교체하여 테스트나 다른 백엔드 사용이 가능합니다.
///
/// 사용 예시:
/// ```dart
/// final mediaController = Provider.of<MediaController>(context, listen: false);
///
/// // Presigned URL 발급
/// final urls = await mediaController.getPresignedUrls(['image1.jpg']);
///
/// // 이미지 업로드
/// final key = await mediaController.uploadPostImage(
///   file: imageFile,
///   userId: 1,
///   refId: 1,
/// );
/// ```
abstract class MediaController extends ChangeNotifier {
  /// 로딩 상태
  bool get isLoading;

  /// 에러 메시지
  String? get errorMessage;

  /// 업로드 진행률 (0.0 ~ 1.0, 향후 확장용)
  double? get uploadProgress;

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
  Future<List<String>> getPresignedUrls(List<String> keys);

  /// 단일 파일 Presigned URL 발급 (편의 메서드)
  ///
  /// Returns: Presigned URL
  Future<String?> getPresignedUrl(String key);

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
  });

  /// 게시물 이미지 업로드 (편의 메서드)
  ///
  /// Returns: 업로드된 파일의 S3 키
  Future<String?> uploadPostImage({
    required http.MultipartFile file,
    required int userId,
    required int refId,
  });

  /// 게시물 오디오 업로드 (편의 메서드)
  ///
  /// Returns: 업로드된 파일의 S3 키
  Future<String?> uploadPostAudio({
    required http.MultipartFile file,
    required int userId,
    required int refId,
  });

  /// 프로필 이미지 업로드 (편의 메서드)
  ///
  /// Returns: 업로드된 파일의 S3 키
  Future<String?> uploadProfileImage({
    required http.MultipartFile file,
    required int userId,
  });

  /// 댓글 오디오 업로드 (편의 메서드)
  ///
  /// Returns: 업로드된 파일의 S3 키
  Future<String?> uploadCommentAudio({
    required http.MultipartFile file,
    required int userId,
    required int postId,
  });

  // ============================================
  // 파일 변환 헬퍼
  // ============================================

  /// File을 MultipartFile로 변환
  Future<http.MultipartFile> fileToMultipart(
    File file, {
    String fieldName = 'files',
  });

  /// 여러 File을 MultipartFile 목록으로 변환
  Future<List<http.MultipartFile>> filesToMultipart(
    List<File> files, {
    String fieldName = 'files',
  });

  // ============================================
  // 에러 처리
  // ============================================

  /// 에러 초기화
  void clearError();
}
