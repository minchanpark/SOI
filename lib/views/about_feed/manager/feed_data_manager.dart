import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/category_controller.dart' as api_category;
import '../../../api/controller/friend_controller.dart';
import '../../../api/controller/post_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/category.dart' as api_model;
import '../../../api/models/friend.dart';
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
  List<FeedPostItem> _allPosts = []; // 전체 피드 게시물을 담는 리스트입니다.
  bool _isLoading = true; // 피드 전체 로딩 상태
  bool _isLoadingMore = false; // 추가 로딩 상태
  bool _hasMoreData = false;

  // "처음엔 5개만 보여주고, 스크롤 중간쯤에서 더 보여주기"용(네트워크가 아니라 UI 노출만 단계적으로)
  static const int _pageSize = 5; // 한 번에 보여줄 게시물 수 --> 5개
  int _visibleCount = 0; // 현재 노출된 게시물 수

  VoidCallback? _onStateChanged;
  Function(List<FeedPostItem>)? _onPostsLoaded;

  // PostController 구독 관련
  PostController? _postController;
  BuildContext? _context;
  VoidCallback? _postsChangedListener;

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
  List<FeedPostItem> get visiblePosts => _allPosts
      .take(_visibleCount)
      .toList(growable: false); // 현재 노출된 게시물 목록을 반환하는 getter

  // ======== 콜백/상태 알림 ===========
  // 포함된 메소드들
  // - setOnStateChanged
  // - setOnPostsLoaded
  // - _notifyStateChanged
  //
  // 메소드의 흐름
  // (외부 설정) setOnStateChanged -> (내부) _notifyStateChanged -> notifyListeners
  // (외부 설정) setOnPostsLoaded -> (내부) loadUserCategoriesAndPhotos -> _onPostsLoaded?.call(...)

  /// 콜백 설정 메소드
  /// 상태 변경 시 호출할 콜백 함수를 설정합니다.
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

  void _notifyStateChanged() {
    _onStateChanged?.call();
    notifyListeners(); // 추가: Provider 구독 UI가 자동으로 rebuild 되도록
  }

  // ======== PostController 구독/해제 ===========
  // 포함된 메소드들
  // - listenToPostController
  // - detachFromPostController
  // - dispose
  //
  // 메소드의 흐름
  // listenToPostController -> (게시물 변경 감지) -> loadUserCategoriesAndPhotos(forceRefresh: true)
  // dispose -> detachFromPostController

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
      if (_context != null && _context!.mounted) {
        debugPrint('[FeedDataManager] 게시물 변경 감지, 피드 새로고침');
        // 게시물이 변경된 경우에는 서버에서 다시 받아오도록 강제 새로고침합니다.
        unawaited(loadUserCategoriesAndPhotos(_context!, forceRefresh: true));
      }
    };

    _postController?.addPostsChangedListener(_postsChangedListener!);
  }

  // 전역 Provider로 쓰기 때문에, 화면 dispose 시에는 캐시를 지우지 않고 리스너만 해제합니다.
  void detachFromPostController() {
    if (_postsChangedListener == null || _postController == null) return;
    _postController!.removePostsChangedListener(_postsChangedListener!);
    _postsChangedListener = null;
    _postController = null;
    _context = null;
  }

  // ======== 피드 로딩(캐시/네트워크) ===========
  // 포함된 메소드들
  // - loadUserCategoriesAndPhotos
  //
  // 메소드의 흐름
  // loadUserCategoriesAndPhotos
  //   -> (캐시 사용) visibleCount/hasMoreData 갱신 -> _notifyStateChanged
  //   -> (서버 로드) loadCategories -> Future.wait(getPostsByCategory...) -> sort -> _notifyStateChanged -> _onPostsLoaded?.call(...)

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
    if (!forceRefresh && _allPosts.isNotEmpty) {
      _isLoading = false;

      // 현재 로드된 게시물의 개수가 0개라면
      if (_visibleCount == 0) {
        // 처음 로드 시에는 5개만 보여주기
        _visibleCount = _allPosts.length < _pageSize
            ? _allPosts.length
            : _pageSize;
      }
      _hasMoreData = _visibleCount < _allPosts.length;
      _notifyStateChanged();
      return;
    }

    /// 피드를 로드하는 메소드입니다.
    /// 사용자 카테고리별로 게시물을 불러와서 결합하고 정렬합니다.
    ///
    /// Parameters:
    /// - [context]: 빌드 컨텍스트
    /// - [forceRefresh]: true면 서버에서 강제 새로고침
    final isInitialLoad = !_isLoadingMore; // 처음 로드하는 것인지의 여부를 체크합니다.
    try {
      if (isInitialLoad) {
        _isLoading = true; // 처음 로드하는 경우라면, 로딩 상태를 설정합니다.
        _hasMoreData = false; // 더 보여줄 데이터 없음으로 초기화
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
      final friendController = Provider.of<FriendController>(
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

      // 피드 캐싱/노출(5개씩)은 `loadUserCategoriesAndPhotos`와 `_visibleCount`에서 담당합니다.
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

      // 카테고리별 게시물을 "병렬"로 로드해서 결합합니다.
      final combinedLists = await Future.wait(
        categories.map((category) async {
          try {
            // 카테고리별 게시물 로드
            final posts = await postController.getPostsByCategory(
              categoryId: category.id,
              userId: currentUser.id,
            );

            // 게시물과 카테고리 정보를 결합
            return posts
                .map(
                  (post) => FeedPostItem(
                    post: post,
                    categoryId: category.id,
                    categoryName: category.name,
                  ),
                )
                .toList(growable: false);
          } catch (e) {
            debugPrint('[FeedDataManager] 카테고리 ${category.id} 로드 실패: $e');
            return const <FeedPostItem>[];
          }
        }),
      );

      final List<FeedPostItem> combined = [
        for (final items in combinedLists) ...items,
      ];

      // 차단 사용자 게시물 필터링
      final blockedUsers = await friendController.getAllFriends(
        userId: currentUser.id,
        status: FriendStatus.blocked,
      );
      if (blockedUsers.isNotEmpty) {
        final blockedIds =
            blockedUsers.map((user) => user.userId).toSet();
        combined.removeWhere(
          (item) => blockedIds.contains(item.post.nickName),
        );
      }

      // 게시물 작성일 기준 내림차순 정렬
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

      // 처음엔 5개만 보여주기 (데이터는 캐싱해두고 UI 노출만 단계적으로)
      _visibleCount = _allPosts.length < _pageSize
          ? _allPosts.length
          : _pageSize;

      // 더 보여줄 게시물이 남았는지 여부 업데이트
      _hasMoreData = _visibleCount < _allPosts.length;

      _notifyStateChanged(); // 상태 변경 알림
      _onPostsLoaded?.call(combined); // 로드 완료 콜백 호출
    } catch (e) {
      debugPrint('[FeedDataManager] 피드 로드 실패: $e');
      _allPosts = []; //
      _hasMoreData = false;
      _visibleCount = 0;
      if (isInitialLoad) {
        _isLoading = false;
      }
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
    _visibleCount = next > _allPosts.length
        ? _allPosts.length
        : next; // 최대 전체 게시물 수를 넘지 않도록 제한
    _hasMoreData = _visibleCount < _allPosts.length; // 더 보여줄 게시물이 남았는지 여부 업데이트
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
      _allPosts.removeAt(index); // 해당 인덱스의 게시물 데이터 제거
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

    _allPosts = filtered;
    if (_visibleCount > _allPosts.length) {
      _visibleCount = _allPosts.length;
    }
    _hasMoreData = _visibleCount < _allPosts.length;
    _notifyStateChanged();
  }

  @override
  void dispose() {
    detachFromPostController();
    super.dispose();
  }
}
