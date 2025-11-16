import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:soi/api_firebase/controllers/category_cover_photo_controller.dart';
import '../../../../api_firebase/controllers/auth_controller.dart';
import '../../../../api_firebase/controllers/category_controller.dart';
import '../../../../api_firebase/models/auth_model.dart';
import '../../../../api_firebase/models/category_data_model.dart';
import '../../../about_friends/friend_list_add_screen.dart';
import '../../widgets/exit_button.dart';
import '../../widgets/category_edit_widget/add_friend_button.dart';
import '../../widgets/category_edit_widget/category_cover_section.dart';
import '../../widgets/category_edit_widget/category_info_section.dart';
import '../../widgets/category_edit_widget/friends_list_widget.dart';
import '../../widgets/category_edit_widget/notification_setting_section.dart';
import 'category_cover_photo_selector_screen.dart';

class CategoryEditorScreen extends StatefulWidget {
  final CategoryDataModel category;

  const CategoryEditorScreen({super.key, required this.category});

  @override
  State<CategoryEditorScreen> createState() => _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends State<CategoryEditorScreen>
    with WidgetsBindingObserver {
  bool _isExpanded = false;

  // 친구 정보 캐시
  Map<String, AuthModel> _friendsInfo = {};
  bool _isLoadingFriends = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFriendsInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PaintingBinding.instance.imageCache.clear();
    super.dispose();
  }

  // 외부에서 호출 가능한 친구 정보 새로고침 메서드
  void refreshFriendsInfo() {
    if (mounted) {
      _loadFriendsInfo();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 앱이 다시 활성화될 때 친구 정보 새로고침
    if (state == AppLifecycleState.resumed && mounted) {
      _loadFriendsInfo();
    }
  }

  @override
  void didUpdateWidget(CategoryEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 카테고리가 변경되었거나 mates가 변경된 경우 친구 정보 다시 로드
    if (oldWidget.category.id != widget.category.id ||
        !_listsEqual(oldWidget.category.mates, widget.category.mates)) {
      _loadFriendsInfo();
    }
  }

  // 리스트 비교 헬퍼 함수
  bool _listsEqual<T>(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  // 친구 정보 로드 (재시도 로직 포함)
  Future<void> _loadFriendsInfo({int retryCount = 0}) async {
    // CategoryController에서 최신 카테고리 정보 가져오기
    final categoryController = context.read<CategoryController>();
    final currentCategory = categoryController.userCategories.firstWhere(
      (cat) => cat.id == widget.category.id,
      orElse: () => widget.category,
    );

    final currentMates = currentCategory.mates;

    if (currentMates.isEmpty) {
      setState(() {
        _isLoadingFriends = false;
        _friendsInfo = {};
      });
      return;
    }

    setState(() {
      _isLoadingFriends = true;
    });

    try {
      final authController = context.read<AuthController>();
      final Map<String, AuthModel> friendsInfo = {};
      final List<String> failedUids = [];

      // 각 친구 정보를 순차적으로 로드 (최신 mates 사용)
      for (String mateUid in currentMates) {
        try {
          final userInfo = await _getUserInfoWithRetry(authController, mateUid);
          if (userInfo != null) {
            friendsInfo[mateUid] = userInfo;
          } else {
            failedUids.add(mateUid);
          }
        } catch (e) {
          failedUids.add(mateUid);
        }
      }

      if (mounted) {
        setState(() {
          _friendsInfo = friendsInfo;
          _isLoadingFriends = false;
        });
      }

      // 실패한 항목이 있고 첫 번째 재시도인 경우 재시도
      if (failedUids.isNotEmpty && retryCount == 0) {
        Future.delayed(Duration(seconds: 3), () {
          if (mounted) {
            _retryFailedUsers(failedUids);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }

      // 전체 재시도 (최대 1회)
      if (retryCount == 0) {
        Future.delayed(Duration(seconds: 5), () {
          if (mounted) {
            _loadFriendsInfo(retryCount: 1);
          }
        });
      }
    }
  }

  // 개별 사용자 정보 로드 (재시도 포함)
  Future<AuthModel?> _getUserInfoWithRetry(
    AuthController authController,
    String uid, {
    int maxRetries = 2,
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final userInfo = await authController.getUserInfo(uid);

        if (userInfo != null) {
          return userInfo;
        }

        // null인 경우 잠시 대기 후 재시도
        if (attempt < maxRetries) {
          final delay = 500 * (attempt + 1);

          await Future.delayed(Duration(milliseconds: delay));
        }
      } catch (e) {
        if (attempt < maxRetries) {
          final delay = 1000 * (attempt + 1);

          await Future.delayed(Duration(milliseconds: delay));
        }
      }
    }

    return null;
  }

  // 실패한 사용자들만 재시도
  Future<void> _retryFailedUsers(List<String> failedUids) async {
    if (failedUids.isEmpty) return;

    try {
      final authController = context.read<AuthController>();
      final Map<String, AuthModel> updatedFriendsInfo = Map.from(_friendsInfo);

      for (String uid in failedUids) {
        try {
          final userInfo = await _getUserInfoWithRetry(authController, uid);
          if (userInfo != null) {
            updatedFriendsInfo[uid] = userInfo;
          }
        } catch (e) {
          // 재시도 실패 시 무시
        }
      }

      if (mounted) {
        setState(() {
          _friendsInfo = updatedFriendsInfo;
        });
      }
    } catch (e) {
      // 전체 재시도 실패 시 무시
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryController>(
      builder: (context, categoryController, child) {
        final currentCategory = categoryController.userCategories.firstWhere(
          (cat) => cat.id == widget.category.id,
          orElse: () => widget.category,
        );

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
              '수정하기',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                fontFamily: 'Pretendard Variable',
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 표지사진 수정 섹션
                  CategoryCoverSection(
                    category: currentCategory,
                    onTap: () => _showCoverPhotoBottomSheet(context),
                  ),

                  SizedBox(height: 24.h),

                  // 카테고리 이름 섹션
                  CategoryInfoSection(category: currentCategory),

                  SizedBox(height: 12),

                  // 알림설정 섹션
                  NotificationSettingSection(),
                  SizedBox(height: 24.h),

                  // 친구 추가 섹션
                  currentCategory.mates.isNotEmpty
                      ? FriendsListWidget(
                          category: currentCategory,
                          friendsInfo: _friendsInfo,
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
                          onFriendAdded: () {
                            // 친구 추가 후 정보 새로고침
                            if (mounted) {
                              _loadFriendsInfo();
                            }
                          },
                        )
                      : AddFriendButton(
                          category: currentCategory,
                          onPressed: () async {
                            // FriendListAddScreen으로 이동
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => FriendListAddScreen(
                                  categoryId: currentCategory.id,
                                  categoryMemberUids: currentCategory.mates,
                                ),
                              ),
                            );

                            // 돌아온 후 친구 정보만 새로고침
                            if (mounted) {
                              _loadFriendsInfo();
                            }
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
                '표지 사진 수정',
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 18.sp,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w700,
                ),
              ),

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
                  '사진찍기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Pretendard Variable',
                  ),
                ),
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
                  '라이브러리에서 선택',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Pretendard Variable',
                  ),
                ),
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
                  '카테고리에서 선택',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Pretendard Variable',
                  ),
                ),
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
                  '표지삭제',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Pretendard Variable',
                  ),
                ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('카메라 촬영 중 오류가 발생했습니다.'),
          backgroundColor: Color(0xFF5a5a5a),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('갤러리 선택 중 오류가 발생했습니다.'),
          backgroundColor: Color(0xFF5a5a5a),
        ),
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

    if (result != null && mounted) {
      final categoryController = context.read<CategoryController>();
      final authController = context.read<AuthController>();
      final userId = authController.getUserId;
      if (userId != null) {
        await categoryController.loadUserCategories(userId, forceReload: true);
      }
    }
  }

  /// 갤러리/카메라에서 선택한 파일로 표지사진 업데이트
  Future<void> _updateCoverPhoto(File imageFile) async {
    final categoryPhotoController = context
        .read<CategoryCoverPhotoController>();
    final categoryController = context.read<CategoryController>();

    final success = await categoryPhotoController.updateCoverPhotoFromGallery(
      categoryId: widget.category.id,
      imageFile: imageFile,
    );

    if (success && mounted) {
      // 카테고리 데이터 다시 로드
      final authController = context.read<AuthController>();
      final userId = authController.getUserId;
      if (userId != null) {
        await categoryController.loadUserCategories(userId, forceReload: true);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '표지사진이 변경되었습니다.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Color(0xFF5a5a5a),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(categoryController.error ?? '표지사진 변경에 실패했습니다.'),
          backgroundColor: const Color(0xFF5a5a5a),
        ),
      );
    }
  }

  /// 표지사진 삭제
  Future<void> _deleteCoverPhoto() async {
    final categoryPhotoController = context
        .read<CategoryCoverPhotoController>();
    final categoryController = context.read<CategoryController>();

    final success = await categoryPhotoController.deleteCoverPhoto(
      widget.category.id,
    );

    if (success && mounted) {
      // 카테고리 데이터 다시 로드
      final authController = context.read<AuthController>();
      final userId = authController.getUserId;
      if (userId != null) {
        await categoryController.loadUserCategories(userId, forceReload: true);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('표지사진이 삭제되었습니다.'),
          backgroundColor: Color(0xFF5a5a5a),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(categoryController.error ?? '표지사진 삭제에 실패했습니다.'),
          backgroundColor: const Color(0xFF5a5a5a),
        ),
      );
    }
  }
}
