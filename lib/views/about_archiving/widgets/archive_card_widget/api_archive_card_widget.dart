import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:soi/views/about_archiving/models/archive_layout_model.dart';
import '../../../../api/controller/category_controller.dart';
import '../../../../api/models/category.dart' as api_category;
import '../../screens/archive_detail/api_category_photos_screen.dart';
import 'api_archive_profile_row_widget.dart';
import 'api_archive_popup_menu_widget.dart';
import 'archive_card_models.dart';
import 'archive_card_placeholders.dart';

/// REST API 기반 아카이브 카드 위젯
///
/// [category]: 카테고리 데이터
/// [isEditMode]: 편집 모드 여부
/// [isEditing]: 현재 편집 중인지 여부
/// [editingController]: 편집 중인 텍스트 컨트롤러
/// [onStartEdit]: 편집 시작 콜백
/// [layoutMode]: 아카이브 레이아웃 모드
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
    return Container(
      key: ValueKey('grid_${category.id}'),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(6.61),
        border: Border.all(width: 1, color: Colors.transparent),
      ),
      child: InkWell(
        onTap: isEditMode
            ? null
            : () {
                final latestCategory =
                    context.read<CategoryController>().getCategoryById(
                      category.id,
                    ) ??
                    category;
                // REST API 버전의 CategoryPhotosScreen으로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ApiCategoryPhotosScreen(category: latestCategory),
                  ),
                );
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.topLeft,
              children: [
                _buildCategoryImage(
                  width: 146.7,
                  height: 146.8,
                  borderRadius: 6.61,
                ),
                _buildPinnedBadge(top: 5, left: 5),
                _buildNewBadge(top: 6.43, left: 127),
              ],
            ),
            SizedBox(height: (8.7).h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 14, right: 8),
                    child: _buildTitleWidget(context, fontSize: 14),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: _buildPopupMenu(),
                ),
              ],
            ),
            SizedBox(height: (16.87).h),
            Padding(
              padding: EdgeInsets.only(left: 12),
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
                  // 프로필 행 위젯 빌드 --> 프로필을 row로 표시
                  return ApiArchiveProfileRowWidget(
                    profileUrlKeys: data.profileUrlKeys,
                    totalUserCount: data.totalUserCount,
                  );
                },
              ),
            ),
          ],
        ),
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
          fontSize: 14,
          fontFamily: 'Pretendard ',
          fontWeight: FontWeight.w400,
          letterSpacing: -0.40,
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
              memCacheWidth: (width * 2).round(),
              maxWidthDiskCache: (width * 2).round(),
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
}
