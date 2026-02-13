import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/models/post.dart';
import 'package:soi/views/about_archiving/models/archive_layout_model.dart';
import '../../../../api/controller/category_controller.dart';
import '../../../../api/controller/post_controller.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../api/controller/friend_controller.dart';
import '../../../../api/models/category.dart' as api_category;
import '../../../../api/models/friend.dart';
import '../../screens/archive_detail/api_category_photos_screen.dart';
import 'api_archive_profile_row_widget.dart';
import 'api_archive_popup_menu_widget.dart';
import 'archive_card_models.dart';
import 'archive_card_placeholders.dart';

import 'package:flutter/foundation.dart' show kDebugMode;

/// 카테고리 카드를 표시하는 위젯
///
/// Parameters:
/// - [category]: 표시할 카테고리 데이터
/// - [isEditMode]: 편집 모드 여부
/// - [isEditing]: 현재 편집 중인지 여부
/// - [editingController]: 편집 중인 텍스트 컨트롤러
/// - [onStartEdit]: 편집 시작 콜백
/// - [layoutMode]: 아카이브 레이아웃 모드
///
/// Returns:
/// - [Widget]: 카테고리 카드 위젯
class ApiArchiveCardWidget extends StatelessWidget {
  final api_category.Category category;
  final bool isEditMode;
  final bool isEditing;
  final TextEditingController? editingController;
  final VoidCallback? onStartEdit;
  final ArchiveLayoutMode layoutMode;

  const ApiArchiveCardWidget({
    super.key,
    required this.category,
    this.isEditMode = false,
    this.isEditing = false,
    this.editingController,
    this.onStartEdit,
    this.layoutMode = ArchiveLayoutMode.grid,
  });

  @override
  Widget build(BuildContext context) {
    return _buildGridLayout(context);
  }

  Widget _buildGridLayout(BuildContext context) {
    return InkWell(
      onTap: isEditMode
          ? null
          : () {
              final latestCategory =
                  context.read<CategoryController>().getCategoryById(
                    category.id,
                  ) ??
                  category;

              // ✨ 프리페칭: 네비게이션 시작과 동시에 데이터 로드
              final postController = context.read<PostController>();
              final userController = context.read<UserController>();
              final friendController = context.read<FriendController>();
              final currentUser = userController.currentUser;

              // 백그라운드에서 데이터 프리페칭 시작 (await 없이)
              if (currentUser != null) {
                _prefetchCategoryData(
                  postController: postController,
                  friendController: friendController,
                  categoryId: latestCategory.id,
                  userId: currentUser.id,
                );
              }

              // 동시에 화면 이동
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ApiCategoryPhotosScreen(category: latestCategory),
                ),
              );
            },
      child: Stack(
        children: [
          // 카테고리 이미지 (전체 채우기)
          _buildCategoryImage(
            width: 170.sp,
            height: 204.sp,
            borderRadius: 10.7,
          ),

          // 고정 배지
          // TODO: 위치 조정 필요
          _buildPinnedBadge(top: 5, left: 5),

          // 신규 배지
          // TODO: 위치 조정 필요
          _buildNewBadge(top: 6.43, left: 127),

          // 카테고리 제목: 왼쪽 위
          Padding(
            padding: EdgeInsets.only(left: 15.sp, top: 15.sp),
            child: _buildTitleWidget(context, fontSize: 16.sp),
          ),

          // 프로필 Row: 오른쪽 아래
          Padding(
            padding: EdgeInsets.only(right: (8.39).sp, bottom: 9.sp),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Selector<CategoryController, CategoryProfileRowData>(
                selector: (_, controller) {
                  final latest = controller.getCategoryById(category.id);
                  return CategoryProfileRowData(
                    profileUrlKeys:
                        latest?.usersProfileKey ?? category.usersProfileKey,
                    totalUserCount:
                        latest?.totalUserCount ?? category.totalUserCount,
                  );
                },
                builder: (context, data, _) {
                  return ApiArchiveProfileRowWidget(
                    profileUrlKeys: data.profileUrlKeys,
                    totalUserCount: data.totalUserCount,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 카테고리 제목 위젯 빌드
  Widget _buildTitleWidget(BuildContext context, {required double fontSize}) {
    if (isEditing && editingController != null) {
      return TextField(
        controller: editingController,
        style: TextStyle(
          color: const Color(0xFFF8F8F8),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          fontFamily: 'Pretendard Variable',
        ),
        cursorColor: const Color(0xfff9f9f9),
        decoration: const InputDecoration(
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        maxLines: 1,
        autofocus: true,
      );
    }

    return Selector<CategoryController, String>(
      selector: (_, controller) =>
          controller.getCategoryById(category.id)?.name ?? category.name,
      builder: (context, name, _) {
        return Text(
          name,
          style: TextStyle(
            color: const Color(0xFFF9F9F9),
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            fontFamily: 'Pretendard',
            letterSpacing: -0.4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }

  /// 팝업 메뉴 위젯 빌드
  Widget _buildPopupMenu() {
    if (isEditMode) {
      return SizedBox(width: 30, height: 30);
    }

    return ApiArchivePopupMenuWidget(
      category: category,
      onEditName: onStartEdit,
      child: Icon(Icons.more_vert, color: Colors.white, size: 22),
    );
  }

  /// 카테고리 이미지 위젯 빌드
  Widget _buildCategoryImage({
    required double width,
    required double height,
    required double borderRadius,
  }) {
    return Selector<CategoryController, String?>(
      selector: (_, controller) =>
          controller.getCategoryById(category.id)?.photoUrl ??
          category.photoUrl,
      builder: (context, photoUrl, _) {
        final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
        if (hasPhoto) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: CachedNetworkImage(
              key: ValueKey('${category.id}_${photoUrl}_$layoutMode'),
              imageUrl: photoUrl,
              cacheKey: '${category.id}_$photoUrl',
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              useOldImageOnUrlChange: true,
              width: width,
              height: height,

              // Opacity 적용
              color: Colors.white.withValues(alpha: 0.8),
              colorBlendMode: BlendMode.modulate,

              // 메모리 캐시, 디스크 캐시 해상도 조정
              // MediaQuery.of(context).devicePixelRatio: 디바이스 픽셀 비율 고려
              memCacheWidth:
                  (width * MediaQuery.of(context).devicePixelRatio * 1.5)
                      .round(),
              maxWidthDiskCache:
                  (width * MediaQuery.of(context).devicePixelRatio * 1.5)
                      .round(),
              fit: BoxFit.cover,

              // shimmer placeholder 및 에러 위젯 처리
              // shimmer는 한번만 보여주고, 이후에는 기본 아이콘을 보여줍니다.
              placeholder: (context, url) => ShimmerOnceThenFallbackIcon(
                key: ValueKey('ph_${category.id}_$photoUrl'),
                width: width,
                height: height,
                borderRadius: borderRadius,
              ),
              errorWidget: (context, url, error) => Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: const Color(0xFFCACACA).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Icon(
                  Icons.image,
                  color: const Color(0xff5a5a5a),
                  size: 32,
                ),
              ),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            width: width,
            height: height,
            color: const Color(0xFFCACACA).withValues(alpha: 0.9),
            child: Icon(Icons.image, color: const Color(0xff5a5a5a), size: 32),
          ),
        );
      },
    );
  }

  /// 고정 배지 위젯 빌드
  Widget _buildPinnedBadge({double? top, double? left, double? right}) {
    return Selector<CategoryController, bool>(
      selector: (_, controller) =>
          controller.getCategoryById(category.id)?.isPinned ??
          category.isPinned,
      builder: (context, isPinned, _) {
        if (!isPinned) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: top,
          left: left,
          right: right,
          child: Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Image.asset('assets/pin_icon.png', width: 9, height: 9),
          ),
        );
      },
    );
  }

  /// 신규 배지 위젯 빌드
  Widget _buildNewBadge({double? top, double? left, double? right}) {
    return Selector<CategoryController, bool>(
      selector: (_, controller) =>
          controller.getCategoryById(category.id)?.isNew ?? category.isNew,
      builder: (context, isNew, _) {
        if (!isNew) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: top,
          left: left,
          right: right,
          child: Image.asset(
            'assets/new_icon.png',
            width: 13.87,
            height: 13.87,
          ),
        );
      },
    );
  }

  /// 카테고리 데이터 프리페칭
  ///
  /// 화면 전환 전에 미리 데이터를 로드하여 즉시 표시 가능하도록 합니다.
  /// 네비게이션 애니메이션(~300ms) 동안 API 호출이 완료될 수 있습니다.
  Future<void> _prefetchCategoryData({
    required PostController postController,
    required FriendController friendController,
    required int categoryId,
    required int userId,
  }) async {
    try {
      // 병렬로 프리페칭
      await Future.wait([
        postController.getPostsByCategory(
          categoryId: categoryId,
          userId: userId,
          notificationId: null,
        ),
        friendController.getAllFriends(
          userId: userId,
          status: FriendStatus.blocked,
        ),
      ]);

      if (kDebugMode) {
        debugPrint('[Prefetch] 카테고리 $categoryId 데이터 프리페칭 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Prefetch] 프리페칭 실패 (무시됨): $e');
      }
      // 프리페칭 실패는 무시 (화면에서 다시 시도함)
    }
  }
}
