import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../api/controller/api_post_controller.dart';
import '../../../../api/controller/api_user_controller.dart';
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

  ApiPostController? postController;
  ApiUserController? userController;

  @override
  void initState() {
    super.initState();
    // 빌드 완료 후 데이터 로드 (notifyListeners 충돌 방지)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPosts();
    });
  }

  // Provider가 관리하는 컨트롤러는 dispose하지 않음
  // @override
  // void dispose() {
  //   super.dispose();
  // }

  /// 카테고리 내 사진(포스트) 목록 로드
  Future<void> _loadPosts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      postController = Provider.of<ApiPostController>(context, listen: false);
      userController = Provider.of<ApiUserController>(context, listen: false);

      // 현재 사용자 ID 가져오기
      final currentUser = userController!.currentUser;
      if (currentUser == null) {
        setState(() {
          _errorMessage = '로그인이 필요합니다.';
          _isLoading = false;
        });
        return;
      }

      // 카테고리 내 포스트 조회 (서버가 이미 presigned URL 반환)
      debugPrint("📂 카테고리 id: ${widget.category.id}");
      final posts = await postController!.getPostsByCategory(
        categoryId: widget.category.id,
        userId: currentUser.id,
      );

      debugPrint("카테고리 사진 로드 완료: ${posts.length}개");

      if (mounted) {
        setState(() {
          _posts = posts;
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
              widget.category.name,
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
                // TODO: API 버전 멤버 바텀시트
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '멤버 목록 (총 ${widget.category.totalUserCount}명)',
                    ),
                    duration: const Duration(seconds: 1),
                  ),
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
                        '${widget.category.totalUserCount}',
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
              onPressed: () {
                // TODO: API 버전 카테고리 편집 화면
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('카테고리 편집 (API 버전 구현 예정)'),
                    duration: Duration(seconds: 1),
                  ),
                );
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

          return ApiPhotoGridItem(
            post: post,
            allPosts: _posts,
            currentIndex: index,
            categoryName: widget.category.name,
            categoryId: widget.category.id,
          );
        },
      ),
    );
  }
}
