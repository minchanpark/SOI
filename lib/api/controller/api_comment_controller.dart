import '../models/models.dart';
import '../services/comment_service.dart';
import 'comment_controller.dart';

/// REST API 기반 댓글 컨트롤러 구현체
///
/// CommentService를 사용하여 댓글 관련 기능을 구현합니다.
/// CommentController를 상속받아 구현합니다.
///   - CommentController: 댓글 관련 기능 정의
///   - ApiCommentController: REST API 기반 구현체
///
/// 사용 예시:
/// ```dart
/// final controller = ApiCommentController();
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
class ApiCommentController extends CommentController {
  final CommentService _commentService;

  bool _isLoading = false;
  String? _errorMessage;

  ApiCommentController({CommentService? commentService})
    : _commentService = commentService ?? CommentService();

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  // ============================================
  // 댓글 생성
  // ============================================

  @override
  Future<bool> createComment({
    required int postId,
    required int userId,
    String? text,
    String? audioKey,
    String? waveformData,
    int? duration,
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
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('댓글 생성 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  @override
  Future<bool> createTextComment({
    required int postId,
    required int userId,
    required String content,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _commentService.createTextComment(
        postId: postId,
        userId: userId,
        content: content,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('텍스트 댓글 생성 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  @override
  Future<bool> createAudioComment({
    required int postId,
    required int userId,
    required String audioKey,
    String? waveformData,
    int? duration,
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
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('음성 댓글 생성 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 댓글 조회
  // ============================================

  @override
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

  @override
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
}
