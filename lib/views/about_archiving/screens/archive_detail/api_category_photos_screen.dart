import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/media_controller.dart';
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
import '../../../../theme/theme.dart';
import '../../widgets/archive_card_widget/archive_card_placeholders.dart';
import '../../widgets/api_photo_grid_item.dart';

/// 카테고리 내에서 사진(포스트)들을 그리드 형식으로 보여주는 화면
/// Post를 조회하여서 카테고리 내에 사진이 포함된 포스트들을 필터링 후 표시
///
/// Parameters:
/// - [category]: 사진을 불러올 카테고리 정보
class ApiCategoryPhotosScreen extends StatefulWidget {
  final Category category;

  const ApiCategoryPhotosScreen({super.key, required this.category});

  @override
  State<ApiCategoryPhotosScreen> createState() =>
      _ApiCategoryPhotosScreenState();
}

class _ApiCategoryPhotosScreenState extends State<ApiCategoryPhotosScreen> {
  static const Duration _cacheTtl = Duration(minutes: 30); // 캐시 만료 시간
  static final Map<String, _CategoryPostsCacheEntry> _categoryPostsCache =
      {}; // 카테고리별 포스트 캐시를 관리하는 맵

  bool _isLoading = true; // 로딩 상태
  String? _errorMessageKey; // 에러 메시지 키
  List<Post> _posts = []; // 로드된 포스트 목록
  Category? _category; // 갱신된 카테고리 정보

  List<String> _postImageUrls = []; // 포스트 이미지 URL 목록

  Timer? _autoRefreshTimer; // 자동 새로고침 타이머
  static const Duration _autoRefreshInterval = Duration(
    minutes: 30,
  ); // 자동 새로고침 간격

  PostController? postController;
  UserController? userController;
  MediaController? mediaController;
  FriendController? friendController;
  VoidCallback? _postsChangedListener; // 포스트 변경을 감지하는 리스너

  Category get _currentCategory => _category ?? widget.category;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    // 빌드 완료 후 데이터 로드 (notifyListeners 충돌 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );
      categoryController.markCategoryAsViewed(_currentCategory.id);
      await _loadPosts();
      _startAutoRefreshTimer();
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

  /// 카테고리 내 사진(포스트) 목록 로드
  Future<void> _loadPosts({bool forceRefresh = false}) async {
    if (!mounted) return;

    try {
      // 컨트롤러 인스턴스 가져오기
      postController = Provider.of<PostController>(context, listen: false);
      userController = Provider.of<UserController>(context, listen: false);
      mediaController = Provider.of<MediaController>(context, listen: false);
      friendController = Provider.of<FriendController>(context, listen: false);

      // 포스트 변경 리스너 등록
      _attachPostChangedListenerIfNeeded();

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
      // 캐시에서 유효한 항목 가져오기
      final cached = _getValidCache(cacheKey);
      if (!forceRefresh && cached != null) {
        if (mounted) {
          setState(() {
            _posts = cached.posts; // 캐시된 포스트 사용
            _postImageUrls = cached.imageUrls; // 캐시된 이미지 URL 사용
            _isLoading = false; // 로딩 완료
            _errorMessageKey = null; // 에러 없음
          });
        }
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessageKey = null;
      });

      // 카테고리 내 포스트 조회
      final posts = await postController!.getPostsByCategory(
        categoryId: _currentCategory.id,
        userId: currentUser.id,
        notificationId: null,
      );

      final blockedUsers = await friendController!.getAllFriends(
        userId: currentUser.id,
        status: FriendStatus.blocked,
      );
      final blockedIds = blockedUsers.map((user) => user.userId).toSet();

      // 미디어(사진/비디오)가 포함된 포스트 필터링
      final mediaPosts = posts
          .where((post) {
            if (!post.hasMedia) return false;
            if (blockedIds.isEmpty) return true;
            return !blockedIds.contains(post.nickName);
          })
          .toList(growable: false);

      // 파일 키 목록 생성
      final postFileKeys = mediaPosts.map((e) => e.postFileKey!).toList();

      // Presigned URL 발급
      final urls = await mediaController!.getPresignedUrls(postFileKeys);

      // post와 URL 정렬 맞추기
      final alignedUrls = List<String>.generate(
        mediaPosts.length,
        (index) => index < urls.length ? urls[index] : '',
        growable: false,
      );

      if (mounted) {
        setState(() {
          _posts = mediaPosts;
          _postImageUrls = alignedUrls;
          _isLoading = false;
        });
      }

      // 캐시에 저장
      _categoryPostsCache[cacheKey] = _CategoryPostsCacheEntry(
        posts: List<Post>.unmodifiable(mediaPosts),
        imageUrls: List<String>.unmodifiable(alignedUrls),
        cachedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[ApiCategoryPhotosScreen] 포스트 로드 실패: $e');
      if (mounted) {
        setState(() {
          _errorMessageKey = 'archive.photo_load_failed';
          _isLoading = false;
        });
      }
    }
  }

  /// 새로고침
  Future<void> _onRefresh() async {
    await _loadPosts(forceRefresh: true);
    _startAutoRefreshTimer();
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
  ///
  /// Returns: 유효한 캐시 항목 또는 null
  _CategoryPostsCacheEntry? _getValidCache(String key) {
    final cached = _categoryPostsCache[key];
    if (cached == null) return null;
    if (DateTime.now().difference(cached.cachedAt) >= _cacheTtl) {
      _categoryPostsCache.remove(key);
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
    if (mounted && updated != null) {
      setState(() {
        _category = updated;
      });
    }
    return updated ?? _currentCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: 90.h,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 카테고리 이름
            Text(
              _currentCategory.name,
              style: TextStyle(
                color: const Color(0xFFD9D9D9),
                fontSize: 20,
                fontFamily: GoogleFonts.inter().fontFamily,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // 멤버 수 표시
            InkWell(
              onTap: () {
                showApiCategoryMembersBottomSheet(
                  context,
                  category: _currentCategory,
                  onAddFriendPressed: _handleAddFriends,
                );
              },
              borderRadius: BorderRadius.circular(100),
              child: SizedBox(
                height: 50.h,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people, size: 25.sp, color: Colors.white),
                      SizedBox(width: 2.w),
                      Text(
                        '${_currentCategory.totalUserCount}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 메뉴 버튼
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CategoryEditorScreen(category: _currentCategory),
                  ),
                );
                if (!mounted) return;
                // 카테고리 정보 갱신
                await _refreshCategory();
              },
              icon: const Icon(Icons.menu),
            ),
          ],
        ),
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 로딩 중
    if (_isLoading) {
      return _buildShimmerGrid();
    }

    // 에러 발생
    if (_errorMessageKey != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessageKey!,
                style: TextStyle(color: Colors.white, fontSize: 16.sp),
                textAlign: TextAlign.center,
              ).tr(),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: _loadPosts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                ),
                child: Text(
                  'common.retry',
                  style: TextStyle(color: Colors.white),
                ).tr(),
              ),
            ],
          ),
        ),
      );
    }

    // 사진 없음
    if (_posts.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Text(
            'archive.empty_photos',
            style: TextStyle(color: Colors.white, fontSize: 16.sp),
            textAlign: TextAlign.center,
          ).tr(),
        ),
      );
    }

    // 사진 그리드
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: Colors.white,
      backgroundColor: Colors.grey.shade800,
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 15.h,
          childAspectRatio: 175 / 233,
        ),
        padding: EdgeInsets.only(
          left: 15.w,
          right: 15.w,
          top: 20.h,
          bottom: 30.h,
        ),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          final postImage = index < _postImageUrls.length
              ? _postImageUrls[index]
              : '';

          return ApiPhotoGridItem(
            post: post,
            postUrl: postImage,
            allPosts: _posts,
            currentIndex: index,
            categoryName: _currentCategory.name,
            categoryId: _currentCategory.id,
            onPostsDeleted: (_) => _onRefresh(), // 사진 삭제 후 새로고침
          );
        },
      ),
    );
  }

  /// 로딩 중일 때 표시할 Shimmer 그리드
  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: EdgeInsets.only(
        left: 15.w,
        right: 15.w,
        top: 20.h,
        bottom: 30.h,
      ),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 15.h,
        childAspectRatio: 175 / 233,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return ShimmerOnceThenFallbackIcon(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              borderRadius: 8,
              shimmerCycles: 2, // shimmer기 몇번 돌지를 전달
            );
          },
        );
      },
    );
  }
}

/// 카테고리별 포스트 캐시 항목 클래스
class _CategoryPostsCacheEntry {
  final List<Post> posts;
  final List<String> imageUrls;
  final DateTime cachedAt;

  const _CategoryPostsCacheEntry({
    required this.posts,
    required this.imageUrls,
    required this.cachedAt,
  });
}
