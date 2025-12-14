import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/views/about_archiving/screens/category_edit/category_editor_screen.dart';
import 'package:soi/views/about_archiving/widgets/api_category_members_bottom_sheet.dart';
import 'package:soi/views/about_friends/friend_list_add_screen.dart';

import '../../../../api/controller/category_controller.dart';
import '../../../../api/controller/post_controller.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../api/models/category.dart';
import '../../../../api/models/post.dart';
import '../../../../theme/theme.dart';
import '../../widgets/api_photo_grid_item.dart';

/// REST API 기반 카테고리 사진 목록 화면
///
/// Firebase 버전의 CategoryPhotosScreen과 동일한 UI를 유지하면서
/// REST API를 사용합니다.
class ApiCategoryPhotosScreen extends StatefulWidget {
  final Category category;

  const ApiCategoryPhotosScreen({super.key, required this.category});

  @override
  State<ApiCategoryPhotosScreen> createState() =>
      _ApiCategoryPhotosScreenState();
}

class _ApiCategoryPhotosScreenState extends State<ApiCategoryPhotosScreen> {
  // 로딩 상태
  bool _isLoading = true;
  String? _errorMessage;
  List<Post> _posts = [];
  Category? _category;

  List<String> _postImageUrls = [];

  Timer? _autoRefreshTimer;
  static const Duration _autoRefreshInterval = Duration(minutes: 30);

  PostController? postController;
  UserController? userController;
  MediaController? mediaController;

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
    super.dispose();
  }

  /// 카테고리 내 사진(포스트) 목록 로드
  Future<void> _loadPosts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 컨트롤러 인스턴스 가져오기
      postController = Provider.of<PostController>(context, listen: false);
      userController = Provider.of<UserController>(context, listen: false);
      mediaController = Provider.of<MediaController>(context, listen: false);

      // 현재 사용자 ID 가져오기
      final currentUser = userController!.currentUser;
      if (currentUser == null) {
        setState(() {
          _errorMessage = '로그인이 필요합니다.';
          _isLoading = false;
        });
        return;
      }

      // 카테고리 내 포스트 조회
      final posts = await postController!.getPostsByCategory(
        categoryId: _currentCategory.id,
        userId: currentUser.id,
        notificationId: null,
      );
      debugPrint("[ApiCategoryPhotosScreen] 현재 사용자 ID: ${currentUser.id}");
      debugPrint("[ApiCategoryPhotosScreen] 카테고리 ID: ${_currentCategory.id}");
      debugPrint("[ApiCategoryPhotosScreen] 로드된 포스트: $posts");

      // 미디어(사진/비디오)가 포함된 포스트 필터링
      final mediaPosts = posts
          .where((post) => post.hasMedia)
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
    } catch (e) {
      debugPrint('[ApiCategoryPhotosScreen] 포스트 로드 실패: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '사진을 불러오는데 실패했습니다.';
          _isLoading = false;
        });
      }
    }
  }

  /// 새로고침
  Future<void> _onRefresh() async {
    await _loadPosts();
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
      await _loadPosts();
    });
  }

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

    final updatedCategory = await _refreshCategory();
    if (!mounted) return;

    if (updatedCategory != null &&
        updatedCategory.totalUserCount != previousCount) {
      showApiCategoryMembersBottomSheet(
        context,
        category: updatedCategory,
        onAddFriendPressed: _handleAddFriends,
      );
    }
  }

  Future<Category?> _refreshCategory() async {
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );
    final userController = Provider.of<UserController>(context, listen: false);
    final userId = userController.currentUser?.id;
    if (userId == null) {
      return _currentCategory;
    }

    await categoryController.loadCategories(userId, forceReload: true);
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
      return const Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3.0),
      );
    }

    // 에러 발생
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 40.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.white, fontSize: 16.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              ElevatedButton(
                onPressed: _loadPosts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                ),
                child: const Text(
                  '다시 시도',
                  style: TextStyle(color: Colors.white),
                ),
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
            '사진이 없습니다.',
            style: TextStyle(color: Colors.white, fontSize: 16.sp),
            textAlign: TextAlign.center,
          ),
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
          );
        },
      ),
    );
  }
}
