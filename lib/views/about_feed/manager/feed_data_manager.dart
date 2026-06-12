import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/category_controller.dart' as api_category;
import '../../../api/controller/friend_controller.dart';
import '../../../api/controller/post_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/category.dart' as api_model;
import '../../../api/models/friend.dart';
import '../../../api/models/post.dart';

/// 피드 화면에서 게시물 데이터를 관리하는 클래스입니다.
/// 사용자 카테고리별로 게시물을 로드하고, 캐싱하며, 게시물 변경을 감지하여 피드를 새로고침하는 역할을 합니다.
/// 또한, 페이징을 위한 추가 로드 기능과 게시물 접근/삭제 기능도 제공합니다.
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

/// 카테고리별 게시물 fetch 결과를 잠정 피드 후보와 최종 집계에 함께 쓰기 위한 래퍼입니다.
class _CategoryFeedLoadResult {
  final int categoryId;
  final List<FeedPostItem> items;
  final bool success;

  const _CategoryFeedLoadResult({
    required this.categoryId,
    required this.items,
    required this.success,
  });
}

class FeedDataManager extends ChangeNotifier {
  List<FeedPostItem> _allPosts =
      const <FeedPostItem>[]; // 전체 피드 게시물을 담는 리스트입니다.
  bool _isLoading = true; // 피드 전체 로딩 상태
  bool _isLoadingMore = false; // 추가 로딩 상태
  bool _hasMoreData = false;

  // "처음엔 5개만 보여주고, 스크롤 중간쯤에서 더 보여주기"용(네트워크가 아니라 UI 노출만 단계적으로)
  static const int _pageSize = 5; // 한 번에 보여줄 게시물 수 --> 5개
  int _visibleCount = 0; // 현재 노출된 게시물 수
  List<FeedPostItem> _visiblePosts = const <FeedPostItem>[]; // 현재 노출된 게시물 캐시

  VoidCallback? _onStateChanged; // 상태 변경 콜백 --> 상태가 변경되면 호출
  Function(List<FeedPostItem>)?
  _onPostsLoaded; // 피드 게시물 로드 완료 콜백 --> 게시물이 로드되면 호출

  PostController? _postController; // 구독 중인 PostController
  BuildContext? _context;
  VoidCallback? _postsChangedListener; // 게시물 변경 감지 리스너
  int? _lastUserId; // 마지막으로 로드한 사용자의 ID

  // 게시물 변경 감지 후 탭이 보이지 않는 상태라면 새로고침을 지연시키는 플래그
  bool _pendingPostRefresh = false;

  // ======== 조회(Getter) ===========
  // 포함된 메소드들
  // - allPosts
  // - isLoading
  // - isLoadingMore
  // - hasMoreData
  // - visiblePosts

  List<FeedPostItem> get allPosts => _allPosts; // 전체 피드 게시물 목록을 반환하는 getter
  bool get isLoading => _isLoading; // 피드 전체 로딩 상태를 반환하는 getter
  bool get isLoadingMore => _isLoadingMore; // 추가 로딩 상태를 반환하는 getter
  bool get hasMoreData => _hasMoreData; // 더 보여줄 데이터가 있는지 여부를 반환하는 getter
  List<FeedPostItem> get visiblePosts =>
      _visiblePosts; // 현재 노출된 게시물 목록을 반환하는 getter

  /// 상태 변경 콜백 설정 메소드
  /// 상태가 변경될 때 호출할 콜백 함수를 설정합니다.
  /// 예를 들어, 피드 데이터가 로드되거나 게시물이 변경될 때 UI를 업데이트하기 위해 사용할 수 있습니다.
  ///
  /// Parameters:
  /// - [callback]: 상태 변경 시 호출할 콜백 함수
  void setOnStateChanged(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  /// 콜백 설정 메소드
  /// 게시물 로드 완료 시 호출할 콜백 함수를 설정합니다.
  ///
  /// Parameters:
  /// - [callback]: 게시물 로드 완료 시 호출할 콜백 함수
  void setOnPostsLoaded(Function(List<FeedPostItem>)? callback) {
    _onPostsLoaded = callback;
  }

  /// 상태 변경 알림 메소드
  /// 피드 데이터가 변경될 때마다 이 메소드를 호출해서 등록된 상태 변경 콜백을 호출하고,
  /// ChangeNotifier의 notifyListeners()를 호출해서 UI가 업데이트되도록 합니다.
  void _notifyStateChanged() {
    _onStateChanged?.call();
    notifyListeners();
  }

  void _syncVisiblePosts({int? visibleCount}) {
    final desiredVisibleCount = visibleCount ?? _visibleCount;
    final boundedVisibleCount = math.min(
      math.max(desiredVisibleCount, 0),
      _allPosts.length,
    );

    _visibleCount = boundedVisibleCount;
    _hasMoreData = _visibleCount < _allPosts.length;
    _visiblePosts = _visibleCount == 0
        ? const <FeedPostItem>[]
        : List<FeedPostItem>.unmodifiable(_allPosts.take(_visibleCount));
  }

  void _replaceAllPosts(List<FeedPostItem> posts, {int? visibleCount}) {
    _allPosts = posts.isEmpty
        ? const <FeedPostItem>[]
        : List<FeedPostItem>.unmodifiable(posts);
    _syncVisiblePosts(visibleCount: visibleCount);
  }

  void _restorePreviousPosts({
    required List<FeedPostItem> posts,
    required List<FeedPostItem> visiblePosts,
    required int visibleCount,
  }) {
    _allPosts = posts;
    _visiblePosts = visiblePosts;
    _visibleCount = visibleCount;
    _hasMoreData = _visibleCount < _allPosts.length;
  }

  /// 잠정 후보 목록을 스냅샷으로 넘겨 태그 prefetch가 전체 집계 완료를 기다리지 않게 합니다.
  void _emitLoadedPostCandidates(List<FeedPostItem> posts) {
    if (_onPostsLoaded == null) {
      return;
    }

    final snapshot = posts.isEmpty
        ? const <FeedPostItem>[]
        : List<FeedPostItem>.unmodifiable(posts);
    _onPostsLoaded?.call(snapshot);
  }

  /// provisional/final 집계 모두 차단 사용자 제거와 최신순 정렬을 같은 기준으로 맞춥니다.
  List<FeedPostItem> _sortAndFilterFeedItems(
    List<FeedPostItem> posts,
    Set<String> blockedNicknames,
  ) {
    if (posts.isEmpty) {
      return const <FeedPostItem>[];
    }

    final filtered = blockedNicknames.isEmpty
        ? List<FeedPostItem>.from(posts)
        : posts
              .where((item) => !blockedNicknames.contains(item.post.nickName))
              .toList(growable: true);
    filtered.sort((a, b) {
      final aTime = a.post.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.post.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return filtered;
  }

  /// 카테고리별 fetch 실패를 로컬 결과로 감싸 한 카테고리 지연이 전체 피드를 막지 않게 합니다.
  Future<_CategoryFeedLoadResult> _loadCategoryPosts({
    required api_model.Category category,
    required PostController postController,
    required int userId,
    required bool forceRefresh,
  }) async {
    try {
      final posts = await postController.getPostsByCategory(
        categoryId: category.id,
        userId: userId,
        notifyLoading: false,
        forceRefresh: forceRefresh,
      );

      return _CategoryFeedLoadResult(
        categoryId: category.id,
        success: true,
        items: posts
            .map(
              (post) => FeedPostItem(
                post: post,
                categoryId: category.id,
                categoryName: category.name,
              ),
            )
            .toList(growable: false),
      );
    } catch (e) {
      debugPrint('[FeedDataManager] 카테고리 ${category.id} 로드 실패: $e');
      return _CategoryFeedLoadResult(
        categoryId: category.id,
        items: const <FeedPostItem>[],
        success: false,
      );
    }
  }

  /// PostController의 게시물 변경을 구독
  void listenToPostController(
    PostController postController,
    BuildContext context,
  ) {
    // 이미 같은 PostController를 구독 중이면 중복 등록을 막습니다.
    if (_postController == postController && _postsChangedListener != null) {
      return;
    }

    // 다른 컨트롤러를 다시 구독해야 하면 기존 리스너부터 해제합니다.
    detachFromPostController();

    _postController = postController;
    _context = context;

    _postsChangedListener = () {
      final feedContext = _context;
      if (feedContext == null || !feedContext.mounted) {
        return;
      }

      if (!TickerMode.valuesOf(feedContext).enabled) {
        _pendingPostRefresh = true;
        return;
      }

      _pendingPostRefresh = false;

      // 게시물이 변경된 경우에는 서버에서 다시 받아오도록 강제 새로고침합니다.
      unawaited(loadUserCategoriesAndPhotos(feedContext, forceRefresh: true));
    };

    // PostController에 게시물 변경 리스너를 등록합니다.
    _postController?.addPostsChangedListener(_postsChangedListener!);
  }

  // 전역 Provider로 쓰기 때문에, 화면 dispose 시에는 캐시를 지우지 않고 리스너만 해제합니다.
  void detachFromPostController() {
    if (_postsChangedListener == null || _postController == null) return;
    _postController!.removePostsChangedListener(_postsChangedListener!);
    _postsChangedListener = null;
    _postController = null;
    _context = null;
    _pendingPostRefresh = false;
  }

  /// 탭이 보이지 않는 상태에서 게시물 변경이 감지된 경우,
  /// 탭이 다시 보이는 시점에 새로고침을 수행하는 메소드입니다.
  void refreshIfPendingVisible() {
    if (!_pendingPostRefresh) return;
    if (_context == null || !_context!.mounted) return;
    if (!TickerMode.valuesOf(_context!).enabled) return;

    _pendingPostRefresh = false; // 새로고침을 수행하므로 플래그를 초기화합니다.
    unawaited(loadUserCategoriesAndPhotos(_context!, forceRefresh: true));
  }

  // ======== 피드 로딩(캐시/네트워크) ===========
  // 포함된 메소드들
  // - loadUserCategoriesAndPhotos
  //
  // 메소드의 흐름
  // loadUserCategoriesAndPhotos
  //   -> (캐시 사용) visibleCount/hasMoreData 갱신 -> _notifyStateChanged
  //   -> (서버 로드) loadCategories -> 카테고리별 잠정 후보 emit -> sort/확정 -> _notifyStateChanged -> _onPostsLoaded?.call(...)

  /// 피드용 사용자 카테고리 및 게시물 로드 메소드
  /// forceRefresh=false면 이미 캐싱된 목록을 그대로 재사용(피드 재방문 시 쉬머/로딩 최소화)
  ///
  /// Parameters:
  /// - [context]: 빌드 컨텍스트
  /// - [forceRefresh]: true면 서버에서 강제 새로고침
  Future<void> loadUserCategoriesAndPhotos(
    BuildContext context, {
    bool forceRefresh = false,
  }) async {
    /// 피드를 로드하는 메소드입니다.
    /// 사용자 카테고리별로 게시물을 불러와서 결합하고 정렬합니다.
    ///
    /// Parameters:
    /// - [context]: 빌드 컨텍스트
    /// - [forceRefresh]: true면 서버에서 강제 새로고침
    var hadCachedPosts = _allPosts.isNotEmpty;
    var previousPosts = _allPosts;
    var previousVisiblePosts = _visiblePosts;
    var previousVisibleCount = _visibleCount;

    try {
      final userController = Provider.of<UserController>(
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

      // 유저가 변경되면 캐시를 초기화하고 강제 새로고침합니다.
      if (_lastUserId != null && _lastUserId != currentUser.id) {
        reset(notify: false);
        forceRefresh = true;
      }
      _lastUserId = currentUser.id;

      hadCachedPosts = _allPosts.isNotEmpty;
      previousPosts = _allPosts;
      previousVisiblePosts = _visiblePosts;
      previousVisibleCount = _visibleCount;

      if (!forceRefresh && _allPosts.isNotEmpty) {
        _isLoading = false;

        _syncVisiblePosts(
          visibleCount: _visibleCount == 0 ? _pageSize : _visibleCount,
        );
        _notifyStateChanged();
        _emitLoadedPostCandidates(_allPosts);
        return;
      }

      if (!hadCachedPosts) {
        _isLoading = true; // 처음 로드하는 경우라면, 로딩 상태를 설정합니다.
        _hasMoreData = false; // 더 보여줄 데이터 없음으로 초기화
        _notifyStateChanged();
      }

      if (!context.mounted) return;

      final categoryController = Provider.of<api_category.CategoryController>(
        context,
        listen: false,
      );
      final friendController = Provider.of<FriendController>(
        context,
        listen: false,
      );
      final postController = Provider.of<PostController>(
        context,
        listen: false,
      );

      final blockedUsersFuture = friendController.getAllFriends(
        userId: currentUser.id,
        status: FriendStatus.blocked,
      );

      // 피드 캐싱/노출(5개씩)은 `loadUserCategoriesAndPhotos`와 `_visibleCount`에서 담당합니다.
      // 사용자 카테고리 로드
      final categories = await categoryController.loadCategories(
        currentUser.id,
        filter: api_model.CategoryFilter.all,
        forceReload: forceRefresh,
      );

      if (categories.isEmpty) {
        _replaceAllPosts(const <FeedPostItem>[], visibleCount: 0);
        _isLoading = false;
        _notifyStateChanged();
        return;
      }

      final blockedUsers = await blockedUsersFuture;
      final blockedNicknames = blockedUsers.map((user) => user.userId).toSet();
      final combinedByCategory = <int, List<FeedPostItem>>{};
      var hadCategoryLoadFailure = false;

      // 카테고리별 게시물은 병렬로 요청하되, 완료되는 순서대로 잠정 후보를 먼저 전달합니다.
      final categoryLoadTasks = categories
          .map(
            (category) => _loadCategoryPosts(
              category: category,
              postController: postController,
              userId: currentUser.id,
              forceRefresh: forceRefresh,
            ),
          )
          .toList(growable: false);

      await for (final result in Stream<_CategoryFeedLoadResult>.fromFutures(
        categoryLoadTasks,
      )) {
        hadCategoryLoadFailure = hadCategoryLoadFailure || !result.success;
        combinedByCategory[result.categoryId] = result.items;

        final provisionalCombined = _sortAndFilterFeedItems(
          combinedByCategory.values
              .expand((items) => items)
              .toList(growable: false),
          blockedNicknames,
        );
        if (provisionalCombined.isNotEmpty) {
          _emitLoadedPostCandidates(provisionalCombined);
        }
      }

      final combined = _sortAndFilterFeedItems(
        combinedByCategory.values
            .expand((items) => items)
            .toList(growable: false),
        blockedNicknames,
      );

      if (combined.isEmpty && hadCachedPosts && hadCategoryLoadFailure) {
        _restorePreviousPosts(
          posts: previousPosts,
          visiblePosts: previousVisiblePosts,
          visibleCount: previousVisibleCount,
        );
        _isLoading = false;
        _notifyStateChanged();
        return;
      }

      _replaceAllPosts(
        combined,
        visibleCount: hadCachedPosts && previousVisibleCount > 0
            ? previousVisibleCount
            : _pageSize,
      );
      _isLoading = false;

      _notifyStateChanged(); // 상태 변경 알림
      _emitLoadedPostCandidates(_allPosts); // 로드 완료 콜백 호출
    } catch (e) {
      debugPrint('[FeedDataManager] 피드 로드 실패: $e');

      if (previousPosts.isNotEmpty) {
        _restorePreviousPosts(
          posts: previousPosts,
          visiblePosts: previousVisiblePosts,
          visibleCount: previousVisibleCount,
        );
      } else {
        _replaceAllPosts(const <FeedPostItem>[], visibleCount: 0);
      }

      _isLoading = false;
      _notifyStateChanged();
    }
  }

  // ======== 추가 노출(페이징: UI만) ===========
  // 포함된 메소드들
  // - loadMorePhotos
  //
  // 메소드의 흐름
  // loadMorePhotos -> visibleCount 증가 -> hasMoreData 갱신 -> _notifyStateChanged

  /// post를 추가로 로드하는 메소드입니다.
  /// 현재 로드된 목록에서 "더 보여주기"만 수행(새 네트워크 요청 없음)
  ///
  /// Parameters:
  /// - [context]: 빌드 컨텍스트
  Future<void> loadMorePhotos(BuildContext context) async {
    if (_isLoadingMore) return;
    if (!_hasMoreData) return;
    _isLoadingMore = true;
    _notifyStateChanged();
    // 이미 로드된 목록에서 "더 보여주기"만 수행(새 네트워크 요청 없음)
    final next = _visibleCount + _pageSize; // 다음으로 보여줄 게시물 수 --> 기존 포스트 개수 + 5개
    _syncVisiblePosts(visibleCount: next);
    _isLoadingMore = false; // 로딩 상태 해제
    _notifyStateChanged(); // 상태 변경 알림
  }

  // ======== 게시물 접근/삭제(로컬 캐시) ===========
  // 포함된 메소드들
  // - getPostData
  // - removePhoto
  //
  // 메소드의 흐름
  // getPostData -> _allPosts[index] 반환
  // removePhoto -> _allPosts.removeAt -> _notifyStateChanged

  /// 특정 인덱스의 피드 게시물 데이터를 반환합니다.
  ///
  /// Parameters:
  /// - [index]: 조회할 게시물의 인덱스
  FeedPostItem? getPostData(int index) {
    if (index >= 0 && index < _allPosts.length) {
      return _allPosts[index]; // 해당 인덱스의 게시물 데이터 반환
    }
    return null;
  }

  /// 특정 인덱스의 피드 게시물을 제거합니다.
  /// _allPosts에서 해당 인덱스의 게시물 데이터를 삭제하고 상태 변경을 알립니다.
  ///
  /// Parameters:
  /// - [index]: 제거할 게시물의 인덱스
  void removePhoto(int index) {
    if (index >= 0 && index < _allPosts.length) {
      final nextPosts = List<FeedPostItem>.of(_allPosts)..removeAt(index);
      _replaceAllPosts(nextPosts, visibleCount: _visibleCount);
      _notifyStateChanged(); // 상태 변경 알림
    }
  }

  /// 닉네임 기준으로 피드에서 게시물 제거
  void removePostsByNickname(String nickName) {
    if (_allPosts.isEmpty) return;
    final filtered = _allPosts
        .where((item) => item.post.nickName != nickName)
        .toList(growable: false);
    if (filtered.length == _allPosts.length) return;

    _replaceAllPosts(filtered, visibleCount: _visibleCount);
    _notifyStateChanged();
  }

  /// 피드 캐시 및 상태 초기화
  /// 피드의 상태를 초기화하고, 필요시 상태 변경 알림을 호출합니다.
  ///
  /// Parameters:
  /// - [notify]: true면 상태 변경 알림 호출
  void reset({bool notify = true}) {
    _replaceAllPosts(const <FeedPostItem>[], visibleCount: 0);
    _isLoading = false;
    _isLoadingMore = false;
    _lastUserId = null;
    _pendingPostRefresh = false;
    if (notify) {
      _notifyStateChanged();
    }
  }

  @override
  void dispose() {
    detachFromPostController();
    super.dispose();
  }
}
