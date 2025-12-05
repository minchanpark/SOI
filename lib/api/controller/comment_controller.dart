import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/comment_service.dart';

/// 댓글 컨트롤러
///
/// 댓글 관련 UI 상태 관리 및 비즈니스 로직을 담당합니다.
/// CommentService를 내부적으로 사용하며, API 변경 시 Service만 수정하면 됩니다.
///
/// 사용 예시:
/// ```dart
/// final controller = Provider.of<CommentController>(context, listen: false);
///
/// // 댓글 생성
/// await controller.createComment(
///   postId: 1,
///   userId: 1,
///   text: '좋은 사진이네요!',
/// );
///
/// // 댓글 조회
/// final comments = await controller.getComments(postId: 1);
/// ```
class CommentController extends ChangeNotifier {
  final CommentService _commentService;

  bool _isLoading = false;
  String? _errorMessage;

  /// 생성자
  ///
  /// [commentService]를 주입받아 사용합니다. 테스트 시 MockCommentService를 주입할 수 있습니다.
  CommentController({CommentService? commentService})
    : _commentService = commentService ?? CommentService();

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  // ============================================
  // 댓글 생성
  // ============================================

  /// 댓글 생성
  Future<bool> createComment({
    required int postId,
    required int userId,
    String? text,
    String? audioKey,
    String? waveformData,
    int? duration,
    double? locationX,
    double? locationY,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _commentService.createComment(
        postId: postId,
        userId: userId,
        text: text,
        audioKey: audioKey,
        waveformData: waveformData,
        duration: duration,
        locationX: locationX,
        locationY: locationY,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('댓글 생성 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 텍스트 댓글 생성
  Future<bool> createTextComment({
    required int postId,
    required int userId,
    required String text,
    double? locationX,
    double? locationY,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _commentService.createTextComment(
        postId: postId,
        userId: userId,
        text: text,
        locationX: locationX,
        locationY: locationY,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('텍스트 댓글 생성 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 음성 댓글 생성
  Future<bool> createAudioComment({
    required int postId,
    required int userId,
    required String audioKey,
    String? waveformData,
    int? duration,
    double? locationX,
    double? locationY,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _commentService.createAudioComment(
        postId: postId,
        userId: userId,
        audioKey: audioKey,
        waveformData: waveformData,
        duration: duration,
        locationX: locationX,
        locationY: locationY,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('음성 댓글 생성 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 이모지 댓글 생성
  Future<bool> createEmojiComment({
    required int postId,
    required int userId,
    required int emojiId,
    double? locationX,
    double? locationY,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _commentService.createEmojiComment(
        postId: postId,
        userId: userId,
        emojiId: emojiId,
        locationX: locationX,
        locationY: locationY,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('이모지 댓글 생성 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 댓글 조회
  // ============================================

  /// 게시물의 댓글 조회
  Future<List<Comment>> getComments({required int postId}) async {
    _setLoading(true);
    _clearError();

    try {
      final comments = await _commentService.getComments(postId: postId);
      _setLoading(false);
      return comments;
    } catch (e) {
      _setError('댓글 조회 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  /// 댓글 개수 조회
  Future<int> getCommentCount({required int postId}) async {
    _setLoading(true);
    _clearError();

    try {
      final count = await _commentService.getCommentCount(postId: postId);
      _setLoading(false);
      return count;
    } catch (e) {
      _setError('댓글 개수 조회 실패: $e');
      _setLoading(false);
      return 0;
    }
  }

  // ============================================
  // 댓글 삭제
  // ============================================

  /// 댓글 삭제
  Future<bool> deleteComment(int commentId) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _commentService.deleteComment(commentId);
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('댓글 삭제 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 에러 처리
  // ============================================

  /// 에러 초기화
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
}
