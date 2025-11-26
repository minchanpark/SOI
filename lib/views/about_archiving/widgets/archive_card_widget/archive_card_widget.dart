import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../../api_firebase/controllers/auth_controller.dart';
import '../../../../api_firebase/controllers/category_controller.dart';
import '../../../../api_firebase/models/category_data_model.dart';
import '../../screens/archive_detail/category_photos_screen.dart';
import 'archive_profile_row_widget.dart';
import 'archive_popup_menu_widget.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/archive_layout_mode.dart';

// 아카이브 카드 위젯
// Lazy Loading: 화면에 보이는 카드만 Firebase 스트림 구독
class ArchiveCardWidget extends StatefulWidget {
  final String categoryId;
  final bool isEditMode;
  final bool isEditing;
  final TextEditingController? editingController;
  final VoidCallback? onStartEdit;
  final ArchiveLayoutMode layoutMode;

  const ArchiveCardWidget({
    super.key,
    required this.categoryId,
    this.isEditMode = false,
    this.isEditing = false,
    this.editingController,
    this.onStartEdit,
    this.layoutMode = ArchiveLayoutMode.grid,
  });

  @override
  State<ArchiveCardWidget> createState() => _ArchiveCardWidgetState();
}

class _ArchiveCardWidgetState extends State<ArchiveCardWidget> {
  // Lazy Loading: 스트림을 nullable로 변경하여 필요할 때만 초기화
  Stream<CategoryDataModel?>? _categoryStream;

  // 한 번이라도 보였는지 추적 (스트림 재생성 방지)
  bool _hasBeenVisible = false;

  // 데이터 로드 완료 여부 (shimmer 한 번만 표시하기 위함)
  bool _hasLoadedData = false;

  @override
  void initState() {
    super.initState();
    // Lazy Loading: initState에서 스트림을 생성하지 않음
    // 화면에 보일 때 _initializeStreamIfNeeded()가 호출됨
  }

  /// 화면에 보일 때만 스트림 초기화 (Lazy Loading)
  void _initializeStreamIfNeeded() {
    if (_categoryStream == null && mounted) {
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );
      _categoryStream = categoryController.streamSingleCategory(
        widget.categoryId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // VisibilityDetector로 감싸서 화면에 보일 때만 데이터 로드
    return VisibilityDetector(
      key: Key('archive_card_visibility_${widget.categoryId}'),
      onVisibilityChanged: (VisibilityInfo info) {
        final isNowVisible = info.visibleFraction > 0;

        // 화면에 처음 보이게 되면 스트림 초기화
        if (isNowVisible && !_hasBeenVisible) {
          _hasBeenVisible = true;
          if (mounted) {
            setState(() {
              _initializeStreamIfNeeded();
            });
          }
        }
      },
      child: _buildCardContent(),
    );
  }

  /// 카드 콘텐츠 빌드 (shimmer를 한 번만 표시)
  Widget _buildCardContent() {
    // 아직 화면에 보이지 않았거나 스트림이 없으면 shimmer 표시
    /* if (!_hasBeenVisible || _categoryStream == null) {
      return widget.layoutMode == ArchiveLayoutMode.list
          ? _buildLoadingListCard()
          : _buildLoadingGridCard();
    }*/

    // 화면에 보였으면 실제 스트림 구독
    return StreamBuilder<CategoryDataModel?>(
      stream: _categoryStream,
      builder: (context, snapshot) {
        // 데이터가 아직 로드되지 않았으면 shimmer 유지 (한 번만)
        // _hasLoadedData를 사용하여 shimmer → 카드 전환이 한 번만 일어나도록 함
        if (!_hasLoadedData) {
          if (snapshot.hasData && snapshot.data != null) {
            // 데이터가 도착하면 플래그 업데이트 (다음 빌드에서 카드 표시)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _hasLoadedData = true);
            });
          }
          // 데이터 로드 전까지 shimmer 유지
          /* return widget.layoutMode == ArchiveLayoutMode.list
              ? _buildLoadingListCard()
              : _buildLoadingGridCard();*/
        }

        // 에러 발생
        if (snapshot.hasError) {
          debugPrint('ArchiveCardWidget Error: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        // 데이터 없음 또는 카테고리 삭제/나가기
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final category = snapshot.data!;

        // 현재 사용자가 카테고리에 없으면 표시 안 함
        final userId = AuthController().getUserId;
        if (userId == null ||
            !category.mates.contains(userId) ||
            category.name.isEmpty) {
          return const SizedBox.shrink();
        }

        // 카테고리 카드 표시
        return _buildCategoryCard(context, category);
      },
    );
  }

  /// 실제 카테고리 카드 빌드
  Widget _buildCategoryCard(BuildContext context, CategoryDataModel category) {
    return /*widget.layoutMode == ArchiveLayoutMode.list
        ? _buildListLayout(context, category)
        :*/ _buildGridLayout(context, category);
  }

  Widget _buildGridLayout(BuildContext context, CategoryDataModel category) {
    //final userId = AuthController().getUserId;
    // final hasNewPhoto =
    //userId != null ? category.hasNewPhotoForUser(userId) : false;

    return Container(
      key: ValueKey('grid_${category.id}'),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(6.61),
        border: Border.all(
          /*color:
              hasNewPhoto
                  ? Colors.white.withValues(alpha: 0.35)
                  : Colors.transparent,*/
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: widget.isEditMode
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CategoryPhotosScreen(category: category),
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
                  category,
                  width: 146.7,
                  height: 146.8,
                  borderRadius: 6.61,
                ),
                _buildPinnedBadge(category, top: 5, left: 5),
                _buildNewBadge(category, top: 6.43, left: 127),
              ],
            ),
            SizedBox(height: (8.7).h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 14, right: 8),
                    child: _buildTitleWidget(context, category, fontSize: 14),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: _buildPopupMenu(category),
                ),
              ],
            ),
            SizedBox(height: (16.87).h),
            Padding(
              padding: EdgeInsets.only(left: 14),
              child: ArchiveProfileRowWidget(mates: category.mates),
            ),
          ],
        ),
      ),
    );
  }

  // 리스트 형태로 보여주는 카테고리는 일단 보여주지 않는 걸로
  /* Widget _buildListLayout(BuildContext context, CategoryDataModel category) {
    final userId = AuthController().getUserId;
    final hasNewPhoto =
        userId != null ? category.hasNewPhotoForUser(userId) : false;

    return Container(
      height: 99,
      key: ValueKey('list_${category.id}'),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(6.61),
        border: Border.all(
          color:
              hasNewPhoto
                  ? Colors.white.withValues(alpha: 0.35)
                  : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap:
            widget.isEditMode
                ? null
                : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => CategoryPhotosScreen(category: category),
                    ),
                  );
                },
        child: Padding(
          padding: EdgeInsets.only(left: 7.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                width: 74.w,
                height: 74.w,
                child: Stack(
                  children: [
                    _buildCategoryImage(
                      category,
                      width: (80.92).w,
                      height: 81.h,
                      borderRadius: (3.65),
                    ),
                    _buildPinnedBadge(category, top: 6.h, left: 6.w),
                    _buildNewBadge(category, top: 4.h, right: 4.w),
                  ],
                ),
              ),
              SizedBox(width: (12.08).w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 12.h),
                            child: _buildTitleWidget(
                              context,
                              category,
                              fontSize: 14.sp,
                            ),
                          ),
                          Spacer(),
                          Padding(
                            padding: EdgeInsets.only(top: 12.h),
                            child: _buildPopupMenu(category),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.only(bottom: 10.h, right: 10.w),
                      child: Row(
                        children: [
                          Spacer(),
                          ArchiveProfileRowWidget(mates: category.mates),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }*/

  Widget _buildTitleWidget(
    BuildContext context,
    CategoryDataModel category, {
    required double fontSize,
  }) {
    if (widget.isEditing) {
      return TextField(
        controller: widget.editingController,
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

    final authController = AuthController();
    final userId = authController.getUserId;
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );

    final displayName = userId != null
        ? categoryController.getCategoryDisplayName(category, userId)
        : category.name;

    return Text(
      displayName,
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

  Widget _buildPopupMenu(CategoryDataModel category) {
    if (widget.isEditMode) {
      return SizedBox(width: 30, height: 30);
    }

    return ArchivePopupMenuWidget(
      category: category,
      onEditName: widget.onStartEdit,
      child: Icon(Icons.more_vert, color: Colors.white, size: 22),
    );
  }

  Widget _buildCategoryImage(
    CategoryDataModel category, {
    required double width,
    required double height,
    required double borderRadius,
  }) {
    if (category.categoryPhotoUrl != null &&
        category.categoryPhotoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CachedNetworkImage(
          key: ValueKey(
            '${category.id}_${category.categoryPhotoUrl}_${widget.layoutMode}',
          ),
          imageUrl: category.categoryPhotoUrl!,
          cacheKey: '${category.id}_${category.categoryPhotoUrl}',
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          useOldImageOnUrlChange: true,
          width: width,
          height: height,
          memCacheWidth: (width * 2).round(),
          maxWidthDiskCache: (width * 2).round(),
          fit: BoxFit.cover,
          /* placeholder: (context, url) => Shimmer.fromColors(
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
          ),*/
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

  Widget _buildPinnedBadge(
    CategoryDataModel category, {
    double? top,
    double? left,
    double? right,
  }) {
    final authController = AuthController();
    final userId = authController.getUserId;
    final isPinned = userId != null ? category.isPinnedForUser(userId) : false;

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
  }

  Widget _buildNewBadge(
    CategoryDataModel category, {
    double? top,
    double? left,
    double? right,
  }) {
    final authController = AuthController();
    final userId = authController.getUserId;
    final hasNewPhoto = userId != null
        ? category.hasNewPhotoForUser(userId)
        : false;

    if (!hasNewPhoto) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Image.asset('assets/new_icon.png', width: 13.87, height: 13.87),
    );
  }

  Widget _buildLoadingGridCard() {
    // key를 사용하여 위젯 재사용, shimmer 애니메이션 연속성 유지
    return SizedBox(
      key: ValueKey('loading_grid_${widget.categoryId}'),
      width: 168,
      height: double.infinity,
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade800,
        highlightColor: Colors.grey.shade700,
        period: const Duration(milliseconds: 1000),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(6.61),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingListCard() {
    // key를 사용하여 위젯 재사용, shimmer 애니메이션 연속성 유지
    return Shimmer.fromColors(
      key: ValueKey('loading_list_${widget.categoryId}'),
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      period: const Duration(milliseconds: 1500),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 130,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade700,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        3,
                        (index) => Padding(
                          padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade700,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
