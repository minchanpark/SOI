import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:soi_api_client/api.dart';

import '../api_client.dart';
import '../api_exception.dart';
import '../models/models.dart';

/// 댓글 관련 API 래퍼 서비스
///
/// 댓글 생성, 조회 등 댓글 관련 기능을 제공합니다.
/// Provider를 통해 주입받아 사용합니다.
///
/// 사용 예시:
/// ```dart
/// final commentService = Provider.of<CommentService>(context, listen: false);
///
/// // 댓글 생성
/// await commentService.createComment(
///   postId: 1,
///   userId: 1,
///   content: '좋은 사진이네요!',
/// );
///
/// // 댓글 조회
/// final comments = await commentService.getComments(postId: 1);
/// ```
class CommentService {
  final CommentAPIApi _commentApi;

  CommentService({CommentAPIApi? commentApi})
    : _commentApi = commentApi ?? SoiApiClient.instance.commentApi;

  // ============================================
  // 댓글 생성
  // ============================================

  /// 댓글 생성
  ///
  /// 게시물에 새로운 댓글을 작성합니다.
  /// 음성 댓글인 경우 [audioFileKey]를 포함합니다.
  ///
  /// Parameters:
  /// - [postId]: 게시물 ID
  /// - [userId]: 작성자 ID
  /// - [content]: 댓글 내용 (텍스트)
  /// - [audioFileKey]: 음성 파일 키 (선택, 음성 댓글인 경우)
  /// - [waveformData]: 음성 파형 데이터 (선택)
  /// - [duration]: 음성 길이 (선택)
  ///
  /// Returns: 생성 성공 여부
  ///
  /// Throws:
  /// - [BadRequestException]: 필수 정보 누락
  /// - [NotFoundException]: 게시물을 찾을 수 없음
  Future<bool> createComment({
    required int postId,
    required int userId,
    String? text,
    String? audioKey,
    String? waveformData,
    int? duration,
    String? content,
  }) async {
    try {
      final dto = CommentReqDto(
        postId: postId,
        userId: userId,
        text: text,
        audioKey: audioKey,
        waveformData: waveformData,
        duration: duration,
      );

      final response = await _commentApi.create2(dto);

      if (response == null) {
        throw const DataValidationException(message: '댓글 생성 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '댓글 생성 실패');
      }

      return true;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '댓글 생성 실패: $e', originalException: e);
    }
  }

  /// 텍스트 댓글 생성 (편의 메서드)
  Future<bool> createTextComment({
    required int postId,
    required int userId,
    required String content,
  }) async {
    return createComment(postId: postId, userId: userId, content: content);
  }

  /// 음성 댓글 생성 (편의 메서드)
  Future<bool> createAudioComment({
    required int postId,
    required int userId,
    required String audioKey,
    String? waveformData,
    int? duration,
  }) async {
    return createComment(
      postId: postId,
      userId: userId,
      audioKey: audioKey,
      waveformData: waveformData,
      duration: duration,
    );
  }

  // ============================================
  // 댓글 조회
  // ============================================

  /// 게시물의 댓글 조회
  ///
  /// [postId]에 해당하는 게시물의 모든 댓글을 조회합니다.
  ///
  /// Returns: 댓글 목록 (List<Comment>)
  ///
  /// Throws:
  /// - [NotFoundException]: 게시물을 찾을 수 없음
  Future<List<Comment>> getComments({required int postId}) async {
    try {
      final response = await _commentApi.getComment(postId);

      if (response == null) {
        return [];
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '댓글 조회 실패');
      }

      return response.data.map((dto) => Comment.fromDto(dto)).toList();
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '댓글 조회 실패: $e', originalException: e);
    }
  }

  /// 댓글 개수 조회 (편의 메서드)
  ///
  /// 게시물의 댓글 수를 반환합니다.
  Future<int> getCommentCount({required int postId}) async {
    final comments = await getComments(postId: postId);
    return comments.length;
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
          message: e.message ?? '댓글을 찾을 수 없습니다.',
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
