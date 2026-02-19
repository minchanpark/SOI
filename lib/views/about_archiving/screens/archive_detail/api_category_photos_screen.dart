import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:soi/views/about_archiving/screens/category_edit/category_editor_screen.dart';
import 'package:soi/views/about_archiving/widgets/api_category_members_bottom_sheet.dart';
import 'package:soi/views/about_friends/friend_list_add_screen.dart';

import '../../../../api/controller/category_controller.dart';
import '../../../../api/controller/friend_controller.dart';
import '../../../../api/controller/post_controller.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../api/models/category.dart';
import '../../../../api/models/friend.dart';
import '../../../../api/models/post.dart';
import '../../../../api/models/user.dart';
import '../../../../theme/theme.dart';
import '../../../../utils/app_route_observer.dart';
import '../../../../utils/video_thumbnail_cache.dart';
import 'widgets/category_photos_header+body/api_category_header_image_prefetch.dart';
import 'widgets/category_photos_header+body/api_category_photos_body_slivers.dart';
import 'widgets/category_photos_header+body/api_category_photos_header.dart';

import 'package:flutter/foundation.dart' as foundation show kDebugMode;

/// 카테고리 사진 화면
/// 카테고리에 속한 사진(포스트)을 그리드 형태로 보여주는 화면입니다.
/// 사용자는 이 화면에서 카테고리 멤버를 확인하고, 카테고리를 편집할 수 있습니다.
///
/// 주요 기능:
/// - 카테고리에 속한 사진(포스트) 목록을 로드하여 그리드로 표시
/// - 로딩, 에러, 빈 상태에 따른 UI 표시
/// - 당겨서 새로고침 기능
/// - 자동 새로고침 타이머 (30분마다)
/// - 카테고리 멤버 확인 및 친구 추가 기능
/// - 카테고리 편집 화면으로 이동 기능
///
/// Parameters:
/// - [category]: 사진을 보여줄 카테고리 정보
///
/// Returns:
/// - [ApiCategoryPhotosScreen]: 카테고리에 속한 사진 그리드 화면을 표시하는 StatefulWidget
class ApiCategoryPhotosScreen extends StatefulWidget {
  final Category category;
  final CategoryHeaderImagePrefetch? prefetchedHeaderImage;
  final String? entryHeroTag;

  const ApiCategoryPhotosScreen({
    super.key,
    required this.category,
    this.prefetchedHeaderImage,
    this.entryHeroTag,
  });

  @override
  State<ApiCategoryPhotosScreen> createState() =>
      _ApiCategoryPhotosScreenState();
}

class _ApiCategoryPhotosScreenState extends State<ApiCategoryPhotosScreen>
    with RouteAware {
  static const Duration _cacheTtl = Duration(minutes: 30); // 캐시 만료 시간
  static const int _kMaxCategoryPostsPages = 50; // 페이지 무한 조회 방지 안전 가드
  static final Map<String, _CategoryPostsCacheEntry> _categoryPostsCache =
      {}; // 카테고리별 포스트 캐시를 관리하는 맵
  static final Map<int, CategoryHeaderImagePrefetch> _headerImageMemoryCache =
      {}; // 카테고리 ID별 헤더 이미지 프리페치 페이로드를 메모리에 캐싱하는 맵

  bool _isLoading = true; // 로딩 상태
  String? _errorMessageKey; // 에러 메시지 키
  List<Post> _posts = []; // 로드된 포스트 목록
  Category? _category; // 갱신된 카테고리 정보
  CategoryHeaderImagePrefetch? _headerImagePrefetch;

  Timer? _autoRefreshTimer; // 자동 새로고침 타이머
  static const Duration _autoRefreshInterval = Duration(
    minutes: 30,
  ); // 자동 새로고침 간격

  PostController? postController;
  UserController? userController;
  FriendController? friendController;
  VoidCallback? _postsChangedListener; // 포스트 변경을 감지하는 리스너
  int _pagingGeneration = 0; // 새 로드 시작 시 기존 백그라운드 페이징 무효화
  bool _isBackgroundPaging = false; // 백그라운드에서 페이지를 로드 중인지 여부
  bool _hasMorePages = false; // 추가 페이지가 있는지 여부
  int _nextPage = 1; // 다음에 로드할 페이지 번호
  final Set<int> _seenPostIds = <int>{};
  Set<String> _blockedIds = <String>{};
  bool _isRouteVisible = true; // 현재 라우트가 사용자에게 보이는 상태인지 여부
  bool _needsRefreshOnVisible =
      false; // 보이지 않는 상태에서 변경 감지 시, 복귀 시 1회 새로고침이 필요한지 여부
  final Set<int> _pendingDeletedPostIdsFromDetail =
      <int>{}; // 상세에서 전달된 삭제 결과를 안전 시점에 반영하기 위한 임시 버퍼
  Timer? _deferredVisibleRefreshTimer;
  bool _isRouteObserverSubscribed = false; // RouteObserver 구독 상태
  ModalRoute<void>? _subscribedRoute; // 현재 구독 중인 라우트

  Category get _currentCategory => _category ?? widget.category;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeRouteObserverIfNeeded(); // 라우트 옵저버 구독
  }

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _headerImagePrefetch = _resolveInitialHeaderImagePrefetch();

    // 화면이 렌더링된 후 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_headerImagePrefetch != null) {
        unawaited(_precacheHeaderImageIfNeeded(_headerImagePrefetch!));
      }

      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );
      categoryController.markCategoryAsViewed(
        _currentCategory.id,
      ); // 카테고리를 본 것으로 표시

      // 리스너 등록을 데이터 로딩 전에 수행하여 타이밍 이슈 방지
      // 게시물 추가 알림을 놓치지 않도록 즉시 등록
      postController = Provider.of<PostController>(context, listen: false);
      userController = Provider.of<UserController>(context, listen: false);
      friendController = Provider.of<FriendController>(context, listen: false);
      _attachPostChangedListenerIfNeeded();

      await _loadPosts(); // 초기 데이터 로드
      _startAutoRefreshTimer(); // 자동 새로고침 타이머 시작
    });
  }

  // Provider가 관리하는 컨트롤러는 dispose하지 않음
  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _deferredVisibleRefreshTimer?.cancel();
    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
      _isRouteObserverSubscribed = false;
    }

    // 포스트 변경 리스너 제거
    if (_postsChangedListener != null && postController != null) {
      // 리스너가 등록된 경우에만 제거
      postController!.removePostsChangedListener(_postsChangedListener!);
    }
    super.dispose();
  }

  /// 라우트 옵저버 구독
  /// 현재 라우트에 구독되어 있지 않다면 구독을 시작합니다.
  /// 이미 구독 중인 경우에는 아무 작업도 수행하지 않습니다.
  void _subscribeRouteObserverIfNeeded() {
    final route = ModalRoute.of(context);
    if (route == null) return;

    final modalRoute = route as ModalRoute<void>;

    if (_isRouteObserverSubscribed && _subscribedRoute == modalRoute) {
      return;
    }

    if (_isRouteObserverSubscribed) {
      appRouteObserver.unsubscribe(this);
      _isRouteObserverSubscribed = false;
    }

    _subscribedRoute = modalRoute;
    appRouteObserver.subscribe(this, modalRoute);
    _isRouteObserverSubscribed = true;
  }

  @override
  void didPush() {
    _isRouteVisible = true;
  }

  @override
  void didPushNext() {
    _isRouteVisible = false;
  }

  @override
  void didPop() {
    _isRouteVisible = false;
  }

  @override
  void didPopNext() {
    _isRouteVisible = true;
    _applyPendingDeletedPostsFromDetail();
    if (!_needsRefreshOnVisible) return;

    // 상세 -> 목록 복귀 직후 Hero/레이아웃 안정화를 위해 약간 지연 후 새로고침합니다.
    _deferredVisibleRefreshTimer?.cancel();
    _deferredVisibleRefreshTimer = Timer(const Duration(milliseconds: 260), () {
      if (!mounted || !_isRouteVisible || !_needsRefreshOnVisible) return;
      if (_pendingDeletedPostIdsFromDetail.isNotEmpty) {
        _applyPendingDeletedPostsFromDetail();
      }
      if (!_needsRefreshOnVisible) return;
      _needsRefreshOnVisible = false;
      unawaited(_loadPosts(forceRefresh: true));
    });
  }

  CategoryHeaderImagePrefetch? _resolveInitialHeaderImagePrefetch() {
    if (widget.prefetchedHeaderImage != null) {
      _headerImageMemoryCache[_currentCategory.id] =
          widget.prefetchedHeaderImage!;
      return widget.prefetchedHeaderImage;
    }

    final cached = _headerImageMemoryCache[_currentCategory.id];
    if (cached != null) return cached;

    final fallback = CategoryHeaderImagePrefetch.fromCategory(_currentCategory);
    if (fallback != null) {
      _headerImageMemoryCache[_currentCategory.id] = fallback;
    }
    return fallback;
  }

  Future<void> _precacheHeaderImageIfNeeded(
    CategoryHeaderImagePrefetch payload,
  ) {
    return CategoryHeaderImagePrefetchRegistry.prefetchIfNeeded(
      context,
      payload,
    );
  }

  /// 카테고리 내 사진(포스트) 목록 로드
  Future<void> _loadPosts({bool forceRefresh = false}) async {
    if (!mounted) return;
    final loadStopwatch = Stopwatch()..start();
    final generation = ++_pagingGeneration;
    _isBackgroundPaging = false;
    _hasMorePages = false;
    _nextPage = 1;

    try {
      // 현재 사용자 ID 가져오기
      final currentUser = userController!.currentUser;
      if (currentUser == null) {
        setState(() {
          _errorMessageKey = 'common.login_required';
          _isLoading = false;
        });
        return;
      }

      // 캐시 확인
      final cacheKey = _buildCacheKey(
        userId: currentUser.id,
        categoryId: _currentCategory.id,
      );

      // Optimistic UI: 만료된 캐시도 일단 사용
      final cached = _getValidCache(cacheKey, allowExpired: true);
      final freshCache = _getValidCache(cacheKey, allowExpired: false);

      if (cached != null && !forceRefresh) {
        // 즉시 캐시 데이터 표시 (만료 여부와 관계없이)
        if (mounted) {
          setState(() {
            _posts = cached.posts;
            _isLoading = false;
            _errorMessageKey = null;
          });
        }

        // 캐시가 신선하면 여기서 종료
        if (freshCache != null) {
          if (foundation.kDebugMode) {
            debugPrint('[_loadPosts] 신선한 캐시 사용, API 호출 생략');
          }
          return;
        }
        // 만료된 캐시인 경우 백그라운드에서 새로고침 계속 진행
        // (UI는 이미 표시됨)
        if (foundation.kDebugMode) {
          debugPrint('[_loadPosts] 만료된 캐시 표시, 백그라운드 갱신 시작');
        }
      } else {
        setState(() {
          _isLoading = true;
          _errorMessageKey = null;
        });
      }

      // 1단계: page=0 + 차단 유저를 병렬 조회 후 즉시 렌더
      final results = await Future.wait([
        postController!.getPostsByCategory(
          categoryId: _currentCategory.id,
          userId: currentUser.id,
          notificationId: null,
          page: 0,
          notifyLoading: false,
        ),
        friendController!.getAllFriends(
          userId: currentUser.id,
          status: FriendStatus.blocked,
        ),
      ]);
      if (!mounted || generation != _pagingGeneration) return;

      final firstPagePosts = results[0] as List<Post>;
      final blockedUsers = results[1] as List<User>;
      _blockedIds = blockedUsers.map((user) => user.userId).toSet();
      _seenPostIds.clear();

      final firstPageResult = _appendVisiblePosts(firstPagePosts);
      final visiblePosts = firstPageResult.posts;
      _nextPage = 1;
      _hasMorePages = firstPagePosts.isNotEmpty;
      _isBackgroundPaging = _hasMorePages;

      if (mounted) {
        setState(() {
          _posts = visiblePosts;
          _isLoading = false;
        });
      }

      _syncCategoryPostsCache(cacheKey);

      // 비디오 썸네일 프리페칭 (백그라운드)
      _prefetchVideoThumbnails(visiblePosts);

      if (foundation.kDebugMode) {
        debugPrint(
          '[_loadPosts] first-page latency=${loadStopwatch.elapsedMilliseconds}ms '
          'fetched=${firstPagePosts.length} visible=${visiblePosts.length} '
          'blockedRemoved=${firstPageResult.blockedRemoved} '
          'deduped=${firstPageResult.duplicateRemoved}',
        );
      }

      // 2단계: page=1..N 백그라운드 누적
      if (_hasMorePages) {
        unawaited(
          _loadRemainingPagesInBackground(
            generation: generation,
            userId: currentUser.id,
            categoryId: _currentCategory.id,
            cacheKey: cacheKey,
            startedAt: loadStopwatch,
            loadedPages: 1,
            totalFetchedPosts: firstPagePosts.length,
            totalDedupedPosts: firstPageResult.duplicateRemoved,
          ),
        );
      } else {
        _isBackgroundPaging = false;
      }
    } catch (e) {
      debugPrint('[ApiCategoryPhotosScreen] 포스트 로드 실패: $e');
      // Optimistic UI: 에러 시에도 기존 캐시 데이터 유지
      if (mounted) {
        // 캐시된 데이터가 없을 때만 에러 메시지 표시
        if (_posts.isEmpty) {
          setState(() {
            _errorMessageKey = 'archive.photo_load_failed';
            _isLoading = false;
          });
        } else {
          // 캐시된 데이터가 있으면 유지하고 로딩만 종료
          setState(() {
            _isLoading = false;
          });
          if (foundation.kDebugMode) {
            debugPrint('[_loadPosts] 갱신 실패했지만 캐시 데이터 유지');
          }
        }
      }
    }
  }

  /// 새로고침
  Future<void> _onRefresh() async {
    await _loadPosts(forceRefresh: true);
    _startAutoRefreshTimer();
  }

  /// 상세 화면에서 포스트가 삭제된 경우, 해당 포스트를 목록에서 제거하는 메서드
  /// 상세 화면에서 삭제된 포스트의 ID 리스트를 받아,
  /// 현재 화면에 표시된 포스트 목록에서 해당 ID에 해당하는 포스트를 제거합니다.
  ///
  /// Parameters:
  /// - [deletedPostIds]: 상세 화면에서 삭제된 포스트의 ID 리스트로,
  ///                     이 ID들을 기준으로 현재 화면에 표시된 포스트 목록에서 삭제된 포스트를 제거합니다.
  void _onPostsDeletedFromDetail(List<int> deletedPostIds) {
    if (!mounted || deletedPostIds.isEmpty) return;
    _pendingDeletedPostIdsFromDetail.addAll(deletedPostIds);

    // 상세에서 명시적으로 전달된 삭제 결과는 로컬 반영을 신뢰하고
    // 복귀 직후 강제 리로드를 건너뜁니다.
    _needsRefreshOnVisible = false;
    _deferredVisibleRefreshTimer?.cancel();

    if (!_isRouteVisible) return;
    _applyPendingDeletedPostsFromDetail();
  }

  void _applyPendingDeletedPostsFromDetail() {
    if (!mounted || _pendingDeletedPostIdsFromDetail.isEmpty) return;
    final deletedIdSet = _pendingDeletedPostIdsFromDetail.toSet();
    _pendingDeletedPostIdsFromDetail.clear();

    final updatedPosts = _posts
        .where((post) => !deletedIdSet.contains(post.id))
        .toList(growable: false);

    if (updatedPosts.length == _posts.length) return;

    setState(() {
      _posts = updatedPosts;
      _isLoading = false;
      _errorMessageKey = null;
    });

    _seenPostIds
      ..clear()
      ..addAll(updatedPosts.map((post) => post.id));

    final currentUser = userController?.currentUser;
    if (currentUser != null) {
      final cacheKey = _buildCacheKey(
        userId: currentUser.id,
        categoryId: _currentCategory.id,
      );
      _syncCategoryPostsCache(cacheKey);
    }
  }

  /// 백그라운드에서 남은 페이지를 로드하는 메서드
  ///
  /// Parameters:
  /// - [generation]: 현재 페이징 세션을 식별하는 고유 번호로, 새 로드가 시작될 때마다 증가합니다.
  ///                 백그라운드 작업이 오래 걸리는 경우, 사용자가 새로고침을 해서 새로운 로드가 시작될 수 있기 때문에,
  ///                 이 값을 통해 오래된 백그라운드 작업이 결과를 반영하지 않도록 합니다.
  /// - [userId]: 현재 사용자 ID로, API 호출에 필요합니다.
  /// - [categoryId]: 현재 카테고리 ID로, API 호출에 필요합니다.
  /// - [cacheKey]: 현재 카테고리의 캐시 키로, 새로 로드된 포스트 목록을 캐시에 저장할 때 사용합니다.
  /// - [startedAt]: 전체 로드 작업이 시작된 시점의 Stopwatch로, 로드 작업의 지연 시간을 측정하는 데 사용합니다.
  /// - [loadedPages]: 이미 로드된 페이지 수로, 첫 페이지는 이미 로드된 상태에서 이 메서드가 호출되므로 1로 시작합니다.
  /// - [totalFetchedPosts]: 지금까지 API에서 받아온  포스트의 총 수로, 중복 제거 전의 수입니다.
  /// - [totalDedupedPosts]: 지금까지 중복 제거 후 최종적으로 화면에 표시된 포스트의 총 수입니다.
  ///
  /// Returns: `Future<void>`로, 모든 페이지 로드가 완료되거나, 더 이상 로드할 페이지가 없거나, 또는 로드 작업이 무효화될 때 완료됩니다.
  Future<void> _loadRemainingPagesInBackground({
    required int generation,
    required int userId,
    required int categoryId,
    required String cacheKey,
    required Stopwatch startedAt,
    required int loadedPages,
    required int totalFetchedPosts,
    required int totalDedupedPosts,
  }) async {
    var pagesLoaded = loadedPages;
    var fetchedPosts = totalFetchedPosts;
    var dedupedPosts = totalDedupedPosts;
    try {
      while (mounted &&
          generation == _pagingGeneration &&
          _hasMorePages &&
          _nextPage < _kMaxCategoryPostsPages) {
        final currentPage =
            _nextPage; // 현재 로드할 페이지 번호를 nextPage에서 읽어와 지역 변수로 저장

        // 다음 페이지 로드
        final pagePosts = await postController!.getPostsByCategory(
          categoryId: categoryId,
          userId: userId,
          notificationId: null,
          page: currentPage,
          notifyLoading: false,
        );
        if (!mounted || generation != _pagingGeneration) return;

        if (pagePosts.isEmpty) {
          _hasMorePages = false;
          break;
        }

        pagesLoaded++; // 로드된 페이지 수 증가
        fetchedPosts += pagePosts.length; // API에서 받아온 포스트 수 누적

        final pageResult = _appendVisiblePosts(pagePosts);
        dedupedPosts += pageResult.duplicateRemoved;

        _nextPage = currentPage + 1;

        if (pageResult.posts.isNotEmpty) {
          setState(() {
            _posts = List<Post>.unmodifiable([..._posts, ...pageResult.posts]);
          });
          _syncCategoryPostsCache(cacheKey);
          _prefetchVideoThumbnails(pageResult.posts);
        }
      }
      if (_nextPage >= _kMaxCategoryPostsPages) {
        _hasMorePages = false;
      }
    } catch (e) {
      if (foundation.kDebugMode) {
        debugPrint('[ApiCategoryPhotosScreen] 백그라운드 페이징 실패: $e');
      }
    } finally {
      if (generation == _pagingGeneration) {
        _isBackgroundPaging = false;
      }
      if (foundation.kDebugMode && generation == _pagingGeneration) {
        debugPrint(
          '[_loadPosts] background complete latency=${startedAt.elapsedMilliseconds}ms '
          'pages=$pagesLoaded fetched=$fetchedPosts loaded=${_posts.length} '
          'deduped=$dedupedPosts hasMore=$_hasMorePages nextPage=$_nextPage '
          'isBackgroundPaging=$_isBackgroundPaging',
        );
      }
    }
  }

  /// 페이지에 새로 추가된 포스트 중에서 차단된 유저의 포스트와 중복된 포스트를 제거하고,
  /// 최종적으로 화면에 표시할 포스트 목록과 제거된 포스트 수를 반환하는 메서드
  ///
  /// Parameters:
  /// - [pagePosts]: 새로 로드된 페이지의 포스트 목록으로, API에서 받아온 원본 데이터입니다.
  ///
  /// Returns: _PageAppendResult 객체로, 화면에 표시할 포스트 목록과 제거된 차단된 유저의 포스트 수, 제거된 중복 포스트 수를 포함합니다.
  _PageAppendResult _appendVisiblePosts(List<Post> pagePosts) {
    final visible = <Post>[];
    var blockedRemoved = 0;
    var duplicateRemoved = 0;

    for (final post in pagePosts) {
      if (_blockedIds.contains(post.nickName)) {
        blockedRemoved++;
        continue;
      }
      if (!_seenPostIds.add(post.id)) {
        duplicateRemoved++;
        continue;
      }
      visible.add(post);
    }

    return _PageAppendResult(
      posts: visible,
      blockedRemoved: blockedRemoved,
      duplicateRemoved: duplicateRemoved,
    );
  }

  /// 카테고리별 포스트 캐시를 동기화하는 메서드
  /// 현재 로드된 포스트 목록을 기반으로 캐시를 업데이트하여, 다음에 동일한 카테고리를 로드할 때 빠르게 데이터를 제공할 수 있도록 합니다.
  ///
  /// Parameters:
  /// - [cacheKey]: 업데이트할 캐시 항목의 키로, 일반적으로 'userId:categoryId' 형식입니다.
  void _syncCategoryPostsCache(String cacheKey) {
    _categoryPostsCache[cacheKey] = _CategoryPostsCacheEntry(
      posts: List<Post>.unmodifiable(_posts),
      cachedAt: DateTime.now(),
    );
  }

  /// 비디오 썸네일 프리페칭
  ///
  /// 화면에 표시될 비디오들의 썸네일을 백그라운드에서 미리 생성합니다.
  /// 이를 통해 사용자가 그리드를 스크롤할 때 썸네일이 즉시 표시됩니다.
  void _prefetchVideoThumbnails(List<Post> posts) {
    final videoPosts = posts.where((post) => post.isVideo).toList();

    if (videoPosts.isEmpty) return;

    // 초반 메모리 버스트를 줄이기 위해 상한을 낮춰 프리페칭합니다.
    final videosToFetch = videoPosts.take(4).toList();

    if (foundation.kDebugMode) {
      debugPrint('[VideoThumbnail] ${videosToFetch.length}개 비디오 썸네일 프리페칭 시작');
    }

    for (final post in videosToFetch) {
      final url = post.postFileUrl;
      if (url == null || url.isEmpty) continue;

      // 캐시 키 생성
      final cacheKey = VideoThumbnailCache.buildStableCacheKey(
        fileKey: post.postFileKey,
        videoUrl: url,
      );

      // 이미 메모리 캐시에 있으면 스킵
      if (VideoThumbnailCache.getFromMemory(cacheKey) != null) {
        continue;
      }

      // 백그라운드에서 3-tier 조회 (Memory → Disk → Generate)
      VideoThumbnailCache.getThumbnail(videoUrl: url, cacheKey: cacheKey);
    }
  }

  /// 자동 새로고침 타이머 시작
  void _startAutoRefreshTimer() {
    // 기존 타이머 취소
    _autoRefreshTimer?.cancel();

    // 새 타이머 시작
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) async {
      if (!mounted) {
        // 화면이 더 이상 존재하지 않으면 타이머 취소
        _autoRefreshTimer?.cancel();
        return;
      }

      // 데이터 새로고침
      await _loadPosts(forceRefresh: true);
    });
  }

  /// 포스트 변경 리스너를 등록
  void _attachPostChangedListenerIfNeeded() {
    if (postController == null || _postsChangedListener != null) return;

    _postsChangedListener = () {
      if (!mounted) return;
      final currentUser = userController?.currentUser;
      if (currentUser == null) return;

      // 해당 카테고리의 캐시 항목 제거
      _categoryPostsCache.remove(
        _buildCacheKey(userId: currentUser.id, categoryId: _currentCategory.id),
      );

      // 비가시 상태에서는 즉시 리로드를 미루고 복귀 시 1회 갱신합니다.
      if (!_isRouteVisible) {
        _needsRefreshOnVisible = true;
        return;
      }

      unawaited(_loadPosts(forceRefresh: true));
    };

    // 리스너 등록
    postController!.addPostsChangedListener(_postsChangedListener!);
  }

  /// 캐시 키 생성
  ///
  /// Parameters:
  /// - [userId]: 사용자 ID
  /// - [categoryId]: 카테고리 ID
  ///
  /// Returns: 캐시 키 문자열
  String _buildCacheKey({required int userId, required int categoryId}) {
    return '$userId:$categoryId';
  }

  /// 유효한 캐시 항목 가져오기
  ///
  /// Parameters:
  /// - [key]: 캐시 키
  /// - [allowExpired]: 만료된 캐시도 반환할지 여부 (Optimistic UI용)
  ///
  /// Returns: 유효한 캐시 항목 또는 null
  _CategoryPostsCacheEntry? _getValidCache(
    String key, {
    bool allowExpired = false,
  }) {
    final cached = _categoryPostsCache[key];
    if (cached == null) return null;

    final isExpired = DateTime.now().difference(cached.cachedAt) >= _cacheTtl;

    // 만료되었지만 allowExpired=true면 반환 (Optimistic UI용)
    if (isExpired && !allowExpired) {
      return null;
    }

    return cached;
  }

  /// 친구 추가를 처리하는 메서드
  Future<void> _handleAddFriends() async {
    final category = _currentCategory;
    final previousCount = category.totalUserCount;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendListAddScreen(
          categoryId: category.id.toString(),
          categoryMemberUids: null,
        ),
      ),
    );

    final updatedCategory = await _refreshCategory(); // 카테고리 정보 갱신
    if (!mounted) return;

    if (updatedCategory != null &&
        updatedCategory.totalUserCount != previousCount) {
      // 멤버 수가 변경된 경우에만 바텀시트 표시
      showApiCategoryMembersBottomSheet(
        context,
        category: updatedCategory,
        onAddFriendPressed: _handleAddFriends,
      );
    }
  }

  /// 카테고리 정보를 갱신하는 메서드
  Future<Category?> _refreshCategory() async {
    // 카테고리 컨트롤러 가져오기
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );
    // userController 가져와서 현재 사용자 ID 확인
    final userController = Provider.of<UserController>(context, listen: false);
    final userId = userController.currentUser?.id;
    if (userId == null) {
      return _currentCategory;
    }

    // 카테고리 목록을 로드하고 캐시합니다.
    await categoryController.loadCategories(userId, forceReload: true);

    // ID로 캐시된 카테고리 가져오기
    final updated = categoryController.getCategoryById(_currentCategory.id);
    final current = updated ?? _currentCategory;
    final nextHeaderImagePrefetch = CategoryHeaderImagePrefetch.fromCategory(
      current,
    );
    final headerChanged =
        _headerImagePrefetch?.imageUrl != nextHeaderImagePrefetch?.imageUrl ||
        _headerImagePrefetch?.cacheKey != nextHeaderImagePrefetch?.cacheKey;

    if (nextHeaderImagePrefetch != null) {
      _headerImageMemoryCache[current.id] = nextHeaderImagePrefetch;
    } else {
      _headerImageMemoryCache.remove(current.id);
    }

    if (mounted && updated != null) {
      setState(() {
        _category = updated;
        _headerImagePrefetch = nextHeaderImagePrefetch;
      });
    } else {
      _headerImagePrefetch = nextHeaderImagePrefetch;
    }

    if (headerChanged && nextHeaderImagePrefetch != null) {
      unawaited(_precacheHeaderImageIfNeeded(nextHeaderImagePrefetch));
    }
    return current;
  }

  /// 카테고리 편집 화면으로 이동하는 메서드
  Future<void> _openCategoryEditor() async {
    final prefetched = _headerImagePrefetch;
    if (prefetched != null) {
      // Editor 진입 직전에 한 번 더 워밍업해 첫 프레임 플리커를 줄입니다.
      unawaited(_precacheHeaderImageIfNeeded(prefetched));
    }

    final categoryForEditor = _currentCategory.copyWith(
      photoUrl: prefetched?.imageUrl ?? _currentCategory.photoUrl,
    );

    // 편집 화면에서 돌아온 후 카테고리 정보를 갱신하여 변경사항 반영
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryEditorScreen(
          category: categoryForEditor,
          initialCoverPhotoUrl: prefetched?.imageUrl,
          initialCoverPhotoCacheKey: prefetched?.cacheKey,
        ),
      ),
    );
    if (!mounted) return;
    await _refreshCategory();
  }

  /// 카테고리 멤버 바텀시트를 표시하는 메서드:
  /// showApiCategoryMembersBottomSheet를 호출하여 현재 카테고리의 멤버 정보를 보여주는 바텀시트를 띄웁니다.
  void _showCategoryMembersBottomSheet() {
    showApiCategoryMembersBottomSheet(
      context,
      category: _currentCategory,
      onAddFriendPressed: _handleAddFriends,
    );
  }

  /// 그리드 레이아웃을 구성하는 메서드
  SliverGridDelegateWithFixedCrossAxisCount _buildPhotoGridDelegate() {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 170 / 204,
      mainAxisSpacing: 11.sp,
      crossAxisSpacing: 11.sp,
    );
  }

  /// 그리드 패딩을 반환하는 게터
  EdgeInsets get _gridPadding => EdgeInsets.only(
    left: (20.05).w,
    right: (20.05).w,
    top: 20.h,
    bottom: 30.h,
  );

  @override
  Widget build(BuildContext context) {
    final topSafeArea = MediaQuery.paddingOf(context).top; // 상단 안전 영역 높이
    final collapsedHeight = topSafeArea + kToolbarHeight; // 축소된 헤더 높이
    final expandedHeight = math.max(
      220.h,
      collapsedHeight + 110.h,
    ); // 확장된 헤더 높이

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _onRefresh, // 당겨서 새로고침 기능
        color: Colors.white,
        backgroundColor: Colors.grey.shade800,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            ApiCategoryPhotosHeader(
              category: _currentCategory,
              backgroundImageUrl: _headerImagePrefetch?.imageUrl,
              backgroundImageCacheKey: _headerImagePrefetch?.cacheKey,
              heroTag: widget.entryHeroTag,
              collapsedHeight: collapsedHeight,
              expandedHeight: expandedHeight,
              onBackPressed: () => Navigator.of(context).maybePop(),
              onMembersPressed: _showCategoryMembersBottomSheet,
              onMenuPressed: () {
                unawaited(_openCategoryEditor());
              },
            ),
            ..._buildBody(),
          ],
        ),
      ),
    );
  }

  /// 화면 본문을 구성하는 메서드
  List<Widget> _buildBody() {
    if (_isLoading) {
      return [
        // 로딩 중에는 로딩 슬리버만 표시
        ApiCategoryPhotosLoadingSliver(
          padding: _gridPadding,
          gridDelegate: _buildPhotoGridDelegate(),
        ),
      ];
    }

    if (_errorMessageKey != null) {
      return [
        // 에러 발생 시 에러 슬리버 표시
        ApiCategoryPhotosErrorSliver(
          errorMessageKey: _errorMessageKey!,
          onRetry: _loadPosts,
        ),
      ];
    }

    if (_posts.isEmpty) {
      return [const ApiCategoryPhotosEmptySliver()];
    }

    return [
      // 포스트가 있을 때,
      ApiCategoryPhotosGridSliver(
        posts: _posts,
        categoryName: _currentCategory.name,
        categoryId: _currentCategory.id,
        padding: _gridPadding,
        gridDelegate: _buildPhotoGridDelegate(),
        onPostsDeleted: _onPostsDeletedFromDetail,
      ),
    ];
  }
}

/// 카테고리별 포스트 캐시 항목 클래스
/// 각 카테고리에 대해 로드된 포스트 목록과 캐시된 시점을 함께 저장하여,
/// 다음에 동일한 카테고리를 로드할 때 빠르게 데이터를 제공할 수 있도록 합니다.
///
/// Parameters:
/// - [posts]: 캐시된 포스트 목록으로, 해당 카테고리에 속한 사진(포스트) 데이터를 포함합니다.
/// - [cachedAt]: 캐시된 시점을 나타내는 DateTime 객체로, 캐시의 유효성을 판단하는 데 사용됩니다.
class _CategoryPostsCacheEntry {
  final List<Post> posts;
  final DateTime cachedAt;

  const _CategoryPostsCacheEntry({required this.posts, required this.cachedAt});
}

/// 페이지에 새로 추가된 포스트 중에서 차단된 유저의 포스트와 중복된 포스트를 제거한 결과를 담는 클래스
/// 새로 로드된 페이지의 포스트 목록에서 차단된 유저의 포스트와 이미 화면에 표시된 포스트를 제거한 후,
/// 최종적으로 화면에 표시할 포스트 목록과 제거된 포스트 수를 함께 반환하는 데 사용됩니다.
///
/// Parameters:
/// - [posts]: 화면에 표시할 최종 포스트 목록
/// - [blockedRemoved]: 차단된 유저의 포스트로 인해 제거된 포스트 수
/// - [duplicateRemoved]: 중복된 포스트로 인해 제거된 포스트 수
class _PageAppendResult {
  final List<Post> posts;
  final int blockedRemoved;
  final int duplicateRemoved;

  const _PageAppendResult({
    required this.posts,
    required this.blockedRemoved,
    required this.duplicateRemoved,
  });
}
