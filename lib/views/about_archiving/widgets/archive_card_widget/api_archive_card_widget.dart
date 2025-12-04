import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/views/about_archiving/models/archive_layout_model.dart';
import '../../../../api/models/category.dart';
import '../../screens/archive_detail/api_category_photos_screen.dart';
import 'api_archive_profile_row_widget.dart';
import 'api_archive_popup_menu_widget.dart';

/// REST API 기반 아카이브 카드 위젯
///
/// [category]: 카테고리 데이터
/// [isEditMode]: 편집 모드 여부
/// [isEditing]: 현재 편집 중인지 여부
/// [editingController]: 편집 중인 텍스트 컨트롤러
/// [onStartEdit]: 편집 시작 콜백
/// [layoutMode]: 아카이브 레이아웃 모드
class ApiArchiveCardWidget extends StatelessWidget {
  final Category category;
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
                // REST API 버전의 CategoryPhotosScreen으로 이동
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ApiCategoryPhotosScreen(category: category),
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
              padding: EdgeInsets.only(left: 14),
              child: ApiArchiveProfileRowWidget(
                profileUrls: category.usersProfile,
                totalUserCount: category.totalUserCount,
              ),
            ),
          ],
        ),
      ),
    );
  }

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

    return Text(
      category.name,
      style: TextStyle(
        color: const Color(0xFFF9F9F9),
        fontSize: 14,
        fontWeight: FontWeight.bold,
        fontFamily: 'Pretendard',
        letterSpacing: -0.4,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

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

  Widget _buildCategoryImage({
    required double width,
    required double height,
    required double borderRadius,
  }) {
    if (category.hasPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          key: ValueKey('${category.id}_${category.photoUrl}_$layoutMode'),
          imageUrl: category.photoUrl!,
          cacheKey: '${category.id}_${category.photoUrl}',
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          useOldImageOnUrlChange: true,
          width: width,
          height: height,
          memCacheWidth: (width * 2).round(),
          maxWidthDiskCache: (width * 2).round(),
          fit: BoxFit.cover,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: Colors.grey.shade800,
            highlightColor: Colors.grey.shade700,
            period: const Duration(milliseconds: 1500),
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFFCACACA).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Icon(Icons.image, color: const Color(0xff5a5a5a), size: 32),
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
  }

  Widget _buildPinnedBadge({double? top, double? left, double? right}) {
    if (!category.isPinned) {
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
  }

  Widget _buildNewBadge({double? top, double? left, double? right}) {
    if (!category.isNew) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Image.asset('assets/new_icon.png', width: 13.87, height: 13.87),
    );
  }
}
