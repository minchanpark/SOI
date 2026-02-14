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

  const ApiCategoryPhotosScreen({
    super.key,
    required this.category,
    this.prefetchedHeaderImage,
  });

  @override
  State<ApiCategoryPhotosScreen> createState() =>
      _ApiCategoryPhotosScreenState();
}

class _ApiCategoryPhotosScreenState extends State<ApiCategoryPhotosScreen> {
  static const Duration _cacheTtl = Duration(minutes: 30); // 캐시 만료 시간
  static final Map<String, _CategoryPostsCacheEntry> _categoryPostsCache =
      {}; // 카테고리별 포스트 캐시를 관리하는 맵
  static final Map<int, CategoryHeaderImagePrefetch> _headerImageMemoryCache =
      {};

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

  Category get _currentCategory => _category ?? widget.category;

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

    // 포스트 변경 리스너 제거
    if (_postsChangedListener != null && postController != null) {
      // 리스너가 등록된 경우에만 제거
      postController!.removePostsChangedListener(_postsChangedListener!);
    }
    super.dispose();
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

      // 카테고리 포스트 조회 & 차단 유저 조회를 병렬로 실행
      // 두 API는 서로 의존성이 없으므로 동시에 호출하여 대기 시간을 절반으로 줄임
      final stopwatch = Stopwatch()..start();

      // 병렬 API 호출
      final results = await Future.wait([
        postController!.getPostsByCategory(
          categoryId: _currentCategory.id,
          userId: currentUser.id,
          notificationId: null,
        ),
        friendController!.getAllFriends(
          userId: currentUser.id,
          status: FriendStatus.blocked,
        ),
      ]);

      final posts = results[0] as List<Post>;
      final blockedUsers = results[1] as List<User>;
      final blockedIds = blockedUsers.map((user) => user.userId).toSet();

      if (foundation.kDebugMode) {
        debugPrint(
          '[_loadPosts] API 병렬 호출 (posts + blocked): ${stopwatch.elapsedMilliseconds}ms',
        );
      }

      // 미디어(사진/비디오)가 포함된 포스트 필터링
      final mediaPosts = posts
          .where((post) {
            if (!post.hasMedia) return false;
            if (blockedIds.isEmpty) return true;
            return !blockedIds.contains(post.nickName);
          })
          .toList(growable: false);

      if (foundation.kDebugMode) {
        debugPrint(
          '[_loadPosts] 필터링 완료 (${mediaPosts.length}개 미디어 포스트): ${stopwatch.elapsedMilliseconds}ms',
        );
        debugPrint('[_loadPosts] 총 소요: ${stopwatch.elapsedMilliseconds}ms');
      }

      if (mounted) {
        setState(() {
          _posts = mediaPosts;
          _isLoading = false;
        });
      }

      // 캐시에 저장
      _categoryPostsCache[cacheKey] = _CategoryPostsCacheEntry(
        posts: List<Post>.unmodifiable(mediaPosts),
        cachedAt: DateTime.now(),
      );

      // 비디오 썸네일 프리페칭 (백그라운드)
      _prefetchVideoThumbnails(mediaPosts);
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

  /// 비디오 썸네일 프리페칭
  ///
  /// 화면에 표시될 비디오들의 썸네일을 백그라운드에서 미리 생성합니다.
  /// 이를 통해 사용자가 그리드를 스크롤할 때 썸네일이 즉시 표시됩니다.
  void _prefetchVideoThumbnails(List<Post> posts) {
    final videoPosts = posts.where((post) => post.isVideo).toList();

    if (videoPosts.isEmpty) return;

    // 처음 10개 비디오만 프리페칭 (초기 뷰포트 + 약간의 여유)
    final videosToFetch = videoPosts.take(10).toList();

    if (foundation.kDebugMode) {
      debugPrint('[VideoThumbnail] ${videosToFetch.length}개 비디오 썸네일 프리페칭 시작');
    }

    for (final post in videosToFetch) {
      final url = post.postFileUrl;
      if (url == null || url.isEmpty) continue;

      final cacheKey = post.postFileKey ?? url;

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

      // 포스트 변경 시 강제 새로고침
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
        onPostsDeleted: (_) => _onRefresh(),
      ),
    ];
  }
}

/// 카테고리별 포스트 캐시 항목 클래스
class _CategoryPostsCacheEntry {
  final List<Post> posts;
  final DateTime cachedAt;

  const _CategoryPostsCacheEntry({required this.posts, required this.cachedAt});
}
