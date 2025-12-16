import 'dart:convert';
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
///   text: '좋은 사진이네요!',
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
  /// - [text]: 댓글 내용 (텍스트)
  /// - [audioFileKey]: 음성 파일 키 (선택, 음성 댓글인 경우)
  /// - [waveformData]: 음성 파형 데이터 (선택)
  /// - [duration]: 음성 길이 (선택)
  ///
  /// Returns: 생성 성공 여부
  ///
  /// Throws:
  /// - [BadRequestException]: 필수 정보 누락
  /// - [NotFoundException]: 게시물을 찾을 수 없음
  Future<CommentCreationResult> createComment({
    required int postId,
    required int userId,
    int? emojiId,
    String? text,
    String? audioFileKey,
    String? waveformData,
    int? duration,
    double? locationX,
    double? locationY,
    CommentType? type,
  }) async {
    try {
      final commentTypeEnum = _toCommentTypeEnum(type);

      final dto = CommentReqDto(
        postId: postId,
        userId: userId,
        emojiId: emojiId,
        text: text,
        audioKey: audioFileKey,
        waveformData: waveformData,
        duration: duration,
        locationX: locationX,
        locationY: locationY,
        commentType: commentTypeEnum,
      );

      debugPrint('=== 댓글 생성 요청 ===');
      debugPrint('postId: $postId, userId: $userId');
      debugPrint('commentType: ${commentTypeEnum.value}');
      debugPrint('audioFileKey: $audioFileKey');
      debugPrint('text: $text');
      debugPrint('waveformData type: ${waveformData?.runtimeType}');
      debugPrint('waveformData value: $waveformData');
      if (waveformData != null && waveformData.isNotEmpty) {
        final end = waveformData.length > 50 ? 50 : waveformData.length;
        debugPrint(
          'waveformData first 50 chars: ${waveformData.substring(0, end)}',
        );
      }

      final jsonMap = dto.toJson();
      final waveformValue = jsonMap['waveformData'];
      // 백엔드가 `waveFormData`(F 대문자)로 필드를 받을 수 있어 호환을 위해 함께 전송합니다.
      if (waveformValue is String) {
        jsonMap['waveFormData'] = waveformValue;
      }
      debugPrint('DTO JSON map: $jsonMap');
      debugPrint(
        'waveformData in JSON type: ${jsonMap['waveformData'].runtimeType}',
      );
      try {
        final encoded = jsonEncode(jsonMap);
        final preview = encoded.length > 300
            ? encoded.substring(0, 300)
            : encoded;
        debugPrint('DTO JSON encoded (preview): $preview');
      } catch (_) {
        // ignore: empty_catches
      }

      final response = await _createComment(jsonMap);
      debugPrint("댓글 생성 응답: $response");

      if (response == null) {
        throw const DataValidationException(message: '댓글 생성 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '댓글 생성 실패');
      }

      final parsedComment = _parseCommentFromResponse(response);
      return CommentCreationResult(success: true, comment: parsedComment);
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
  Future<CommentCreationResult> createTextComment({
    required int postId,
    required int userId,
    required String text,
    required double locationX,
    required double locationY,
  }) async {
    return createComment(
      postId: postId,
      userId: userId,
      // TEXT 댓글은 서버가 null/empty 처리에 민감할 수 있어 Swagger 입력 형태로 맞춥니다.
      emojiId: 0,
      text: text,
      audioFileKey: '',
      waveformData: '',
      duration: 0,
      locationX: locationX,
      locationY: locationY,
      type: CommentType.text,
    );
  }

  /// 음성 댓글 생성 (편의 메서드)
  Future<CommentCreationResult> createAudioComment({
    required int postId,
    required int userId,
    required String audioFileKey,
    required String waveformData,
    required int duration,
    required double locationX,
    required double locationY,
  }) async {
    return createComment(
      postId: postId,
      userId: userId,
      emojiId: 0,
      text: '',
      audioFileKey: audioFileKey,
      waveformData: waveformData,
      duration: duration,
      locationX: locationX,
      locationY: locationY,
      type: CommentType.audio,
    );
  }

  /// 이모지 댓글 생성 (편의 메서드)
  Future<CommentCreationResult> createEmojiComment({
    required int postId,
    required int userId,
    required int emojiId,
  }) async {
    return createComment(
      postId: postId,
      userId: userId,
      emojiId: emojiId,
      text: '',
      audioFileKey: '',
      waveformData: '',
      duration: 0,
      locationX: 0,
      locationY: 0,
      type: CommentType.emoji,
    );
  }

  /// 댓글 생성 응답에서 Comment 객체 파싱
  ///
  /// Parameters:
  ///   - [response]: API 응답 객체
  ///
  /// Returns: 파싱된 Comment 객체 (없을 경우 null)
  Comment? _parseCommentFromResponse(ApiResponseDtoObject response) {
    final data = response.data;
    if (data == null) {
      debugPrint('댓글 생성 응답에 data가 없습니다.');
      return null;
    }

    if (data is CommentRespDto) {
      return Comment.fromDto(data);
    }

    if (data is Map<String, dynamic>) {
      final dto = CommentRespDto.fromJson(data);
      if (dto != null) return Comment.fromDto(dto);
    }

    if (data is Map) {
      final dto = CommentRespDto.fromJson(Map<String, dynamic>.from(data));
      if (dto != null) return Comment.fromDto(dto);
    }

    if (data is List) {
      final list = CommentRespDto.listFromJson(data);
      if (list.isNotEmpty) {
        return Comment.fromDto(list.first);
      }
    }

    debugPrint('댓글 생성 응답 data 파싱 실패: ${data.runtimeType}');
    return null;
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
  // 댓글 삭제
  // ============================================

  /// 댓글 삭제
  ///
  /// [commentId]에 해당하는 댓글을 삭제합니다.
  ///
  /// Returns: 삭제 성공 여부
  ///
  /// Throws:
  /// - [NotFoundException]: 댓글을 찾을 수 없음
  Future<bool> deleteComment(int commentId) async {
    try {
      final response = await _commentApi.deleteComment(commentId);

      if (response == null) {
        throw const DataValidationException(message: '댓글 삭제 응답이 없습니다.');
      }

      if (response.success != true) {
        throw SoiApiException(message: response.message ?? '댓글 삭제 실패');
      }

      return true;
    } on ApiException catch (e) {
      throw _handleApiException(e);
    } on SocketException catch (e) {
      throw NetworkException(originalException: e);
    } catch (e) {
      if (e is SoiApiException) rethrow;
      throw SoiApiException(message: '댓글 삭제 실패: $e', originalException: e);
    }
  }

  // ============================================
  // 에러 핸들링 헬퍼
  // ============================================

  /// CommentType을 API DTO enum으로 변환
  CommentReqDtoCommentTypeEnum _toCommentTypeEnum(CommentType? type) {
    switch (type) {
      case CommentType.text:
        return CommentReqDtoCommentTypeEnum.TEXT;
      case CommentType.audio:
        return CommentReqDtoCommentTypeEnum.AUDIO;
      case CommentType.emoji:
        return CommentReqDtoCommentTypeEnum.EMOJI;
      default:
        return CommentReqDtoCommentTypeEnum.TEXT;
    }
  }

  SoiApiException _handleApiException(ApiException e) {
    debugPrint('API Error [${e.code}]: ${e.message}');

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

  Future<ApiResponseDtoObject?> _createComment(
    Map<String, dynamic> body,
  ) async {
    final apiClient = SoiApiClient.instance.apiClient;
    final response = await apiClient.invokeAPI(
      '/comment/create',
      'POST',
      const <QueryParam>[],
      body,
      <String, String>{},
      <String, String>{},
      'application/json',
    );

    if (response.statusCode >= HttpStatus.badRequest) {
      throw ApiException(response.statusCode, utf8.decode(response.bodyBytes));
    }

    if (response.bodyBytes.isEmpty ||
        response.statusCode == HttpStatus.noContent) {
      return null;
    }

    final decodedBody = utf8.decode(response.bodyBytes);
    return await apiClient.deserializeAsync(decodedBody, 'ApiResponseDtoObject')
        as ApiResponseDtoObject?;
  }
}
