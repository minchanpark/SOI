import 'package:flutter/material.dart';

import '../models/models.dart';

/// 댓글 컨트롤러 추상 클래스
///
/// 댓글 관련 기능을 정의하는 인터페이스입니다.
/// 구현체를 교체하여 테스트나 다른 백엔드 사용이 가능합니다.
///
/// 사용 예시:
/// ```dart
/// final commentController = Provider.of<CommentController>(context, listen: false);
///
/// // 댓글 생성
/// await commentController.createComment(
///   postId: 1,
///   userId: 1,
///   text: '좋은 사진이네요!',
/// );
///
/// // 댓글 조회
/// final comments = await commentController.getComments(postId: 1);
/// ```
abstract class CommentController extends ChangeNotifier {
  /// 로딩 상태
  bool get isLoading;

  /// 에러 메시지
  String? get errorMessage;

  // ============================================
  // 댓글 생성
  // ============================================

  /// 댓글 생성
  ///
  /// 게시물에 새로운 댓글을 작성합니다.
  ///
  /// Parameters:
  /// - [postId]: 게시물 ID
  /// - [userId]: 작성자 ID
  /// - [text]: 텍스트 내용 (선택)
  /// - [audioUrl]: 음성 파일 URL (선택, 음성 댓글인 경우)
  /// - [waveformData]: 음성 파형 데이터 (선택)
  /// - [duration]: 음성 길이 (선택)
  ///
  /// Returns: 생성 성공 여부
  Future<bool> createComment({
    required int postId,
    required int userId,
    String? text,
    String? audioUrl,
    String? waveformData,
    int? duration,
  });

  /// 텍스트 댓글 생성 (편의 메서드)
  ///
  /// Parameters:
  /// - [postId]: 게시물 ID
  /// - [userId]: 작성자 ID
  /// - [content]: 텍스트 내용
  ///
  /// Returns: 생성 성공 여부
  Future<bool> createTextComment({
    required int postId,
    required int userId,
    required String content,
  });

  /// 음성 댓글 생성 (편의 메서드)
  ///
  /// Parameters:
  /// - [postId]: 게시물 ID
  /// - [userId]: 작성자 ID
  /// - [audioUrl]: 음성 파일 URL
  /// - [waveformData]: 음성 파형 데이터 (선택)
  /// - [duration]: 음성 길이 (선택)
  ///
  /// Returns: 생성 성공 여부
  Future<bool> createAudioComment({
    required int postId,
    required int userId,
    required String audioUrl,
    String? waveformData,
    int? duration,
  });

  // ============================================
  // 댓글 조회
  // ============================================

  /// 게시물의 댓글 조회
  ///
  /// [postId]에 해당하는 게시물의 모든 댓글을 조회합니다.
  ///
  /// Returns: 댓글 목록 (List<Comment>)
  Future<List<Comment>> getComments({required int postId});

  /// 댓글 개수 조회 (편의 메서드)
  ///
  /// 게시물의 댓글 수를 반환합니다.
  ///
  /// Returns: 댓글 개수
  Future<int> getCommentCount({required int postId});

  // ============================================
  // 에러 처리
  // ============================================

  /// 에러 초기화
  void clearError();
}
