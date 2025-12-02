import '../models/models.dart';
import '../services/post_service.dart';
import 'post_controller.dart';

/// REST API 기반 게시물 컨트롤러 구현체
///
/// PostService를 사용하여 게시물 관련 기능을 구현합니다.
/// PostController를 상속받아 구현합니다.
///   - PostController: 게시물 관련 기능 정의
///   - ApiPostController: REST API 기반 구현체
///
/// 사용 예시:
/// ```dart
/// final controller = ApiPostController();
///
/// // 게시물 생성
/// final success = await controller.createPost(
///   userId: 'user123',
///   content: '오늘의 일상',
///   postFileKey: 'images/photo.jpg',
///   categoryIds: [1, 2],
/// );
///
/// // 메인 피드 조회
/// final posts = await controller.getMainFeedPosts(userId: 1);
/// ```
class ApiPostController extends PostController {
  final PostService _postService;

  bool _isLoading = false;
  String? _errorMessage;

  ApiPostController({PostService? postService})
    : _postService = postService ?? PostService();

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  // ============================================
  // 게시물 생성
  // ============================================

  @override
  Future<bool> createPost({
    required String userId,
    String? content,
    String? postFileKey,
    String? audioFileKey,
    List<int> categoryIds = const [],
    String? waveformData,
    int? duration,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _postService.createPost(
        userId: userId,
        content: content,
        postFileKey: postFileKey,
        audioFileKey: audioFileKey,
        categoryIds: categoryIds,
        waveformData: waveformData,
        duration: duration,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('게시물 생성 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 게시물 조회
  // ============================================

  @override
  Future<List<Post>> getMainFeedPosts({required int userId}) async {
    _setLoading(true);
    _clearError();

    try {
      final posts = await _postService.getMainFeedPosts(userId: userId);
      _setLoading(false);
      return posts;
    } catch (e) {
      _setError('피드 조회 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  @override
  Future<List<Post>> getPostsByCategory({
    required int categoryId,
    required int userId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final posts = await _postService.getPostsByCategory(
        categoryId: categoryId,
        userId: userId,
      );
      _setLoading(false);
      return posts;
    } catch (e) {
      _setError('카테고리 게시물 조회 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  @override
  Future<Post?> getPostDetail(int postId) async {
    _setLoading(true);
    _clearError();

    try {
      final post = await _postService.getPostDetail(postId);
      _setLoading(false);
      return post;
    } catch (e) {
      _setError('게시물 상세 조회 실패: $e');
      _setLoading(false);
      return null;
    }
  }

  // ============================================
  // 게시물 수정
  // ============================================

  @override
  Future<bool> updatePost({
    required int postId,
    String? content,
    String? postFileKey,
    String? audioFileKey,
    List<int>? categoryIds,
    String? waveformData,
    int? duration,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _postService.updatePost(
        postId: postId,
        content: content,
        postFileKey: postFileKey,
        audioFileKey: audioFileKey,
        categoryIds: categoryIds,
        waveformData: waveformData,
        duration: duration,
      );
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('게시물 수정 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 게시물 삭제
  // ============================================

  @override
  Future<bool> deletePost(int postId) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _postService.deletePost(postId);
      _setLoading(false);
      return result;
    } catch (e) {
      _setError('게시물 삭제 실패: $e');
      _setLoading(false);
      return false;
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
