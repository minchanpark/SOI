import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import '../../../../api/controller/category_controller.dart' as api_category;
import '../../../../api/controller/media_controller.dart';
import '../../../../api/controller/user_controller.dart';
import '../../../../api/models/category.dart';
import '../../../../api/models/user.dart';
import '../../../../api/services/media_service.dart';
import '../../../../utils/snackbar_utils.dart';
import '../../../about_friends/friend_list_add_screen.dart';
import '../../widgets/exit_button.dart';
import '../../widgets/category_edit_widget/add_friend_button.dart';
import '../../widgets/category_edit_widget/category_cover_section.dart';
import '../../widgets/category_edit_widget/category_info_section.dart';
import '../../widgets/category_edit_widget/friends_list_widget.dart';
import 'category_cover_photo_selector_screen.dart';
import '../../widgets/category_edit_widget/notification_setting_section.dart';

/// 카테고리 편집 화면
///
/// 카테고리의 표지사진, 이름, 알림설정, 친구 추가/삭제 등을 관리합니다.
///
/// Parameters:
///  - [category]: 편집할 카테고리 데이터 모델
class CategoryEditorScreen extends StatefulWidget {
  final Category category;

  const CategoryEditorScreen({super.key, required this.category});

  @override
  State<CategoryEditorScreen> createState() => _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends State<CategoryEditorScreen>
    with WidgetsBindingObserver {
  bool _isExpanded = false;

  // 멤버 정보 캐시 (API 기반)
  List<CategoryMemberViewModel> _members = [];
  bool _isLoadingFriends = false;

  // 표지사진 URL(Resolved) 캐시
  String? _coverPhotoUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCategoryCoverPhoto();
      _loadMembers();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // (배포버전 프리즈 방지) 전역 imageCache.clear()는 캐시가 큰 실사용 환경에서
    // dispose 타이밍에 수 초 프리즈를 만들 수 있어 제거합니다.
    super.dispose();
  }

  // 외부에서 호출 가능한 친구 정보 새로고침 메서드
  void refreshFriendsInfo() {
    if (mounted) {
      _loadMembers();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 앱이 다시 활성화될 때 친구 정보 새로고침
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshCategoryCoverPhoto();
      _loadMembers();
    }
  }

  @override
  void didUpdateWidget(CategoryEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.category.id != widget.category.id) {
      _refreshCategoryCoverPhoto();
      _loadMembers();
    }
  }

  Category _getCurrentCategory(api_category.CategoryController controller) {
    return controller.getCategoryById(widget.category.id) ?? widget.category;
  }

  Future<void> _refreshCategoryCoverPhoto() async {
    final controller = context.read<api_category.CategoryController>();
    final currentCategory = _getCurrentCategory(controller);
    final photoKey = currentCategory.photoUrl;

    if (photoKey == null || photoKey.isEmpty) {
      if (!mounted) return;
      setState(() => _coverPhotoUrl = null);
      return;
    }

    final uri = Uri.tryParse(photoKey);
    if (uri != null && uri.hasScheme) {
      if (!mounted) return;
      setState(() => _coverPhotoUrl = photoKey);
      return;
    }

    final mediaController = context.read<MediaController>();
    final url = await mediaController.getPresignedUrl(photoKey);
    if (!mounted) return;
    setState(() => _coverPhotoUrl = url);
  }

  Future<void> _loadMembers() async {
    if (!mounted) return;
    setState(() => _isLoadingFriends = true);

    try {
      final categoryController = context
          .read<api_category.CategoryController>();
      final userController = context.read<UserController>();
      final mediaController = context.read<MediaController>();

      final currentCategory = _getCurrentCategory(categoryController);
      final nicknames = currentCategory.nickNames;
      final profileKeys = currentCategory.usersProfileKey;

      if (nicknames.isEmpty) {
        if (!mounted) return;
        setState(() {
          _members = const [];
          _isLoadingFriends = false;
        });
        return;
      }

      final futures = <Future<CategoryMemberViewModel>>[];
      for (int i = 0; i < nicknames.length; i++) {
        futures.add(
          _buildMemberViewModel(
            nickname: nicknames[i],
            profileKey: i < profileKeys.length ? profileKeys[i] : null,
            userController: userController,
            mediaController: mediaController,
          ),
        );
      }

      final resolvedMembers = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        _members = resolvedMembers;
        _isLoadingFriends = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingFriends = false);
    }
  }

  Future<CategoryMemberViewModel> _buildMemberViewModel({
    required String nickname,
    required String? profileKey,
    required UserController userController,
    required MediaController mediaController,
  }) async {
    String? profileUrl;
    if (profileKey != null && profileKey.isNotEmpty) {
      final uri = Uri.tryParse(profileKey);
      if (uri != null && uri.hasScheme) {
        profileUrl = profileKey;
      } else {
        profileUrl = await mediaController.getPresignedUrl(profileKey);
      }
    }

    User? user;
    try {
      user = await userController.getUserByNickname(nickname);
    } catch (_) {}

    final displayName = (user != null && user.name.isNotEmpty)
        ? user.name
        : nickname;
    final subtitle = user?.userId ?? nickname;
    final resolvedUserId = user?.id ?? int.tryParse(nickname);

    return CategoryMemberViewModel(
      userId: resolvedUserId,
      displayName: displayName,
      profileImageUrl: profileUrl,
      subtitle: subtitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<api_category.CategoryController>(
      builder: (context, categoryController, child) {
        final currentCategory = _getCurrentCategory(categoryController);

        return Scaffold(
          backgroundColor: const Color(0xFF111111),
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
            backgroundColor: const Color(0xFF111111),
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleSpacing: 0,
            title: Text(
              'category.edit_title',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Pretendard Variable',
              ),
            ).tr(),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 표지사진 수정 섹션
                  CategoryCoverSection(
                    imageUrl: _coverPhotoUrl,
                    onTap: () => _showCoverPhotoBottomSheet(context),
                  ),

                  SizedBox(height: 24.h),

                  // 카테고리 이름 섹션
                  CategoryInfoSection(category: currentCategory),

                  SizedBox(height: 12),

                  // 알림설정 섹션
                  NotificationSettingSection(categoryId: currentCategory.id),
                  SizedBox(height: 24.h),

                  // 친구 추가 섹션
                  currentCategory.nickNames.isNotEmpty
                      ? FriendsListWidget(
                          members: _members,
                          isLoadingFriends: _isLoadingFriends,
                          isExpanded: _isExpanded,
                          onExpandToggle: () {
                            setState(() {
                              _isExpanded = true;
                            });
                          },
                          onCollapseToggle: () {
                            setState(() {
                              _isExpanded = false;
                            });
                          },
                          onFriendAdded: () =>
                              _navigateToAddFriends(currentCategory),
                        )
                      : AddFriendButton(
                          onPressed: () async {
                            await _navigateToAddFriends(currentCategory);
                          },
                        ),
                  SizedBox(height: 24.h),

                  // 나가기 버튼
                  ExitButton(category: currentCategory),

                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 표지사진 수정 바텀시트
  void _showCoverPhotoBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1c1c1c),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 핸들바
              Container(
                margin: EdgeInsets.only(top: 12.w),
                width: 56.w,
                height: 3.h,
                decoration: BoxDecoration(
                  color: const Color(0xFFcccccc),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 9.h),
              Text(
                'category.cover.edit_sheet_title',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 18.sp,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w700,
                ),
              ).tr(),

              Divider(color: const Color(0xFF5A5A5A)),

              // 카메라로 촬영
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 0.h,
                ),
                leading: Image.asset(
                  'assets/camera_archive_edit.png',
                  width: 24.w,
                  height: 24.h,
                ),
                title: Text(
                  'category.cover.select_take_photo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Pretendard Variable',
                  ),
                ).tr(),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),

              // 갤러리에서 선택
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 0.h,
                ),
                leading: Image.asset(
                  'assets/library_archive_edit.png',
                  width: 24.w,
                  height: 24.h,
                ),
                title: Text(
                  'category.cover.select_from_library',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Pretendard Variable',
                  ),
                ).tr(),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),

              // 카테고리에서 선택
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 0.h,
                ),
                leading: Image.asset(
                  'assets/archiving_archive.png',
                  width: 24.w,
                  height: 24.h,
                ),
                title: Text(
                  'category.cover.select_from_category',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Pretendard Variable',
                  ),
                ).tr(),
                onTap: () {
                  Navigator.pop(context);
                  _selectFromCategory();
                },
              ),

              // 표지삭제
              ListTile(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 0.h,
                ),
                leading: Image.asset(
                  'assets/trash_archive_edit.png',
                  width: 24.w,
                  height: 24.h,
                ),
                title: Text(
                  'category.cover.delete_button',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Pretendard Variable',
                  ),
                ).tr(),
                onTap: () {
                  Navigator.pop(context);
                  _deleteCoverPhoto();
                },
              ),

              SizedBox(height: 30.h),
            ],
          ),
        );
      },
    );
  }

  /// 카메라로 사진 촬영
  Future<void> _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        final imageFile = File(image.path);
        await _updateCoverPhoto(imageFile);
      }
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        tr('category.cover.camera_error', context: context),
      );
    }
  }

  /// 갤러리에서 사진 선택
  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        final imageFile = File(image.path);
        await _updateCoverPhoto(imageFile);
      }
    } catch (e) {
      SnackBarUtils.showSnackBar(
        context,
        tr('category.cover.gallery_error', context: context),
      );
    }
  }

  /// 카테고리에서 사진 선택
  Future<void> _selectFromCategory() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CategoryCoverPhotoSelectorScreen(category: widget.category),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      await _reloadCategoryCache();
    }
  }

  /// 갤러리/카메라에서 선택한 파일로 표지사진 업데이트
  Future<void> _updateCoverPhoto(File imageFile) async {
    try {
      final userController = context.read<UserController>();
      final currentUser = userController.currentUser;
      if (currentUser == null) {
        _showSnackBar(tr('common.login_required', context: context));
        return;
      }

      final mediaController = context.read<MediaController>();
      final multipart = await mediaController.fileToMultipart(imageFile);
      final keys = await mediaController.uploadMedia(
        files: [multipart],
        types: [MediaType.image],
        usageTypes: [MediaUsageType.categoryProfile],
        userId: currentUser.id,
        refId: widget.category.id,
        usageCount: 1,
      );

      if (keys.isEmpty) {
        _showSnackBar(tr('category.cover.upload_failed', context: context));
        return;
      }

      final categoryController = context
          .read<api_category.CategoryController>();
      final success = await categoryController.updateCustomProfile(
        categoryId: widget.category.id,
        userId: currentUser.id,
        profileImageKey: keys.first,
      );

      if (!success) {
        final message =
            categoryController.errorMessage ??
            tr('category.cover.update_failed', context: context);
        _showSnackBar(message);
        return;
      }

      await _reloadCategoryCache();
      _showSnackBar(tr('category.cover.updated', context: context));
    } catch (_) {
      _showSnackBar(tr('category.cover.update_error', context: context));
    }
  }

  /// 표지사진 삭제
  Future<void> _deleteCoverPhoto() async {
    try {
      final userController = context.read<UserController>();
      final currentUser = userController.currentUser;
      if (currentUser == null) {
        _showSnackBar(tr('common.login_required', context: context));
        return;
      }

      final categoryController = context
          .read<api_category.CategoryController>();
      final success = await categoryController.updateCustomProfile(
        categoryId: widget.category.id,
        userId: currentUser.id,
        profileImageKey: '',
      );

      if (!success) {
        final message =
            categoryController.errorMessage ??
            tr('category.cover.delete_failed', context: context);
        _showSnackBar(message);
        return;
      }

      await _reloadCategoryCache();
      _showSnackBar(tr('category.cover.deleted', context: context));
    } catch (_) {
      _showSnackBar(tr('category.cover.delete_error', context: context));
    }
  }

  Future<void> _navigateToAddFriends(Category category) async {
    final existingMemberUids = _members
        .map((member) => member.userId)
        .whereType<int>()
        .map((id) => id.toString())
        .toList(growable: false);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FriendListAddScreen(
          categoryId: category.id.toString(),
          categoryMemberUids: existingMemberUids.isNotEmpty
              ? existingMemberUids
              : category.nickNames,
          allowDeselection: false,
        ),
      ),
    );
    if (!mounted) return;
    await _reloadCategoryCache();
  }

  Future<void> _reloadCategoryCache() async {
    final userController = context.read<UserController>();
    final currentUser = userController.currentUser;
    if (currentUser == null) return;

    final categoryController = context.read<api_category.CategoryController>();
    await categoryController.loadCategories(currentUser.id, forceReload: true);

    if (!mounted) return;
    await _refreshCategoryCoverPhoto();
    await _loadMembers();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    SnackBarUtils.showSnackBar(context, message);
  }
}
