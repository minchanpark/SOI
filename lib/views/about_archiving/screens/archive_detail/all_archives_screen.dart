import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/views/about_archiving/models/archive_layout_model.dart';
import '../../../../api/controller/category_controller.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../api/models/category.dart';
import '../../../../theme/theme.dart';
import '../../widgets/archive_card_widget/api_archive_card_widget.dart';
import '../../../../api/controller/category_search_controller.dart';

// 전체 아카이브 화면
// 모든 사용자의 아카이브 목록을 표시
// 아카이브를 클릭하면 아카이브 상세 화면으로 이동
class AllArchivesScreen extends StatefulWidget {
  final bool isEditMode;
  final String? editingCategoryId;
  final TextEditingController? editingController;
  final Function(String categoryId, String currentName)? onStartEdit;
  final ArchiveLayoutMode layoutMode;

  const AllArchivesScreen({
    super.key,
    this.isEditMode = false,
    this.editingCategoryId,
    this.editingController,
    this.onStartEdit,
    this.layoutMode = ArchiveLayoutMode.grid,
  });

  @override
  State<AllArchivesScreen> createState() => _AllArchivesScreenState();
}

class _AllArchivesCategoryViewState {
  final List<int> categoryIds;
  final bool isInitialLoading;
  final String? fatalErrorMessage;

  const _AllArchivesCategoryViewState({
    required this.categoryIds,
    required this.isInitialLoading,
    required this.fatalErrorMessage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AllArchivesCategoryViewState &&
          runtimeType == other.runtimeType &&
          isInitialLoading == other.isInitialLoading &&
          fatalErrorMessage == other.fatalErrorMessage &&
          listEquals(categoryIds, other.categoryIds);

  @override
  int get hashCode => Object.hash(
    isInitialLoading,
    fatalErrorMessage,
    Object.hashAll(categoryIds),
  );
}

class _AllArchivesScreenState extends State<AllArchivesScreen>
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

  /// 데이터 로드
  Future<void> _loadData() async {
    // 현재 로그인한 사용자 ID 가져오기
    final currentUser = _userController!.currentUser;
    if (currentUser != null) {
      if (mounted) {
        setState(() {
          _userId = currentUser.id;
        });
      }
      // 카테고리 로드
      await _categoryController!.loadCategories(currentUser.id);
      if (mounted) {
        setState(() {
          _isInitialLoad = false;
        });
      }
    } else {
      debugPrint('[AllArchivesScreen] 로그인된 사용자 없음');
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
      await _categoryController!.loadCategories(_userId!, forceReload: true);
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

      // 카테고리 목록
      // Selector로 부분 갱신이 되도록 함.
      body: Selector<CategoryController, _AllArchivesCategoryViewState>(
        selector: (context, categoryController) {
          final categoryIds = categoryController.allCategories
              .map((c) => c.id)
              .toList(growable: false);

          // "목록이 비어있는 상태"에서만 로딩/에러 UI가 필요하므로 파생 상태로 구독한다.
          final isInitialLoading =
              categoryController.isLoading && categoryIds.isEmpty;
          final fatalErrorMessage = categoryIds.isEmpty
              ? categoryController.errorMessage
              : null;

          return _AllArchivesCategoryViewState(
            categoryIds: categoryIds,
            isInitialLoading: isInitialLoading,
            fatalErrorMessage: fatalErrorMessage,
          );
        },
        builder: (context, state, child) {
          final searchController = context.watch<CategorySearchController>();
          final isSearchActive =
              searchController.searchQuery.isNotEmpty &&
              searchController.activeFilter == CategoryFilter.all;
          final displayCategoryIds = isSearchActive
              ? searchController.filteredCategories
                    .map((c) => c.id)
                    .toList(growable: false)
              : state.categoryIds;

          // 로딩 중 (카테고리 목록이 비어있는 경우에만)
          if (state.isInitialLoading) {
            return _buildShimmerGrid();
          }

          // 에러가 있을 때 (카테고리 목록이 비어있는 경우에만)
          if (state.fatalErrorMessage != null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '오류가 발생했습니다.',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: _refresh,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            );
          }

          // 카테고리가 없는 경우
          if (displayCategoryIds.isEmpty) {
            if (isSearchActive) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40.h),
                  child: Text(
                    '검색 결과가 없습니다.',
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.h),
                child: Text(
                  '등록된 카테고리가 없습니다.',
                  style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  textAlign: TextAlign.center,
                ),
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
                    displayCategoryIds,
                    searchController.searchQuery,
                  )
                : _buildListView(
                    displayCategoryIds,
                    searchController.searchQuery,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildGridView(List<int> categoryIds, String searchQuery) {
    return GridView.builder(
      key: ValueKey('grid_${categoryIds.length}_$searchQuery'),
      padding: EdgeInsets.only(left: 22.w, right: 20.w, bottom: 20.h),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: (168 / 229),
        mainAxisSpacing: 15.sp,
        crossAxisSpacing: 15.sp,
      ),
      itemCount: categoryIds.length,
      itemBuilder: (context, index) {
        final categoryId = categoryIds[index];
        final categoryController = context.read<CategoryController>();
        final category = categoryController.getCategoryById(categoryId);
        if (category == null) return const SizedBox.shrink();

        return ApiArchiveCardWidget(
          key: ValueKey('archive_card_$categoryId'),
          category: category,
          layoutMode: ArchiveLayoutMode.grid,
          isEditMode: widget.isEditMode,
          isEditing:
              widget.isEditMode &&
              widget.editingCategoryId == categoryId.toString(),
          editingController:
              widget.isEditMode &&
                  widget.editingCategoryId == categoryId.toString()
              ? widget.editingController
              : null,
          onStartEdit: () {
            if (widget.onStartEdit != null) {
              final latest =
                  categoryController.getCategoryById(categoryId) ?? category;
              widget.onStartEdit!(categoryId.toString(), latest.name);
            }
          },
        );
      },
    );
  }

  Widget _buildListView(List<int> categoryIds, String searchQuery) {
    return ListView.separated(
      key: ValueKey('list_${categoryIds.length}_$searchQuery'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(left: 22.w, right: 20.w, top: 8.h, bottom: 20.h),
      itemBuilder: (context, index) {
        final categoryId = categoryIds[index];
        final categoryController = context.read<CategoryController>();
        final category = categoryController.getCategoryById(categoryId);
        if (category == null) return const SizedBox.shrink();

        return ApiArchiveCardWidget(
          key: ValueKey('archive_list_card_$categoryId'),
          category: category,
          layoutMode: ArchiveLayoutMode.list,
          isEditMode: widget.isEditMode,
          isEditing:
              widget.isEditMode &&
              widget.editingCategoryId == categoryId.toString(),
          editingController:
              widget.isEditMode &&
                  widget.editingCategoryId == categoryId.toString()
              ? widget.editingController
              : null,
          onStartEdit: () {
            if (widget.onStartEdit != null) {
              final latest =
                  categoryController.getCategoryById(categoryId) ?? category;
              widget.onStartEdit!(categoryId.toString(), latest.name);
            }
          },
        );
      },
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemCount: categoryIds.length,
    );
  }

  /// Shimmer 로딩 그리드
  /// 로딩 중일떄, 일반 CircularProgressIndicator 대신 표시
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
