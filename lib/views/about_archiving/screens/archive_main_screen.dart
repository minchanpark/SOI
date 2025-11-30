import 'dart:async'; // Timer 사용을 위해 추가
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/api_firebase/controllers/category_search_controller.dart';
import '../../../api_firebase/controllers/auth_controller.dart';
import '../../../api_firebase/controllers/category_controller.dart';
import '../../../api_firebase/models/selected_friend_model.dart';
import '../../../theme/theme.dart';
import '../../about_friends/friend_list_add_screen.dart';
import '../widgets/overlapping_profiles_widget.dart';
import '../models/archive_layout_mode.dart';
import 'archive_detail/all_archives_screen.dart';
import 'archive_detail/my_archives_screen.dart';
import 'archive_detail/shared_archives_screen.dart';

// 아카이브 메인 화면
class ArchiveMainScreen extends StatefulWidget {
  const ArchiveMainScreen({super.key});

  @override
  State<ArchiveMainScreen> createState() => _ArchiveMainScreenState();
}

class _ArchiveMainScreenState extends State<ArchiveMainScreen> {
  int _selectedIndex = 0;
  final ArchiveLayoutMode _layoutMode = ArchiveLayoutMode.grid;

  // 컨트롤러들
  final _categoryNameController = TextEditingController();
  final _searchController = TextEditingController();
  final PageController _pageController = PageController(); // PageView 컨트롤러 추가

  // 검색 debounce를 위한 Timer
  Timer? _searchDebounceTimer;

  // Provider 참조를 미리 저장 (dispose에서 안전하게 사용하기 위함)
  CategorySearchController? _categoryController;
  AuthController? _authController;

  // 편집 모드 상태 관리
  bool _isEditMode = false;
  String? _editingCategoryId;
  final _editingNameController = TextEditingController();
  final ValueNotifier<bool> _hasTextChangedNotifier = ValueNotifier<bool>(
    false,
  );
  String _originalText = ''; // 원본 텍스트 저장

  // 선택된 친구들 상태 관리
  List<SelectedFriendModel> _selectedFriends = [];

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
        _categoryController?.clearSearch(notify: false);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Provider 참조를 안전하게 저장
    _categoryController ??= Provider.of<CategorySearchController>(
      context,
      listen: false,
    );

    if (_authController == null) {
      _authController = Provider.of<AuthController>(context, listen: false);
      _authController!.addListener(_handleAuthControllerUpdated);
    }
  }

  void _onSearchChanged() {
    // 이전 타이머 취소
    _searchDebounceTimer?.cancel();

    // 300ms 지연 후 검색 실행 (타이핑 중 깜빡거림 방지)
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      // 검색어만 전달 (내부 카테고리 목록 사용)
      _categoryController?.searchCategories(_searchController.text);
    });
  }

  void _handleAuthControllerUpdated() {
    final controller = _authController;
    if (!mounted || controller == null || controller.isUploading) {
      return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이름을 입력해주세요'),
            backgroundColor: const Color(0xFF5A5A5A),
          ),
        );
      }
      return;
    }

    // 사용자별 커스텀 이름 업데이트
    try {
      // 현재 사용자 ID 가져오기
      final authController = AuthController();
      final userId = authController.getUserId;

      if (userId == null) {
        throw Exception('사용자 정보를 찾을 수 없습니다');
      }

      // 커스텀 이름 업데이트
      await _categoryController?.updateCustomCategoryName(
        categoryId: _editingCategoryId!,
        userId: userId,
        customName: trimmedText,
      );

      // 리스너 제거 후 모드 종료
      _editingNameController.removeListener(_onTextChanged);
      cancelEditMode();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('내 카테고리 이름이 수정되었습니다'),
            backgroundColor: const Color(0xFF5A5A5A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이름 수정 중 오류가 발생했습니다'),
            backgroundColor: const Color(0xFF5A5A5A),
          ),
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
          leading: Row(
            children: [
              SizedBox(width: 32.w),
              // 프로필 이미지 - StreamBuilder로 실시간 업데이트
              Consumer<AuthController>(
                builder: (context, authController, _) {
                  final currentUserId = authController.getUserId;
                  return StreamBuilder<String>(
                    stream: authController.getUserProfileImageUrlStream(
                      currentUserId ?? '',
                    ),
                    builder: (context, imageSnapshot) {
                      final isLoadingAvatar =
                          imageSnapshot.connectionState ==
                          ConnectionState.waiting;
                      final profileImageUrl = imageSnapshot.data ?? '';

                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 8.h,
                        ),
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle),
                          child: Builder(
                            builder: (context) {
                              return InkWell(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    '/profile_screen',
                                  );
                                },
                                child: SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: ClipOval(
                                    child: isLoadingAvatar
                                        ? _buildAvatarShimmer()
                                        : profileImageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: profileImageUrl,
                                            fit: BoxFit.cover,
                                            width: 34,
                                            height: 34,
                                            fadeInDuration: Duration.zero,
                                            fadeOutDuration: Duration.zero,
                                            memCacheWidth: (34 * 4).round(),
                                            maxWidthDiskCache: (34 * 4).round(),
                                            placeholder: (context, url) =>
                                                _buildAvatarShimmer(),
                                            errorWidget: (context, url, error) {
                                              Future.microtask(
                                                () => authController
                                                    .cleanInvalidProfileImageUrl(),
                                              );
                                              return _buildAvatarFallback();
                                            },
                                          )
                                        : _buildAvatarFallback(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 32.w),
              child: IconButton(
                onPressed: _showCategoryBottomSheet,
                icon: Image.asset(
                  "assets/create_category_icon.png",
                  width: 30.w,
                  height: 30.h,
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
                          Expanded(child: _buildChip('전체', 0)),
                          Expanded(child: _buildChip('공유앨범', 1)),
                          Expanded(child: _buildChip('나의 앨범', 2)),
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
                          '확인',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 20.sp,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                          '취소',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20.sp,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600,
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

  // 선택 가능한 Chip 위젯 생성
  Widget _buildChip(String label, int index) {
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
      },
      child: Container(
        height: 34.h,
        alignment: Alignment.center,
        padding: EdgeInsets.only(top: 2.h),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
            fontFamily: 'Pretendard',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // 카테고리 추가 bottom sheet 표시
  void _showCategoryBottomSheet() {
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
                          '새 카테고리 만들기',
                          style: TextStyle(
                            color: const Color(0xFFFFFFFF),
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Pretendard',
                            letterSpacing: -0.5,
                          ),
                        ),

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
                              _createNewCategory();
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              '저장',
                              style: TextStyle(
                                color: const Color(0xFFFFFFFF),
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Pretendard',
                                letterSpacing: -0.4,
                              ),
                            ),
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
                                '친구 추가하기',
                                style: TextStyle(
                                  color: const Color(0xFFE2E2E2),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'Pretendard',
                                  letterSpacing: -0.4,
                                ),
                              ),
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
                            hintText: '카테고리의 이름을 입력해 주세요.',
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
                                  '${value.text.length}/20자',
                                  style: TextStyle(
                                    color: const Color(0xFFCCCCCC),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Pretendard',
                                    letterSpacing: -0.4,
                                  ),
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
  }

  // 카테고리 생성 처리 함수
  Future<void> _createNewCategory() async {
    final categoryName = _categoryNameController.text.trim();
    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(_snackBarComponenet('카테고리 이름을 입력해주세요'));
      return;
    }

    // UI 즉시 닫기 (사용자 체감 속도 향상)
    final selectedFriendsCopy = List<SelectedFriendModel>.from(
      _selectedFriends,
    );
    Navigator.pop(context);
    _categoryNameController.clear();
    setState(() => _selectedFriends = []);

    try {
      final authController = Provider.of<AuthController>(
        context,
        listen: false,
      );
      final categoryController = Provider.of<CategoryController>(
        context,
        listen: false,
      );
      final userId = authController.getUserId;

      if (userId == null) {
        _showSnackBar('로그인이 필요합니다. 다시 로그인해주세요.');
        return;
      }

      // mates 리스트 준비 (현재 사용자 + 선택된 친구들)
      final mates = [userId, ...selectedFriendsCopy.map((f) => f.uid)];

      // 프로필 이미지 맵 수집
      final mateProfileImages = await _collectMateProfileImages(
        authController: authController,
        userId: userId,
        friends: selectedFriendsCopy,
      );

      await categoryController.createCategory(
        name: categoryName,
        mates: mates,
        mateProfileImages: mateProfileImages.isNotEmpty
            ? mateProfileImages
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(_showSuccessSnackBar());
      }
    } catch (e) {
      debugPrint('[ArchiveMainScreen] 카테고리 생성 오류: $e');
      _showSnackBar('카테고리 생성에 실패했습니다');
    }
  }

  /// 프로필 이미지 맵 수집 (현재 사용자 + 친구들)
  Future<Map<String, String>> _collectMateProfileImages({
    required AuthController authController,
    required String userId,
    required List<SelectedFriendModel> friends,
  }) async {
    final images = <String, String>{};

    // 현재 사용자 프로필 이미지 (캐시 우선)
    try {
      final userImage = await authController.getUserProfileImageUrlWithCache(
        userId,
      );
      if (userImage.isNotEmpty) images[userId] = userImage;
    } catch (e) {
      debugPrint('[ArchiveMainScreen] 현재 사용자 프로필 이미지 가져오기 실패: $e');
    }

    // 선택된 친구들의 프로필 이미지 (이미 메모리에 있음)
    for (final friend in friends) {
      if (friend.profileImageUrl?.isNotEmpty == true) {
        images[friend.uid] = friend.profileImageUrl!;
      }
    }

    return images;
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(_snackBarComponenet(message));
    }
  }

  SnackBar _showSuccessSnackBar() {
    return SnackBar(
      content: Row(
        children: [
          SvgPicture.asset(
            'assets/archive_icon.svg',
            width: 19.sp,
            height: 17.sp,
            colorFilter: ColorFilter.mode(Color(0xffc2c0c0), BlendMode.srcIn),
          ),
          SizedBox(width: 15.w),
          Text(
            '새 카테고리가 추가 되었습니다.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      backgroundColor: Color(0xFF323232),
      duration: Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.5)),
    );
  }

  SnackBar _snackBarComponenet(String content) {
    return SnackBar(
      content: Text(content, style: TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF5A5A5A),
    );
  }

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
    _authController?.removeListener(_handleAuthControllerUpdated);

    PaintingBinding.instance.imageCache.clear();
    super.dispose();
  }
}

Widget _buildAvatarShimmer() {
  return Shimmer.fromColors(
    baseColor: Colors.grey.shade600,
    highlightColor: Colors.grey.shade400,
    child: Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
    ),
  );
}

Widget _buildAvatarFallback() {
  return Container(
    width: 60,
    height: 60,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFd9d9d9),
    ),
    child: const Icon(Icons.person, color: Colors.white, size: 26),
  );
}
