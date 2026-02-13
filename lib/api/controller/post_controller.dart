import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../services/post_service.dart';

/// 게시물 컨트롤러
///
/// 게시물 관련 UI 상태 관리 및 비즈니스 로직을 담당합니다.
/// PostService를 내부적으로 사용하며, API 변경 시 Service만 수정하면 됩니다.
///
/// 사용 예시:
/// ```dart
/// final controller = Provider.of<PostController>(context, listen: false);
///
/// // 게시물 생성
/// final success = await controller.createPost(
///   nickName: 'user123',
///   content: '오늘의 일상',
///   postFileKey: 'images/photo.jpg',
///   categoryIds: [1, 2],
/// );
///
/// // 메인 피드 조회
/// final posts = await controller.getMainFeedPosts(userId: 1);
/// ```
class PostController extends ChangeNotifier {
  final PostService _postService;

  bool _isLoading = false;
  String? _errorMessage;

  // ✨ Controller 레벨 캐시
  final Map<String, _CachedCategoryPosts> _categoryCache = {};
  static const Duration _controllerCacheTtl = Duration(hours: 1);

  // 게시물 변경 리스너 목록
  final List<VoidCallback> _onPostsChangedListeners = [];

  /// 게시물 변경 리스너 추가
  void addPostsChangedListener(VoidCallback listener) {
    _onPostsChangedListeners.add(listener);
  }

  /// 게시물 변경 리스너 제거
  void removePostsChangedListener(VoidCallback listener) {
    _onPostsChangedListeners.remove(listener);
  }

  /// 게시물 변경 알림
  void _notifyPostsChanged() {
    // ✨ 캐시 무효화 (게시물 변경 시)
    clearAllCache();

    for (final listener in _onPostsChangedListeners) {
      listener();
    }
  }

  /// 외부에서 게시물 변경 알림 트리거
  void notifyPostsChanged() {
    _notifyPostsChanged();
  }

  /// 생성자
  ///
  /// [postService]를 주입받아 사용합니다. 테스트 시 MockPostService를 주입할 수 있습니다.
  PostController({PostService? postService})
    : _postService = postService ?? PostService();

  /// 로딩 상태
  bool get isLoading => _isLoading;

  /// 에러 메시지
  String? get errorMessage => _errorMessage;

  // ============================================
  // 게시물 생성
  // ============================================

  /// 게시물 생성
  ///
  /// 새로운 게시물(사진 + 음성메모)을 생성합니다.
  ///
  /// Parameters:
  /// - [nickName]: 작성자 사용자 ID (String)
  /// - [content]: 게시물 내용 (선택)
  /// - [postFileKey]: 이미지 파일 키
  /// - [audioFileKey]: 음성 파일 키 (선택)
  /// - [categoryIds]: 게시할 카테고리 ID 목록
  /// - [waveformData]: 음성 파형 데이터 (선택)
  /// - [duration]: 음성 길이 (선택)
  ///
  /// Returns: 생성 성공 여부
  ///   - true: 생성 성공
  ///   - false: 생성 실패
  Future<bool> createPost({
    int? userId,
    required String nickName,
    String? content,
    List<String> postFileKey = const [],
    List<String> audioFileKey = const [],
    List<int> categoryIds = const [],
    String? waveformData,
    int? duration,
    double? savedAspectRatio,
    bool? isFromGallery,
    PostType? postType,
  }) async {
    _setLoading(true);
    _clearError();

    // (배포버전 성능) 요청 payload 전체 로그는 프레임 드랍/프리즈를 유발할 수 있어 디버그에서만 출력합니다.
    if (kDebugMode) {
      debugPrint(
        "[PostController]\nuserId: $userId\nnickName: $nickName\ncontent: $content\npostFileKey: $postFileKey\naudioFileKey: $audioFileKey\ncategoryIds: $categoryIds\nwaveformData: $waveformData\nduration: $duration",
      );
    }

    try {
      final result = await _postService.createPost(
        userId: userId,
        nickName: nickName,
        content: content,
        postFileKey: postFileKey,
        audioFileKey: audioFileKey,
        categoryIds: categoryIds,
        waveformData: waveformData,
        duration: duration,
        savedAspectRatio: savedAspectRatio,
        isFromGallery: isFromGallery,
        postType: postType,
      );
      if (kDebugMode) debugPrint("[PostController] 게시물 생성 결과: $result");
      _setLoading(false);
      if (result) _notifyPostsChanged();
      return result;
    } catch (e) {
      _setError('게시물 생성 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  /// 게시물 생성 후 ID 반환 (UI 전용)
  Future<int?> createPostAndReturnId({
    required int userId,
    required String nickName,
    String? content,
    List<int> categoryIds = const [],
    String? postFileKey,
    String? audioFileKey,
    String? waveformData,
    int? duration,
    double? savedAspectRatio,
    bool? isFromGallery,
    PostType? postType,
  }) async {
    debugPrint("[PostController] createPostAndReturnId 호출됨");
    try {
      debugPrint("[PostController] 전달된 nickName: $nickName");
      debugPrint("[PostController] 전달된 content: $content");
      debugPrint("[PostController] 전달된 categoryIds: $categoryIds");
      debugPrint("[PostController] 전달된 postFileKey: $postFileKey");
      debugPrint("[PostController] 전달된 audioFileKey: $audioFileKey");
      debugPrint("[PostController] 전달된 waveformData: $waveformData");
      debugPrint("[PostController] 전달된 duration: $duration");
      return await _postService.createPostAndReturnId(
        userId: userId,
        nickName: nickName,
        content: content,
        categoryIds: categoryIds,
        postFileKey: postFileKey,
        audioFileKey: audioFileKey,
        waveformData: waveformData,
        duration: duration,
        savedAspectRatio: savedAspectRatio,
        isFromGallery: isFromGallery,
        postType: postType,
      );
    } catch (e) {
      _setError('[PostController]게시물 생성 실패: $e');
      return null;
    }
  }

  // ============================================
  // 게시물 조회
  // ============================================

  /// 메인 피드 게시물 조회
  ///
  /// [userId]가 속한 모든 카테고리의 게시물을 조회합니다.
  /// 메인 페이지에 표시할 피드용입니다.
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  /// - [postStatus]: 게시물 상태 (기본값: ACTIVE)
  /// - [page]: 페이지 번호 (기본값: 0)
  ///
  /// Returns: 게시물 목록 (List of Post)
  Future<List<Post>> getAllPosts({
    required int userId,
    PostStatus postStatus = PostStatus.active,
    int page = 0,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final posts = await _postService.getAllPosts(
        userId: userId,
        postStatus: postStatus,
        page: page,
      );
      _setLoading(false);
      return posts;
    } catch (e) {
      _setError('피드 조회 실패: $e');
      _setLoading(false);
      return [];
    }
  }

  /// 카테고리별 게시물 조회
  /// 특정 카테고리에 속한 게시물만 조회합니다.
  ///
  /// Parameters:
  ///   - [categoryId]: 카테고리 ID
  ///   - [userId]: 요청 사용자 ID (권한 확인용)(int)
  ///   - [notificationId]: 알림 ID (선택, 알림에서 접근 시 사용)
  ///     - 알림이 아닌 곳에서 호출할 경우, null을 전달
  ///   - [page]: 페이지 번호 (기본값: 0)
  ///
  /// Returns: 게시물 목록 (List of Post)
  Future<List<Post>> getPostsByCategory({
    required int categoryId,
    required int userId,
    int? notificationId,
    int page = 0,
  }) async {
    // 캐시 키 생성
    final cacheKey = '$userId:$categoryId:$page';

    // 캐시 확인 (만료 안 된 것만)
    final cached = _categoryCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) < _controllerCacheTtl) {
      if (kDebugMode) {
        debugPrint('📦 [PostController] 캐시 히트: $cacheKey');
      }
      return cached.posts;
    }

    _setLoading(true);
    _clearError();

    try {
      final posts = await _postService.getPostsByCategory(
        categoryId: categoryId,
        userId: userId,
        notificationId: notificationId,
        page: page,
      );

      // 캐시 저장
      _categoryCache[cacheKey] = _CachedCategoryPosts(
        posts: posts,
        cachedAt: DateTime.now(),
      );

      _setLoading(false);
      return posts;
    } catch (e) {
      _setError('카테고리 게시물 조회 실패: $e');
      _setLoading(false);

      // 에러 시 만료된 캐시라도 반환
      if (cached != null) {
        if (kDebugMode) {
          debugPrint('⚠️ [PostController] 에러 발생, 만료된 캐시 사용');
        }
        return cached.posts;
      }
      return [];
    }
  }

  /// 게시물 상세 조회
  /// [postId]에 해당하는 게시물의 상세 정보를 조회합니다.
  ///
  /// Parameters:
  ///   - [postId]: 조회할 게시물 ID
  ///
  /// Returns: 게시물 정보 (Post)
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

  /// 게시물 수정
  /// 기존 게시물의 내용을 수정합니다.
  ///
  /// Parameters:
  ///   - [postId]: 수정할 게시물 ID
  ///   - [content]: 변경할 내용 (선택)
  ///   - [postFileKey]: 변경할 이미지 키 (선택)
  ///   - [audioFileKey]: 변경할 음성 키 (선택)
  ///   - [categoryId]: 변경할 카테고리 ID (선택, 단일 값)
  ///   - [waveformData]: 변경할 파형 데이터 (선택)
  ///   - [duration]: 변경할 음성 길이 (선택)
  ///
  /// Returns: 수정 성공 여부
  ///   - true: 수정 성공
  ///   - false: 수정 실패
  Future<bool> updatePost({
    required int postId,
    String? content,
    String? postFileKey,
    String? audioFileKey,
    int? categoryId,
    String? waveformData,
    int? duration,
    bool? isFromGallery,
    double? savedAspectRatio,
    PostType? postType,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _postService.updatePost(
        postId: postId,
        content: content,
        postFileKey: postFileKey,
        audioFileKey: audioFileKey,
        categoryId: categoryId,
        waveformData: waveformData,
        duration: duration,
        isFromGallery: isFromGallery,
        savedAspectRatio: savedAspectRatio,
        postType: postType,
      );
      _setLoading(false);
      if (result) _notifyPostsChanged();
      return result;
    } catch (e) {
      _setError('게시물 수정 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 게시물 상태 변경
  // ============================================

  /// 게시물 상태 변경
  /// - 게시물 삭제는 이 메소드를 사용해서 수행합니다.
  /// - 게시물 영구 삭제는 30일 후, 서버에서 자동으로 처리됩니다.
  ///
  /// Parameters:
  ///   - [postId]: 게시물 ID
  ///   - [postStatus]: 변경할 상태 (ACTIVE, DELETED, INACTIVE)
  ///
  /// Returns: 변경 성공 여부
  Future<bool> setPostStatus({
    required int postId,
    required PostStatus postStatus,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _postService.setPostStatus(
        postId: postId,
        postStatus: postStatus,
      );
      _setLoading(false);
      if (result) _notifyPostsChanged();
      return result;
    } catch (e) {
      _setError('게시물 상태 변경 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 게시물 삭제
  // ============================================

  /// 게시물 삭제
  /// [postId]에 해당하는 게시물을 삭제합니다.
  /// 삭제된 게시물은 휴지통으로 이동됩니다.
  ///
  /// Parameters:
  ///   - [postId]: 삭제할 게시물 ID
  ///
  /// Returns: 삭제 성공 여부
  ///   - true: 삭제 성공
  ///   - false: 삭제 실패
  Future<bool> deletePost(int postId) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await _postService.deletePost(postId);
      _setLoading(false);
      if (result) _notifyPostsChanged();
      return result;
    } catch (e) {
      _setError('게시물 삭제 실패: $e');
      _setLoading(false);
      return false;
    }
  }

  // ============================================
  // 캐시 관리
  // ============================================

  /// 특정 카테고리의 캐시 무효화
  void invalidateCategoryCache(int categoryId) {
    _categoryCache.removeWhere((key, _) => key.contains(':$categoryId:'));
    if (kDebugMode) {
      debugPrint('[PostController] 카테고리 $categoryId 캐시 무효화');
    }
  }

  /// 전체 캐시 초기화
  void clearAllCache() {
    _categoryCache.clear();
    if (kDebugMode) {
      debugPrint('[PostController] 전체 캐시 초기화');
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
    debugPrint("[PostController] 에러 발생: $message");
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}

/// 카테고리별 포스트 캐시 항목 클래스
class _CachedCategoryPosts {
  final List<Post> posts;
  final DateTime cachedAt;

  _CachedCategoryPosts({required this.posts, required this.cachedAt});
}
