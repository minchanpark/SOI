import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../api/controller/category_controller.dart' as api_category;
import '../../../../api/controller/media_controller.dart';
import '../../../../api/controller/post_controller.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../api/models/category.dart';
import '../../../../utils/snackbar_utils.dart';

/// 카테고리 표지사진 선택 화면
class CategoryCoverPhotoSelectorScreen extends StatefulWidget {
  final Category category;

  const CategoryCoverPhotoSelectorScreen({super.key, required this.category});

  @override
  State<CategoryCoverPhotoSelectorScreen> createState() =>
      _CategoryCoverPhotoSelectorScreenState();
}

class _CategoryCoverPhotoSelectorScreenState
    extends State<CategoryCoverPhotoSelectorScreen> {
  String? selectedPhotoKey;

  bool _isLoading = true;
  List<_SelectablePhoto> _photos = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategoryPhotos();
    });
  }

  Future<void> _loadCategoryPhotos() async {
    final userController = context.read<UserController>();
    final currentUser = userController.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _photos = const [];
      });
      return;
    }

    try {
      final postController = context.read<PostController>();
      final mediaController = context.read<MediaController>();

      final posts = await postController.getPostsByCategory(
        categoryId: widget.category.id,
        userId: currentUser.id,
        notificationId: null,
      );

      // 이미지 + 비디오 게시물 모두 포함
      final mediaPosts = posts
          .where((post) => post.hasImage || post.isVideo)
          .toList();

      final resolved = <_SelectablePhoto>[];

      for (final post in mediaPosts) {
        String? key;

        if (post.isVideo) {
          // 비디오인 경우: 캐시에서 썸네일 키 조회
          final videoKey = post.postFileKey;

          if (videoKey != null && videoKey.isNotEmpty) {
            key = mediaController.getThumbnailForVideo(videoKey);
            if (key == null) {
              // 캐시에 없으면 비디오는 스킵 (썸네일이 없으면 표시 불가)

              continue;
            }
          }
        } else {
          // 이미지인 경우: 기존대로 postFileKey 사용
          key = post.postFileKey;
        }

        if (key != null && key.isNotEmpty) {
          try {
            final urls = await mediaController.getPresignedUrls([key]);
            if (urls.isNotEmpty) {
              resolved.add(_SelectablePhoto(key: key, url: urls[0]));
            }
          } catch (e) {
            // URL 발급 실패 시 해당 항목은 스킵
            continue;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _photos = resolved;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _photos = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          'category.cover.change_title',
          style: TextStyle(
            color: Colors.white,
            fontSize: (20).sp,
            fontWeight: FontWeight.w600,
            fontFamily: 'Pretendard Variable',
          ),
        ).tr(),
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFffffff)),
            )
          else if (_photos.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64.sp,
                    color: Colors.grey[600],
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'category.cover.no_photos',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16.sp,
                      fontFamily: 'Pretendard Variable',
                    ),
                  ).tr(),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8.w,
                  mainAxisSpacing: 8.h,
                  childAspectRatio: 175 / 232,
                ),
                itemCount: _photos.length,
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  final isSelected = selectedPhotoKey == photo.key;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedPhotoKey = isSelected ? null : photo.key;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: Colors.white)
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: photo.url,
                              cacheKey: photo.key,
                              useOldImageOnUrlChange: true,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              memCacheWidth: (175 * 2).round(),
                              maxWidthDiskCache: (175 * 2).round(),
                              placeholder: (context, url) => Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.error,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Positioned(
                                top: 8.h,
                                left: 8.w,
                                child: Container(
                                  width: 24.w,
                                  height: 24.h,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '✓',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: (14).sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 349.w,
                height: 50.h,

                child: ElevatedButton(
                  onPressed: _updateCoverPhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (selectedPhotoKey == null)
                        ? const Color(0xFF5a5a5a)
                        : const Color(0xFFf9f9f9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26.9),
                    ),
                  ),
                  child: Text(
                    'common.confirm',
                    style: TextStyle(
                      color: (selectedPhotoKey == null)
                          ? Colors.white
                          : Colors.black,
                      fontSize: (16).sp,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Pretendard Variable',
                    ),
                  ).tr(),
                ),
              ),
              SizedBox(height: 30.h),
            ],
          ),
        ],
      ),
    );
  }

  /// 표지사진 업데이트
  void _updateCoverPhoto() async {
    final key = selectedPhotoKey;
    if (key == null) return;

    final userController = context.read<UserController>();
    final currentUser = userController.currentUser;
    if (currentUser == null) return;

    final categoryController = context.read<api_category.CategoryController>();
    final success = await categoryController.updateCustomProfile(
      categoryId: widget.category.id,
      userId: currentUser.id,
      profileImageKey: key,
    );

    if (success && mounted) {
      await categoryController.loadCategories(
        currentUser.id,
        forceReload: true,
      );
      if (!mounted) return;
      Navigator.pop(context, key);
      SnackBarUtils.showSnackBar(
        context,
        tr('category.cover.updated', context: context),
      );
    } else if (mounted) {
      final message =
          categoryController.errorMessage ??
          tr('category.cover.update_failed', context: context);
      SnackBarUtils.showSnackBar(context, message);
    }
  }
}

class _SelectablePhoto {
  final String key;
  final String url;

  const _SelectablePhoto({required this.key, required this.url});
}
