import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/controller/post_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/post.dart';

class DeletedPostListScreen extends StatefulWidget {
  const DeletedPostListScreen({super.key});

  @override
  State<DeletedPostListScreen> createState() => _DeletedPostListScreenState();
}

class _DeletedPostListScreenState extends State<DeletedPostListScreen> {
  List<Post> _deletedPosts = [];
  final Set<int> _selectedPostIds = <int>{};
  final Map<int, String> _imageUrlByPostId = <int, String>{};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeletedPosts();
    });
  }

  Future<void> _loadDeletedPosts() async {
    final userController = context.read<UserController>();
    final user = userController.currentUser;
    if (user == null || user.id == 0) {
      setState(() {
        _error = '로그인이 필요합니다.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final postController = context.read<PostController>();
      final mediaController = context.read<MediaController>();

      final posts = await postController.getAllPosts(
        userId: user.id,
        postStatus: PostStatus.deleted,
      );

      final imageKeysToResolve = <String>[];
      final postIdsForResolvedKeys = <int>[];

      _imageUrlByPostId.clear();
      for (final post in posts) {
        final keyOrUrl = post.postFileKey;
        if (keyOrUrl == null || keyOrUrl.isEmpty) continue;

        final uri = Uri.tryParse(keyOrUrl);
        if (uri != null && uri.hasScheme) {
          _imageUrlByPostId[post.id] = keyOrUrl;
          continue;
        }

        imageKeysToResolve.add(keyOrUrl);
        postIdsForResolvedKeys.add(post.id);
      }

      if (imageKeysToResolve.isNotEmpty) {
        final urls = await mediaController.getPresignedUrls(imageKeysToResolve);
        final count = urls.length < postIdsForResolvedKeys.length
            ? urls.length
            : postIdsForResolvedKeys.length;
        for (var i = 0; i < count; i++) {
          _imageUrlByPostId[postIdsForResolvedKeys[i]] = urls[i];
        }
      }

      if (!mounted) return;
      setState(() {
        _deletedPosts = posts;
        _selectedPostIds.removeWhere(
          (id) => !_deletedPosts.any((post) => post.id == id),
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '게시물 복구',
              textAlign: TextAlign.start,
              style: TextStyle(
                color: const Color(0xFFF8F8F8),
                fontSize: 20.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          _buildBody(),
          Positioned(
            bottom: 40.h,

            child: SizedBox(
              width: 349.w,
              height: 50.h,
              child: ElevatedButton(
                onPressed: _selectedPostIds.isNotEmpty
                    ? _restoreSelectedPosts
                    : () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedPostIds.isNotEmpty
                      ? Colors.white
                      : const Color(0xFF595959),

                  disabledBackgroundColor: const Color(0xFF595959),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26.90),
                  ),
                ),
                child: Text(
                  '게시물에 표시',
                  style: TextStyle(
                    color: _selectedPostIds.isNotEmpty
                        ? Colors.black
                        : Colors.white,
                    fontSize: 18,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '오류가 발생했습니다',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _error!,
              style: TextStyle(
                color: const Color(0xFFB0B0B0),
                fontSize: 14.sp,
                fontFamily: 'Pretendard',
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadDeletedPosts,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_deletedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64.sp,
              color: const Color(0xFF666666),
            ),
            SizedBox(height: 16.h),
            Text(
              '삭제한 게시물이 없습니다',
              style: TextStyle(
                color: const Color(0xFFB0B0B0),
                fontSize: 16.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 13.h,
          childAspectRatio: 175 / 233, // 175:233 비율
        ),
        itemCount: _deletedPosts.length,
        itemBuilder: (context, index) {
          return _buildDeletedPostItem(_deletedPosts[index], index);
        },
      ),
    );
  }

  Widget _buildDeletedPostItem(Post post, int index) {
    final bool isPostSelected = _selectedPostIds.contains(post.id);
    final imageUrl = _imageUrlByPostId[post.id];

    return GestureDetector(
      onTap: () {
        _togglePostSelection(post.id);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: const Color(0xFF1C1C1C),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: (175 * 2).round(),
                  maxWidthDiskCache: (175 * 2).round(),
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: const Color(0xFF333333),
                    highlightColor: const Color(0xFF555555),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF333333),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFF333333),
                    child: Icon(
                      Icons.image,
                      color: Colors.white54,
                      size: 48.sp,
                    ),
                  ),
                )
              else
                Container(
                  color: const Color(0xFF333333),
                  child: Icon(Icons.image, color: Colors.white54, size: 48.sp),
                ),
              // 선택 오버레이
              if (isPostSelected)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              // 체크마크
              if (isPostSelected)
                Positioned(
                  top: 8.h,
                  left: 8.w,
                  child: Container(
                    width: 24.w,
                    height: 24.h,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, color: Colors.white, size: 16.sp),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _togglePostSelection(int postId) {
    setState(() {
      if (_selectedPostIds.contains(postId)) {
        _selectedPostIds.remove(postId);
      } else {
        _selectedPostIds.add(postId);
      }
    });
  }

  Future<void> _restoreSelectedPosts() async {
    if (context.read<UserController>().currentUserId == null) return;

    if (_selectedPostIds.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final postController = context.read<PostController>();
    int successCount = 0;
    int failCount = 0;

    for (final postId in _selectedPostIds.toList()) {
      try {
        final success = await postController.setPostStatus(
          postId: postId,
          postStatus: PostStatus.active,
        );

        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        debugPrint('사진 복원 오류: $e');
        failCount++;
      }
    }
    // 선택 상태 초기화
    if (!mounted) return;
    setState(_selectedPostIds.clear);

    // 삭제된 사진 목록 다시 로드
    await _loadDeletedPosts();

    // 사용자에게 결과 알림
    if (mounted) {
      String message;
      if (failCount == 0) {
        message = '$successCount개의 게시물이 복원되었습니다';
      } else if (successCount == 0) {
        message = '게시물 복원에 실패했습니다';
      } else {
        message = '$successCount개 복원 성공, $failCount개 실패';
      }

      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.white,
        textColor: Colors.black,
        fontSize: 14.sp,
      );
    }
  }
}
