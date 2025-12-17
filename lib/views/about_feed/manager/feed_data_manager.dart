import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/category_controller.dart' as api_category;
import '../../../api/controller/post_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/category.dart' as api_model;
import '../../../api/models/post.dart';

class FeedPostItem {
  final Post post;
  final int categoryId;
  final String categoryName;

  const FeedPostItem({
    required this.post,
    required this.categoryId,
    required this.categoryName,
  });
}

class FeedDataManager extends ChangeNotifier {
  List<FeedPostItem> _allPosts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreData = false;

  // 추가: "처음엔 5개만 보여주고, 스크롤 중간쯤에서 더 보여주기"용(네트워크가 아니라 UI 노출만 단계적)
  static const int _pageSize = 5;
  int _visibleCount = 0;

  VoidCallback? _onStateChanged;
  Function(List<FeedPostItem>)? _onPostsLoaded;

  // PostController 구독 관련
  PostController? _postController;
  BuildContext? _context;
  VoidCallback? _postsChangedListener;

  List<FeedPostItem> get allPosts => _allPosts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;
  List<FeedPostItem> get visiblePosts =>
      _allPosts.take(_visibleCount).toList(growable: false);

  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  void setOnPostsLoaded(Function(List<FeedPostItem>)? callback) {
    _onPostsLoaded = callback;
  }

  void _notifyStateChanged() {
    _onStateChanged?.call();
    notifyListeners(); // 추가: Provider 구독 UI가 자동으로 rebuild 되도록
  }

  /// PostController의 게시물 변경을 구독
  void listenToPostController(
    PostController postController,
    BuildContext context,
  ) {
    // 추가: 이미 같은 PostController를 구독 중이면 중복 등록을 막습니다.
    if (_postController == postController && _postsChangedListener != null) {
      return;
    }

    // 추가: 다른 컨트롤러를 다시 구독해야 하면 기존 리스너부터 해제합니다.
    detachFromPostController();

    _postController = postController;
    _context = context;

    _postsChangedListener = () {
      if (_context != null && _context!.mounted) {
        debugPrint('[FeedDataManager] 게시물 변경 감지, 피드 새로고침');
        // 추가: 게시물이 변경된 경우에는 서버에서 다시 받아오도록 강제 새로고침합니다.
        unawaited(loadUserCategoriesAndPhotos(_context!, forceRefresh: true));
      }
    };

    _postController?.addPostsChangedListener(_postsChangedListener!);
  }

  // 추가: forceRefresh=false면 이미 캐싱된 목록을 그대로 재사용(피드 재방문 시 쉬머/로딩 최소화)
  Future<void> loadUserCategoriesAndPhotos(
    BuildContext context, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _allPosts.isNotEmpty) {
      _isLoading = false;
      if (_visibleCount == 0) {
        _visibleCount =
            _allPosts.length < _pageSize ? _allPosts.length : _pageSize;
      }
      _hasMoreData = _visibleCount < _allPosts.length;
      _notifyStateChanged();
      return;
    }
    await _loadFeed(context, forceRefresh: forceRefresh);
  }

  Future<void> loadMorePhotos(BuildContext context) async {
    if (_isLoadingMore) return;
    if (!_hasMoreData) return;
    _isLoadingMore = true;
    _notifyStateChanged();
    // 추가: 이미 로드된 목록에서 "더 보여주기"만 수행(새 네트워크 요청 없음)
    final next = _visibleCount + _pageSize;
    _visibleCount = next > _allPosts.length ? _allPosts.length : next;
    _hasMoreData = _visibleCount < _allPosts.length;
    _isLoadingMore = false;
    _notifyStateChanged();
  }

  Future<void> _loadFeed(
    BuildContext context, {
    bool forceRefresh = false,
  }) async {
    final isInitialLoad = !_isLoadingMore;
    try {
      if (isInitialLoad) {
        _isLoading = true;
        _hasMoreData = false;
        _notifyStateChanged();
      }

      final userController = Provider.of<UserController>(
        context,
        listen: false,
      );
      final categoryController = Provider.of<api_category.CategoryController>(
        context,
        listen: false,
      );
      final postController = Provider.of<PostController>(
        context,
        listen: false,
      );

      if (userController.currentUser == null) {
        await userController.tryAutoLogin();
      }
      final currentUser = userController.currentUser;
      if (currentUser == null) {
        throw Exception('로그인이 필요합니다.');
      }

      // NOTE: 피드 캐싱/노출(5개씩)은 `loadUserCategoriesAndPhotos`와 `_visibleCount`에서 담당합니다.

      // 사용자 카테고리 로드
      final categories = await categoryController.loadCategories(
        currentUser.id,
        filter: api_model.CategoryFilter.all,
        forceReload: forceRefresh,
      );

      if (categories.isEmpty) {
        _allPosts = [];
        _isLoading = false;
        _notifyStateChanged();
        return;
      }

      final List<FeedPostItem> combined = [];
      for (final category in categories) {
        try {
          // 카테고리별 게시물 로드
          final posts = await postController.getPostsByCategory(
            categoryId: category.id,
            userId: currentUser.id,
          );
          combined.addAll(
            posts.map(
              (post) => FeedPostItem(
                post: post,
                categoryId: category.id,
                categoryName: category.name,
              ),
            ),
          );
        } catch (e) {
          debugPrint('[FeedDataManager] 카테고리 ${category.id} 로드 실패: $e');
        }
      }

      combined.sort((a, b) {
        final aTime =
            a.post.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.post.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      _allPosts = combined;
      if (isInitialLoad) {
        _isLoading = false;
      }

      // 추가: 처음엔 5개만 보여주기 (데이터는 캐싱해두고 UI 노출만 단계적으로)
      _visibleCount = _allPosts.length < _pageSize ? _allPosts.length : _pageSize;
      _hasMoreData = _visibleCount < _allPosts.length;

      _notifyStateChanged();
      _onPostsLoaded?.call(combined);
    } catch (e) {
      debugPrint('[FeedDataManager] 피드 로드 실패: $e');
      _allPosts = [];
      _hasMoreData = false;
      _visibleCount = 0;
      if (isInitialLoad) {
        _isLoading = false;
      }
      _notifyStateChanged();
    }
  }

  void removePhoto(int index) {
    if (index >= 0 && index < _allPosts.length) {
      _allPosts.removeAt(index);
      _notifyStateChanged();
    }
  }

  FeedPostItem? getPostData(int index) {
    if (index >= 0 && index < _allPosts.length) {
      return _allPosts[index];
    }
    return null;
  }

  // 추가: 전역 Provider로 쓰기 때문에, 화면 dispose 시에는 캐시를 지우지 않고 리스너만 해제합니다.
  void detachFromPostController() {
    if (_postsChangedListener == null || _postController == null) return;
    _postController!.removePostsChangedListener(_postsChangedListener!);
    _postsChangedListener = null;
    _postController = null;
    _context = null;
  }

  @override
  void dispose() {
    detachFromPostController();
    super.dispose();
  }
}
