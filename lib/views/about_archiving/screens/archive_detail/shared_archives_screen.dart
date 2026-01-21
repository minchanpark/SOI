import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../api/controller/category_controller.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../api/models/category.dart';
import '../../../../theme/theme.dart';
import '../../models/archive_layout_model.dart';
import '../../widgets/archive_card_widget/api_archive_card_widget.dart';
import '../../../../api/controller/category_search_controller.dart';

// 공유 아카이브 화면 (REST API 버전)
// 다른 사용자와 공유된 카테고리만 표시
class SharedArchivesScreen extends StatefulWidget {
  final bool isEditMode;
  final String? editingCategoryId;
  final TextEditingController? editingController;
  final Function(String categoryId, String currentName)? onStartEdit;
  final ArchiveLayoutMode layoutMode;

  const SharedArchivesScreen({
    super.key,
    this.isEditMode = false,
    this.editingCategoryId,
    this.editingController,
    this.onStartEdit,
    this.layoutMode = ArchiveLayoutMode.grid,
  });

  @override
  State<SharedArchivesScreen> createState() => _SharedArchivesScreenState();
}

class _SharedArchivesScreenState extends State<SharedArchivesScreen>
    with AutomaticKeepAliveClientMixin {
  int? _userId;

  // API 컨트롤러들
  UserController? _userController;
  CategoryController? _categoryController;

  /// 초기 로드 상태
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userController ??= Provider.of<UserController>(context, listen: false);
    _categoryController ??= Provider.of<CategoryController>(
      context,
      listen: false,
    );
  }

  /// 카테고리 초기 로드
  Future<void> _loadData() async {
    final userController = Provider.of<UserController>(context, listen: false);
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );

    _userController = userController;
    _categoryController = categoryController;

    // 현재 로그인한 사용자 ID 가져오기
    final currentUser = userController.currentUser;
    if (currentUser != null) {
      if (mounted) {
        setState(() {
          _userId = currentUser.id;
        });
      }
      // 카테고리 로드 (public 필터 - 공유된 카테고리)
      await categoryController.loadCategories(
        currentUser.id,
        filter: CategoryFilter.public_,
        fetchAllPages: true,
        maxPages: 2,
      );
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
    } else {
      debugPrint('[SharedArchivesScreen] 로그인된 사용자 없음');
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
    }
  }

  /// 새로고침
  Future<void> _refresh() async {
    if (_userId != null && _categoryController != null) {
      await _categoryController!.loadCategories(
        _userId!,
        filter: CategoryFilter.public_,
        forceReload: true,
        fetchAllPages: true,
        maxPages: 2,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 초기 로딩 중
    if (_isInitialLoad) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        body: _buildShimmerGrid(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: Consumer<CategoryController>(
        builder: (context, categoryController, child) {
          final categories = categoryController.publicCategories;
          final searchController = context.watch<CategorySearchController>();
          final isSearchActive =
              searchController.searchQuery.isNotEmpty &&
              searchController.activeFilter == CategoryFilter.public_;
          final displayCategories = isSearchActive
              ? searchController.filteredCategories
              : categories;

          // 로딩 중
          if (categoryController.isLoading && categories.isEmpty) {
            return _buildShimmerGrid();
          }

          // 에러가 있을 때
          if (categoryController.errorMessage != null && categories.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'common.error_occurred',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                      textAlign: TextAlign.center,
                    ).tr(),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: Text('common.retry').tr(),
                    ),
                  ],
                ),
              ),
            );
          }

          // 카테고리가 없는 경우
          if (displayCategories.isEmpty) {
            if (isSearchActive) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.h),
                  child: Text(
                    'archive.search_empty',
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                    textAlign: TextAlign.center,
                  ).tr(),
                ),
              );
            }

            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.h),
                child: Text(
                  'archive.empty_shared_categories',
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  textAlign: TextAlign.center,
                ).tr(),
              ),
            );
          }

          // RefreshIndicator로 당겨서 새로고침 지원
          return RefreshIndicator(
            onRefresh: _refresh,
            color: Colors.white,
            backgroundColor: const Color(0xFF1C1C1C),
            child: widget.layoutMode == ArchiveLayoutMode.grid
                ? _buildGridView(
                    displayCategories,
                    searchController.searchQuery,
                  )
                : _buildListView(
                    displayCategories,
                    searchController.searchQuery,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildGridView(List<Category> categories, String searchQuery) {
    return GridView.builder(
      key: ValueKey('shared_grid_${categories.length}_$searchQuery'),
      padding: EdgeInsets.only(left: 22.w, right: 20.w, bottom: 20.h),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: (168 / 229),
        mainAxisSpacing: 15.sp,
        crossAxisSpacing: 15.sp,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];

        return ApiArchiveCardWidget(
          key: ValueKey('shared_archive_card_${category.id}'),
          category: category,
          layoutMode: ArchiveLayoutMode.grid,
          isEditMode: widget.isEditMode,
          isEditing:
              widget.isEditMode &&
              widget.editingCategoryId == category.id.toString(),
          editingController:
              widget.isEditMode &&
                  widget.editingCategoryId == category.id.toString()
              ? widget.editingController
              : null,
          onStartEdit: () {
            if (widget.onStartEdit != null) {
              widget.onStartEdit!(category.id.toString(), category.name);
            }
          },
        );
      },
    );
  }

  Widget _buildListView(List<Category> categories, String searchQuery) {
    return ListView.separated(
      key: ValueKey('shared_list_${categories.length}_$searchQuery'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(left: 22.w, right: 20.w, top: 8.h, bottom: 20.h),
      itemBuilder: (context, index) {
        final category = categories[index];

        return ApiArchiveCardWidget(
          key: ValueKey('shared_archive_list_card_${category.id}'),
          category: category,
          layoutMode: ArchiveLayoutMode.list,
          isEditMode: widget.isEditMode,
          isEditing:
              widget.isEditMode &&
              widget.editingCategoryId == category.id.toString(),
          editingController:
              widget.isEditMode &&
                  widget.editingCategoryId == category.id.toString()
              ? widget.editingController
              : null,
          onStartEdit: () {
            if (widget.onStartEdit != null) {
              widget.onStartEdit!(category.id.toString(), category.name);
            }
          },
        );
      },
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemCount: categories.length,
    );
  }

  /// Shimmer 로딩 그리드
  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: EdgeInsets.only(left: 22.w, right: 20.w, bottom: 20.h),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: (168 / 229),
        mainAxisSpacing: 15.sp,
        crossAxisSpacing: 15.sp,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: const Color(0xFF2A2A2A),
          highlightColor: const Color(0xFF3A3A3A),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(6.61),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 146.8.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6.61),
                  ),
                ),
                SizedBox(height: 8.7.h),
                Padding(
                  padding: EdgeInsets.only(left: 14.w),
                  child: Container(
                    width: 80.w,
                    height: 14.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                SizedBox(height: 16.87.h),
                Padding(
                  padding: EdgeInsets.only(left: 14.w),
                  child: Row(
                    children: List.generate(
                      3,
                      (i) => Container(
                        width: 24.w,
                        height: 24.w,
                        margin: EdgeInsets.only(right: 4.w),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
