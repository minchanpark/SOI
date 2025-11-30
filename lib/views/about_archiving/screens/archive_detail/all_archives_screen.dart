import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
//import 'package:shimmer/shimmer.dart';
import 'package:soi/api_firebase/controllers/category_search_controller.dart';
import '../../../../api_firebase/controllers/auth_controller.dart';
import '../../../../api_firebase/controllers/category_controller.dart';
import '../../../../theme/theme.dart';
import '../../models/archive_layout_mode.dart';
import '../../widgets/archive_card_widget/archive_card_widget.dart';

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

class _AllArchivesScreenState extends State<AllArchivesScreen>
    with AutomaticKeepAliveClientMixin {
  String? nickName;
  final Map<String, List<String>> _categoryProfileImages = {};
  final Map<String, List<String>> _categoryMatesCache = {}; // mates 변경 감지용
  AuthController? _authController; // AuthController 참조 저장
  CategoryController? _categoryController; // CategoryController 참조 저장
  bool _isInitialLoad = true; // 초기 로딩 상태 추적
  int _previousCategoryCount = 0; // 이전 카테고리 개수 저장
  final Map<String, Future<void>> _profileImageLoaders = {};

  @override
  void initState() {
    super.initState();
    // 이메일이나 닉네임을 미리 가져와요.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authController = Provider.of<AuthController>(context, listen: false);
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );

      _authController!.getIdFromFirestore().then((value) {
        if (mounted) {
          setState(() {
            nickName = value;
          });
          // 닉네임을 얻었을 때 카테고리 로드
          categoryController.loadUserCategories(value);
        }
      });

      // AuthController의 변경사항을 감지하여 프로필 이미지 캐시 업데이트
      _authController!.addListener(_onAuthControllerChanged);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AuthController 참조를 안전하게 저장
    _authController ??= Provider.of<AuthController>(context, listen: false);
  }

  @override
  void dispose() {
    // 저장된 참조를 사용하여 리스너 제거
    _authController?.removeListener(_onAuthControllerChanged);
    super.dispose();
  }

  /// AuthController 변경 감지 시 프로필 이미지 캐시 무효화
  void _onAuthControllerChanged() {
    if (mounted) {
      setState(() {
        _categoryProfileImages.clear(); // 모든 프로필 이미지 캐시 무효화
        _profileImageLoaders.clear();
      });
    }
  }

  // 카테고리에 대한 프로필 이미지를 가져오는 함수
  Future<void> _loadProfileImages(String categoryId, List<String> mates) async {
    // mates가 변경되었는지 확인
    final cachedMates = _categoryMatesCache[categoryId];
    final matesChanged = cachedMates == null ||
        cachedMates.length != mates.length ||
        !cachedMates.every((mate) => mates.contains(mate));

    // 캐시가 있고 mates가 변경되지 않았으면 재로드 불필요
    if (_categoryProfileImages.containsKey(categoryId) && !matesChanged) {
      return;
    }

    // mates가 변경되었으면 캐시 무효화
    if (matesChanged) {
      _categoryProfileImages.remove(categoryId);
      _categoryMatesCache[categoryId] = List.from(mates);
    }

    // 중복 호출을 피하기 위해 이미 로딩 중이면 해당 Future를 반환
    final existingLoader = _profileImageLoaders[categoryId];
    if (existingLoader != null) {
      return existingLoader;
    }

    final authController = _authController;
    final categoryController = _categoryController;
    if (authController == null || categoryController == null) {
      return;
    }

    final loader = categoryController
        .getCategoryProfileImages(mates, authController)
        .then((profileImages) {
      if (!mounted) return;
      setState(() {
        _categoryProfileImages[categoryId] = profileImages;
        _categoryMatesCache[categoryId] = List.from(mates);
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _categoryProfileImages[categoryId] = [];
        _categoryMatesCache[categoryId] = List.from(mates);
      });
    }).whenComplete(() {
      _profileImageLoaders.remove(categoryId);
    });

    _profileImageLoaders[categoryId] = loader;
    return loader;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 만약 닉네임을 아직 못 가져왔다면 로딩 중이에요.
    if (nickName == null) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 3.0,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      body: Consumer2<CategorySearchController, CategoryController>(
        builder: (context, searchController, categoryControllerParam, child) {
          // categoryController를 저장하여 _buildGridView와 _buildListView에서 사용
          _categoryController = categoryControllerParam;

          // Stream 사용으로 실시간 업데이트
          return StreamBuilder<List<dynamic>>(
            stream: _categoryController!.streamUserCategories(nickName!),
            builder: (context, snapshot) {
              // 로딩 중일 때
              /* if (snapshot.connectionState == ConnectionState.waiting ||
                  !snapshot.hasData) {
                // 이전에 카테고리가 있었으면 shimmer 표시
                if (_previousCategoryCount > 0) {
                  return _buildShimmerGrid(_previousCategoryCount);
                }
                // 처음 로딩이면 아무것도 표시하지 않음
                return const SizedBox.shrink();
              }*/

              // 에러가 있을 때
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.h),
                    child: Text(
                      '오류가 발생했습니다.',
                      style: TextStyle(color: Colors.white, fontSize: 16.sp),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final categories = snapshot.data ?? [];

              // 카테고리 개수 저장 (다음 로딩 시 사용)
              if (categories.isNotEmpty &&
                  _previousCategoryCount != categories.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _previousCategoryCount = categories.length;
                    });
                  }
                });
              }

              // 모든 카테고리에 대해 프로필 이미지 로드 요청
              for (var category in categories) {
                final categoryId = category.id;
                final mates = category.mates;
                _loadProfileImages(categoryId, mates);
              }

              // 초기 로딩 완료 표시
              if (_isInitialLoad) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _isInitialLoad = false;
                    });
                  }
                });
              }

              // 검색어가 있으면 카테고리 필터링
              final displayCategories = searchController.searchQuery.isNotEmpty
                  ? categories.where((category) {
                      final userId = _authController?.getUserId;
                      return userId != null
                          ? searchController.matchesSearchQuery(
                              category,
                              searchController.searchQuery,
                              currentUserId: userId,
                            )
                          : category.name.toLowerCase().contains(
                              searchController.searchQuery.toLowerCase(),
                            );
                    }).toList()
                  : categories;

              // 필터링 후 결과가 없는 경우 체크
              if (displayCategories.isEmpty) {
                // 검색 중인데 결과가 없는 경우
                if (searchController.searchQuery.isNotEmpty) {
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

                // 원본 카테고리가 없는 경우
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

              // FadeIn 애니메이션으로 부드럽게 표시
              return AnimatedOpacity(
                opacity: _isInitialLoad ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
                child: widget.layoutMode == ArchiveLayoutMode.grid
                    ? _buildGridView(searchController, displayCategories)
                    : _buildListView(searchController, displayCategories),
              );
            },
          );
        },
      ),
    );
  }

  /* Widget _buildShimmerGrid(int itemCount) {
    // 최소 2개, 최대 6개의 Shimmer 표시
    final shimmerCount = itemCount == 0 ? 6 : itemCount.clamp(1, 6);

    return GridView.builder(
      padding: EdgeInsets.only(left: 22.w, right: 20.w, bottom: 20.h),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: (168.w / 229.h),
        mainAxisSpacing: 15.h,
        crossAxisSpacing: 15.w,
      ),
      itemCount: shimmerCount,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[800]!,
          highlightColor: Colors.grey[700]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
        );
      },
    );
  }*/

  Widget _buildGridView(
    CategorySearchController searchController,
    List categories,
  ) {
    return GridView.builder(
      key: ValueKey(
        'grid_${categories.length}_${searchController.searchQuery}',
      ),
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
        final categoryId = category.id;

        // 현재 사용자의 표시 이름 가져오기 (상위 categoryController 재사용)
        final userId = _authController?.getUserId;
        final displayName = userId != null && _categoryController != null
            ? _categoryController!.getCategoryDisplayName(category, userId)
            : category.name;

        return ArchiveCardWidget(
          key: ValueKey('archive_card_$categoryId'),
          categoryId: categoryId,
          layoutMode: ArchiveLayoutMode.grid,
          isEditMode: widget.isEditMode,
          isEditing:
              widget.isEditMode && widget.editingCategoryId == categoryId,
          editingController:
              widget.isEditMode && widget.editingCategoryId == categoryId
              ? widget.editingController
              : null,
          onStartEdit: () {
            if (widget.onStartEdit != null) {
              widget.onStartEdit!(categoryId, displayName);
            }
          },
        );
      },
    );
  }

  Widget _buildListView(
    CategorySearchController searchController,
    List categories,
  ) {
    return ListView.separated(
      key: ValueKey(
        'list_${categories.length}_${searchController.searchQuery}',
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(left: 22.w, right: 20.w, top: 8.h, bottom: 20.h),
      itemBuilder: (context, index) {
        final category = categories[index];
        final categoryId = category.id;

        // 현재 사용자의 표시 이름 가져오기 (상위 categoryController 재사용)
        final userId = _authController?.getUserId;
        final displayName = userId != null && _categoryController != null
            ? _categoryController!.getCategoryDisplayName(category, userId)
            : category.name;

        return ArchiveCardWidget(
          key: ValueKey('archive_list_card_$categoryId'),
          categoryId: categoryId,
          layoutMode: ArchiveLayoutMode.list,
          isEditMode: widget.isEditMode,
          isEditing:
              widget.isEditMode && widget.editingCategoryId == categoryId,
          editingController:
              widget.isEditMode && widget.editingCategoryId == categoryId
              ? widget.editingController
              : null,
          onStartEdit: () {
            if (widget.onStartEdit != null) {
              widget.onStartEdit!(categoryId, displayName);
            }
          },
        );
      },
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemCount: categories.length,
    );
  }

  @override
  bool get wantKeepAlive => true;
}
