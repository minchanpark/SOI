import 'dart:async'; // Timer 사용을 위해 추가
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/category_controller.dart';
import 'package:soi/api/controller/friend_controller.dart';
import 'package:soi/api/controller/media_controller.dart';
import 'package:soi/api/controller/notification_controller.dart';
import 'package:soi/api/controller/post_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/controller/category_search_controller.dart';
import 'package:soi/api/models/category.dart';
import 'package:soi/api/models/friend.dart';
//import 'package:soi/api/models/selected_friend_model.dart';
import 'package:soi/views/about_archiving/models/archive_layout_model.dart';
import '../../../theme/theme.dart';
import '../../../utils/snackbar_utils.dart';
import '../../../utils/video_thumbnail_cache.dart';
//import '../../about_friends/friend_list_add_screen.dart';
//import '../widgets/overlapping_profiles_widget.dart';
import 'archive_detail/all_archives_screen.dart';
import 'archive_detail/my_archives_screen.dart';
import 'archive_detail/shared_archives_screen.dart';

// 아카이브 메인 화면
class APIArchiveMainScreen extends StatefulWidget {
  const APIArchiveMainScreen({super.key});

  @override
  State<APIArchiveMainScreen> createState() => _APIArchiveMainScreenState();
}

class _APIArchiveMainScreenState extends State<APIArchiveMainScreen> {
  int _selectedIndex = 0;
  final ArchiveLayoutMode _layoutMode = ArchiveLayoutMode.grid;

  // 컨트롤러들
  final _categoryNameController = TextEditingController();
  final _searchController = TextEditingController();
  final PageController _pageController = PageController(); // PageView 컨트롤러 추가

  // 검색 debounce를 위한 Timer
  Timer? _searchDebounceTimer;

  // Provider 참조를 미리 저장 (dispose에서 안전하게 사용하기 위함)
  CategorySearchController? _categorySearchController;
  CategoryController? _categoryController;
  VoidCallback? _categoryDataListener;

  UserController? _userController;
  MediaController? _mediaController;

  // 프리페칭 관련
  PostController? _postController;
  FriendController? _friendController;
  bool _hasPrefetchedPosts = false;

  // UserController 리스너 참조 저장 --> 프로필 이미지 변경 감지 및 처리
  VoidCallback? _userListener;

  // 프로필 이미지 캐싱 키
  String? _cachedProfileImageKey;

  // 편집 모드 상태 관리
  bool _isEditMode = false;
  String? _editingCategoryId;
  final _editingNameController = TextEditingController();
  final ValueNotifier<bool> _hasTextChangedNotifier = ValueNotifier<bool>(
    false,
  );

  // 원본 텍스트 저장
  String _originalText = '';

  // 선택된 친구들 상태 관리
  // List<SelectedFriendModel> _selectedFriends = [];

  // 프로필 이미지 URL
  String? _profileImageUrl;

  // 탭 화면 목록을 동적으로 생성하는 메서드
  List<Widget> get _screens => [
    AllArchivesScreen(
      layoutMode: _layoutMode,
      isEditMode: _isEditMode,
      editingCategoryId: _editingCategoryId,
      editingController: _editingNameController,
      onStartEdit: startEditMode,
    ),

    SharedArchivesScreen(
      layoutMode: _layoutMode,
      isEditMode: _isEditMode,
      editingCategoryId: _editingCategoryId,
      editingController: _editingNameController,
      onStartEdit: startEditMode,
    ),
    MyArchivesScreen(
      layoutMode: _layoutMode,
      isEditMode: _isEditMode,
      editingCategoryId: _editingCategoryId,
      editingController: _editingNameController,
      onStartEdit: startEditMode,
    ),
  ];

  @override
  void initState() {
    super.initState();

    // 검색 기능 설정
    _searchController.addListener(_onSearchChanged);

    // 최적화: 초기화 작업을 지연시켜 UI 블로킹 방지
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 다음 프레임에서 실행하여 UI 렌더링을 먼저 완료
      Future.delayed(Duration.zero, () {
        _categorySearchController?.clearSearch(notify: false);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Provider 참조를 안전하게 저장
    _ensureCategorySearchController();
    _ensureCategoryController();

    // MediaController를 먼저 준비해야 사용자 정보 변경 시 즉시 로딩 가능
    _mediaController ??= Provider.of<MediaController>(context, listen: false);

    // 프리페칭용 컨트롤러 준비
    _postController ??= Provider.of<PostController>(context, listen: false);
    _friendController ??= Provider.of<FriendController>(context, listen: false);

    final userController = Provider.of<UserController>(context, listen: false);
    if (_userController != userController) {
      if (_userListener != null) {
        _userController?.removeListener(_userListener!);
      }
      _userController = userController;
      _userListener ??= _handleUserProfileChanged;
      _userController?.addListener(_userListener!);
      _handleUserProfileChanged();
    }

    // 프로필 이미지 URL은 UserController 리스너에서 관리
  }

  void _ensureCategorySearchController() {
    if (_categorySearchController != null) return;
    _categorySearchController = Provider.of<CategorySearchController>(
      context,
      listen: false,
    );
  }

  void _ensureCategoryController() {
    final categoryController = Provider.of<CategoryController>(
      context,
      listen: false,
    );
    if (_categoryController == categoryController) return;

    if (_categoryDataListener != null) {
      _categoryController?.removeListener(_categoryDataListener!);
    }
    _categoryController = categoryController;
    _categoryDataListener ??= () {
      if (_categorySearchController?.searchQuery.isNotEmpty == true) {
        _applySearch();
      }
      // ✨ 카테고리 로드 완료 시 포스트 프리페칭 시작
      _prefetchPostsForCategories();
    };
    _categoryController?.addListener(_categoryDataListener!);
  }

  /// 카테고리 목록이 로드되면 각 카테고리의 포스트를 백그라운드에서 프리페칭
  ///
  /// 사용자가 카테고리를 탭하기 전에 데이터를 미리 로드하여
  /// 카테고리 진입 시 즉시 표시되도록 합니다.
  void _prefetchPostsForCategories() {
    if (_hasPrefetchedPosts) return;

    final categories = _categoryController?.allCategories;
    if (categories == null || categories.isEmpty) return;

    final userId = _userController?.currentUser?.id;
    if (userId == null) return;

    _hasPrefetchedPosts = true;

    // 처음 6개 카테고리만 프리페칭 (그리드 뷰에 보이는 수)
    final categoriesToFetch = categories.take(6).toList();

    if (kDebugMode) {
      debugPrint('[ArchiveMain] ${categoriesToFetch.length}개 카테고리 포스트 프리페칭 시작');
    }

    for (final category in categoriesToFetch) {
      // PostController 캐시에 저장되므로 나중에 카테고리 진입 시 즉시 사용
      _postController
          ?.getPostsByCategory(categoryId: category.id, userId: userId)
          .then((posts) {
            // 비디오 썸네일도 프리페칭
            final videoPosts = posts.where((p) => p.isVideo).take(4).toList();
            for (final post in videoPosts) {
              final url = post.postFileUrl;
              if (url == null || url.isEmpty) continue;
              final cacheKey = post.postFileKey ?? url;
              if (VideoThumbnailCache.getFromMemory(cacheKey) != null) continue;
              VideoThumbnailCache.getThumbnail(
                videoUrl: url,
                cacheKey: cacheKey,
              );
            }
          });
    }

    // blocked friends도 프리페칭
    _friendController?.getAllFriends(
      userId: userId,
      status: FriendStatus.blocked,
    );
  }

  /// 프로필 이미지 presigned URL 로드
  Future<void> _loadProfileImageUrl({String? profileImageKey}) async {
    // 최적화: currentUser를 직접 사용 (불필요한 getUser API 호출 제거)
    final user = _userController?.currentUser;

    if (user == null) {
      debugPrint('[ArchiveMainScreen] currentUser가 null - 프로필 이미지 로드 건너뜀');
      return;
    }

    final resolvedKey = profileImageKey ?? user.profileImageUrlKey;

    if (resolvedKey == null || resolvedKey.isEmpty) {
      debugPrint('[ArchiveMainScreen] profileImageUrlKey가 비어있음 - 기본 아바타 표시');
      return;
    }

    try {
      final url = await _mediaController?.getPresignedUrl(resolvedKey);
      if (mounted && url != null) {
        setState(() {
          _profileImageUrl = url;
          _cachedProfileImageKey = resolvedKey;
        });
      }
    } catch (e) {
      debugPrint('[ArchiveMainScreen] 프로필 이미지 URL 로드 실패: $e');
    }
  }

  /// 사용자 정보 변경 처리
  /// 프로필 이미지 키 변경 시 presigned URL 재로딩
  void _handleUserProfileChanged() {
    final key = _userController?.currentUser?.profileImageUrlKey;

    // 프로필 이미지 키가 없으면 기본 아바타로 설정
    if (key == null || key.isEmpty) {
      if (_profileImageUrl != null && mounted) {
        setState(() {
          _profileImageUrl = null;
          _cachedProfileImageKey = null;
        });
      }
      return;
    }

    // 이미 캐싱된 키와 동일하면 재로딩 불필요
    if (_profileImageUrl != null && key == _cachedProfileImageKey) {
      return;
    }

    // 프로필 이미지 키 변경 시 presigned URL 재로딩
    _cachedProfileImageKey = key;

    setState(() {
      // 프로필 이미지 URL 초기화하여 로딩 상태 표시
      _profileImageUrl = null;
    });

    // 프로필 이미지 URL 재로딩
    _loadProfileImageUrl(profileImageKey: key);
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _applySearch();
    });
  }

  void _applySearch() {
    if (!mounted) return;
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _categorySearchController?.clearSearch();
      return;
    }

    final categoryController = context.read<CategoryController>();
    final filter = _currentFilter;
    final categories = _getCategoriesForFilter(categoryController, filter);
    _categorySearchController?.searchCategories(
      categories,
      query,
      filter: filter,
    );
  }

  CategoryFilter get _currentFilter {
    switch (_selectedIndex) {
      case 1:
        return CategoryFilter.public_;
      case 2:
        return CategoryFilter.private_;
      default:
        return CategoryFilter.all;
    }
  }

  List<Category> _getCategoriesForFilter(
    CategoryController controller,
    CategoryFilter filter,
  ) {
    switch (filter) {
      case CategoryFilter.public_:
        return controller.publicCategories;
      case CategoryFilter.private_:
        return controller.privateCategories;
      case CategoryFilter.all:
        return controller.categories;
    }
  }

  // 편집 모드 관련 메서드들
  void startEditMode(String categoryId, String currentName) {
    setState(() {
      _isEditMode = true;
      _editingCategoryId = categoryId;
      _originalText = currentName; // 전달받은 현재 이름 저장
      _hasTextChangedNotifier.value = false; // 초기 상태는 변경 없음

      // 컨트롤러 완전히 초기화
      _editingNameController.clear();
      _editingNameController.text = currentName;

      // 선택과 커서 위치도 리셋
      _editingNameController.selection = TextSelection.fromPosition(
        TextPosition(offset: currentName.length),
      );

      // 텍스트 변경 리스너 추가
      _editingNameController.addListener(_onTextChanged);
    });
  }

  // 텍스트 변경 감지 메서드 (setState 없음!)
  void _onTextChanged() {
    // 원본 텍스트와 다르면 변경된 것으로 간주 (빈 텍스트도 허용)
    final hasChanged =
        _editingNameController.text.trim() != _originalText.trim();

    if (_hasTextChangedNotifier.value != hasChanged) {
      _hasTextChangedNotifier.value =
          hasChanged; // ValueNotifier만 업데이트 (setState 없음!)
    }
  }

  void cancelEditMode() {
    if (mounted) {
      setState(() {
        // 리스너 제거
        _editingNameController.removeListener(_onTextChanged);

        _isEditMode = false;
        _editingCategoryId = null;
        _hasTextChangedNotifier.value = false;
        _originalText = '';
        _editingNameController.clear();
      });
    }
  }

  Future<void> confirmEditMode() async {
    if (_editingCategoryId == null) return;

    final trimmedText = _editingNameController.text.trim();

    // 빈 텍스트 입력 시에만 에러 메시지 표시
    if (trimmedText.isEmpty) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          tr('archive.edit_name_required', context: context),
        );
      }
      return;
    }

    // 사용자별 커스텀 이름 업데이트
    try {
      // 최적화: 이미 있는 _userController 사용 (새 AuthController 인스턴스 생성 제거)
      final userId = _userController?.currentUser?.id;

      if (userId == null) {
        throw Exception(tr('common.user_info_unavailable', context: context));
      }

      final categoryId = int.tryParse(_editingCategoryId ?? '');
      if (categoryId == null) {
        throw Exception(
          tr('archive.category_info_unavailable', context: context),
        );
      }

      // 커스텀 이름 업데이트
      await _categoryController?.updateCustomName(
        categoryId: categoryId,
        userId: userId,
        name: trimmedText,
      );

      // 리스너 제거 후 모드 종료
      _editingNameController.removeListener(_onTextChanged);
      cancelEditMode();

      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          tr('archive.edit_name_success', context: context),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          tr('archive.edit_name_error', context: context),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // opaque: 빈 영역에서도 탭 이벤트를 감지
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // 편집 모드일 때 바깥 부분 클릭 시 편집 모드 해제
        if (_isEditMode) {
          cancelEditMode();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          centerTitle: true,
          leadingWidth: 90.w,
          title: Column(
            children: [
              Text(
                'SOI',
                style: TextStyle(
                  color: Color(0xfff9f9f9),
                  fontSize: 20.sp,
                  fontFamily: GoogleFonts.inter().fontFamily,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 30.h),
            ],
          ),
          backgroundColor: AppTheme.lightTheme.colorScheme.surface,
          toolbarHeight: 70.h,
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 32.w),
              child: Center(
                child: Consumer<NotificationController>(
                  builder: (context, _, child) {
                    return IconButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/notifications'),
                      icon: Container(
                        width: 35,
                        height: 35,
                        padding: EdgeInsets.only(bottom: 3.h),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xff1c1c1c),
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(top: 2.h),
                          child: Image.asset(
                            "assets/notification.png",
                            width: 25.sp,
                            height: 25.sp,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(60.sp),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.h, vertical: 8.w),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final chipWidth = constraints.maxWidth / 3;
                  return Stack(
                    children: [
                      // 애니메이션되는 인디케이터
                      AnimatedPositioned(
                        left: chipWidth * _selectedIndex,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: Container(
                          width: chipWidth,
                          height: 34.h,
                          alignment: Alignment.center,
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 8.w),
                            decoration: BoxDecoration(
                              color: const Color(0xFF323232),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      // 텍스트 레이블들
                      Row(
                        children: [
                          Expanded(child: _buildChip('archive.tabs.all', 0)),
                          Expanded(child: _buildChip('archive.tabs.shared', 1)),
                          Expanded(child: _buildChip('archive.tabs.mine', 2)),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // 검색바
            Padding(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 15.h,
                bottom: 5.h,
              ),
              child: Container(
                height: 41.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(16.6),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 10.w),
                    Icon(
                      Icons.search,
                      color: const Color(0xFFCCCCCC),
                      size: 24.sp,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: TextField(
                          controller: _searchController,
                          textAlignVertical: TextAlignVertical.center,
                          cursorColor: const Color(0xFFCCCCCC),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10.w,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 25.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                /* IconButton(
                  onPressed: () {
                    setState(() {
                      _layoutMode =
                          _layoutMode == ArchiveLayoutMode.grid
                              ? ArchiveLayoutMode.list
                              : ArchiveLayoutMode.grid;
                    });
                  },
                 icon:
                      _layoutMode == ArchiveLayoutMode.grid
                          ? Image.asset(
                            "assets/list_icon.png",
                            width: (16.92).w,
                            height: (17.27).h,
                          )
                          : Image.asset(
                            "assets/grid_icon.png",
                            width: (17.36).w,
                            height: (17.36).h,
                          ),
                ),*/
                SizedBox(width: (10).w),
              ],
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                  _applySearch();
                },
                children: _screens,
              ),
            ),

            if (_isEditMode)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: confirmEditMode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26.9),
                          ),
                        ),
                        child: Text(
                          'common.confirm',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20.sp,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                          ),
                        ).tr(),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: cancelEditMode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF323232),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26.9),
                          ),
                        ),
                        child: Text(
                          'common.cancel',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                          ),
                        ).tr(),
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

  // 선택 가능한 Chip 위젯 생성
  Widget _buildChip(String labelKey, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        // PageView도 함께 이동 - 부드러운 애니메이션으로 변경
        _pageController.animateToPage(
          index,
          duration: Duration(milliseconds: 100),
          curve: Curves.easeInOut,
        );
        _applySearch();
      },
      child: Container(
        height: 34.h,
        alignment: Alignment.center,
        padding: EdgeInsets.only(top: 2.h),
        child: Text(
          labelKey,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 16,
            fontFamily: 'Pretendard Variable',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ).tr(),
      ),
    );
  }

  // 카테고리 추가 bottom sheet 표시
  /*void _showCategoryBottomSheet() {
    final screenWidth = MediaQuery.of(context).size.width;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              height: 200.h,
              decoration: const BoxDecoration(
                color: Color(0xFF171717),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더 영역
                  Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 17.h, 20.w, 8.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 뒤로가기 버튼
                        SizedBox(
                          width: 34.w,
                          height: 38.h,
                          child: IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _categoryNameController.clear();
                              setState(() {
                                _selectedFriends = [];
                              });
                            },
                            icon: Icon(
                              Icons.arrow_back_ios,
                              color: const Color(0xFFD9D9D9),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),

                        // 제목
                        Text(
                          'archive.create_category_title',
                          style: TextStyle(
                            color: const Color(0xFFFFFFFF),
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Pretendard',
                            letterSpacing: -0.5,
                          ),
                        ).tr(),

                        // 저장 버튼
                        Container(
                          width: 51.w,
                          height: 25.h,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF323232),
                            borderRadius: BorderRadius.circular(16.5),
                          ),
                          padding: EdgeInsets.only(top: 2.h),
                          child: TextButton(
                            onPressed: () {
                              _createNewCategory(_selectedFriends);
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'common.save',
                              style: TextStyle(
                                color: const Color(0xFFFFFFFF),
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Pretendard',
                                letterSpacing: -0.4,
                              ),
                            ).tr(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 구분선
                  Container(
                    width: screenWidth,
                    height: 1,
                    color: const Color(0xFF3D3D3D),
                    margin: EdgeInsets.symmetric(horizontal: 2.w),
                  ),

                  // 친구 추가 섹션
                  if (_selectedFriends.isEmpty)
                    // 친구 추가하기 버튼
                    GestureDetector(
                      onTap: () async {
                        // add_category_widget.dart와 동일한 방식으로 처리
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FriendListAddScreen(
                              categoryMemberUids: _selectedFriends
                                  .map((friend) => friend.uid)
                                  .toList(),
                              allowDeselection: true,
                            ),
                          ),
                        );

                        if (result != null) {
                          setModalState(() {
                            _selectedFriends = result;
                          });

                          for (final friend in _selectedFriends) {
                            debugPrint('- ${friend.name} (${friend.uid})');
                          }
                        }
                      },
                      child: Padding(
                        padding: EdgeInsets.only(top: 10.h, left: 12.w),
                        child: Container(
                          width: 117.w,
                          height: 35.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF323232),
                            borderRadius: BorderRadius.circular(16.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/category_add.png',
                                width: 17.sp,
                                height: 17.sp,
                              ),
                              SizedBox(width: 6.w),
                              Text(
                                'category.members.add_friend_action',
                                style: TextStyle(
                                  color: const Color(0xFFE2E2E2),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'Pretendard',
                                  letterSpacing: -0.4,
                                ),
                              ).tr(),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // 선택된 친구들 표시 (+ 버튼 포함)
                  if (_selectedFriends.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 10.h, left: 12.w),
                      child: OverlappingProfilesWidget(
                        selectedFriends: _selectedFriends,
                        onAddPressed: () async {
                          final result =
                              await Navigator.push<List<SelectedFriendModel>>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FriendListAddScreen(
                                    categoryMemberUids: _selectedFriends
                                        .map((friend) => friend.uid)
                                        .toList(),
                                    allowDeselection: true,
                                  ),
                                ),
                              );

                          if (result != null) {
                            setModalState(() {
                              _selectedFriends = result;
                            });

                            for (final friend in _selectedFriends) {
                              debugPrint('- ${friend.name} (${friend.uid})');
                            }
                          }
                        },
                        showAddButton: true,
                      ),
                    ),

                  // 입력 필드 영역
                  Padding(
                    padding: EdgeInsets.only(left: 22.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _categoryNameController,
                          maxLength: 20,
                          cursorColor: const Color(0xFFCCCCCC),
                          style: TextStyle(
                            color: const Color(0xFFFFFFFF),
                            fontSize: 14.sp,
                            fontFamily: 'Pretendard',
                          ),
                          decoration: InputDecoration(
                            hintText: tr(
                              'archive.create_category_name_hint',
                              context: context,
                            ),
                            hintStyle: TextStyle(
                              color: const Color(0xFFCCCCCC),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              fontFamily: 'Pretendard',
                              letterSpacing: -0.4,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                          ),
                          autofocus: true,
                        ),

                        // 커스텀 글자 수 표시
                        Padding(
                          padding: EdgeInsets.only(right: 11.w),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _categoryNameController,
                              builder: (context, value, child) {
                                return Text(
                                  'archive.create_category_name_counter',
                                  style: TextStyle(
                                    color: const Color(0xFFCCCCCC),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Pretendard',
                                    letterSpacing: -0.4,
                                  ),
                                ).tr(
                                  namedArgs: {
                                    'count': value.text.length.toString(),
                                  },
                                );
                              },
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
        },
      ),
    ).then((_) {
      // 바텀시트가 닫힐 때 선택된 친구들 초기화
      if (mounted) {
        setState(() {
          _selectedFriends = [];
        });
      }
    });
  }*/

  // 카테고리 생성 처리 함수
  /*Future<void> _createNewCategory(
    List<SelectedFriendModel> selectedFriends,
  ) async {
    final categoryName = _categoryNameController.text.trim();
    if (categoryName.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        tr('archive.create_category_name_required', context: context),
      );
      return;
    }

    // UI 즉시 닫기 (사용자 체감 속도 향상)
    Navigator.pop(context);
    _categoryNameController.clear();
    setState(() => _selectedFriends = []);

    try {
      // REST API 컨트롤러 사용
      // 최적화: 이미 있는 Provider 인스턴스 사용 (새 인스턴스 생성 제거)
      final userController = Provider.of<UserController>(
        context,
        listen: false,
      );
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );

      final userId = userController.currentUser?.id;

      if (userId == null) {
        _showSnackBar(tr('common.login_required_relogin', context: context));
        return;
      }

      final isPublicCategory = selectedFriends.isNotEmpty;
      final receiverIds = <int>[];

      // 선택된 친구들의 ID 추가
      // PUBLIC 카테고리인 경우에만 본인 및 친구 ID 추가
      if (isPublicCategory) {
        receiverIds.add(userId);
        for (final friend in selectedFriends) {
          final parsedId = int.tryParse(friend.uid);
          if (parsedId != null && !receiverIds.contains(parsedId)) {
            receiverIds.add(parsedId);
          }
        }
      }

      // 카테고리 생성 API 호출
      // 최적화: 이미 있는 categoryController 사용 (새 인스턴스 생성 제거)
      final categoryId = await categoryController.createCategory(
        requesterId: userId,
        name: categoryName,
        receiverIds: receiverIds,
        isPublic: isPublicCategory,
      );

      if (categoryId != null) {
        // 최적화: forceReload: true가 캐시를 무시하므로 invalidateCache 중복 제거
        await categoryController.loadCategories(
          userId,
          forceReload: true,
          fetchAllPages: true,
          maxPages: 50,
        );

        if (mounted) {
          SnackBarUtils.showSnackBar(
            context,
            tr('archive.create_category_success', context: context),
          );
        }
      } else {
        _showSnackBar(tr('archive.create_category_failed', context: context));
      }
    } catch (e) {
      debugPrint('[ArchiveMainScreen] 카테고리 생성 오류: $e');
      _showSnackBar(tr('archive.create_category_failed', context: context));
    }
  }*/

  /*void _showSnackBar(String message) {
    if (mounted) {
      SnackBarUtils.showSnackBar(context, message);
    }
  }*/

  @override
  void dispose() {
    // 검색 debounce 타이머 정리
    _searchDebounceTimer?.cancel();

    // 편집 컨트롤러 리스너 안전하게 제거
    _editingNameController.removeListener(_onTextChanged);

    // 컨트롤러들 정리
    _categoryNameController.dispose();
    _editingNameController.dispose(); // 편집 컨트롤러 정리
    _hasTextChangedNotifier.dispose(); // ValueNotifier 정리
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _pageController.dispose(); // PageController 정리
    if (_userListener != null) {
      _userController?.removeListener(_userListener!);
    }
    if (_categoryDataListener != null) {
      _categoryController?.removeListener(_categoryDataListener!);
    }

    // 최적화: 전체 이미지 캐시 삭제 제거 (다른 화면의 캐시까지 삭제되어 비효율적)
    // CachedNetworkImage가 자체적으로 캐시를 관리하므로 수동 삭제 불필요
    super.dispose();
  }
}
