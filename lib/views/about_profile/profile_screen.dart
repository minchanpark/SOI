import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../api/controller/category_controller.dart';
import '../../api/controller/media_controller.dart';
import '../../api/controller/user_controller.dart';
import '../../api/models/user.dart';
import '../about_feed/manager/feed_data_manager.dart';
import '../../utils/snackbar_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // 사용자 정보
  User? _userInfo;
  User? currentUser;
  User? userInfo;

  // 프로필 이미지 URL
  String? _profileImageUrl;
  String? _profileImageUrlKey;

  // 로딩 상태
  bool _isLoading = true;
  bool _isUploadingProfile = false;
  int _profileImageRetryCount = 0;
  bool _profileImageLoadFailed = false;

  // 알림 설정 상태
  bool _isNotificationEnabled = false;

  // API 컨트롤러들
  UserController? userController;
  MediaController? mediaController;

  @override
  void initState() {
    super.initState();
    // 빌드가 완료된 후 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    // UserController 인스턴스 가져오기
    userController = context.read<UserController>();
    mediaController = context.read<MediaController>();

    // UserController의 currentUser 사용.
    // 현재 로그인한 사용자의 정보를 가지고 온다.
    currentUser = userController!.currentUser;

    if (currentUser != null) {
      try {
        // API에서 사용자 정보 가져오기
        userInfo = await userController!.getUser(currentUser!.id);

        _profileImageUrlKey = userInfo?.profileImageUrlKey;

        // presigned URL 가져오기 (키가 있을 경우에만)
        String? presignedUrl;
        if (_profileImageUrlKey != null && _profileImageUrlKey!.isNotEmpty) {
          presignedUrl = await mediaController!.getPresignedUrl(
            _profileImageUrlKey!,
          );
        }

        if (!mounted) return;
        setState(() {
          _userInfo = userInfo;
          _profileImageUrl = presignedUrl; // 프로필 이미지 URL 설정
          _profileImageRetryCount = 0; // 재시도 카운트 초기화
          _profileImageLoadFailed = false; // 프로필 이미지 로드에 실패하였을 때, false로 초기화
          _isLoading = false;
        });
      } catch (e) {
        debugPrint('사용자 데이터 로드 오류: $e');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      debugPrint('currentUser가 null입니다.');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 프로필 이미지 업데이트 메서드
  Future<void> _updateProfileImage() async {
    try {
      final picker = ImagePicker();
      final userController = context.read<UserController>();
      final mediaController = context.read<MediaController>();
      final current = userController.currentUser;

      if (current == null) {
        _showProfileSnackBar(
          tr('profile.snackbar.login_required', context: context),
        );
        return;
      }

      final XFile? pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (pickedImage == null) return;

      final file = File(pickedImage.path);
      if (!await file.exists()) {
        _showProfileSnackBar(
          tr('profile.snackbar.image_not_found', context: context),
        );
        return;
      }

      final compressedFile = await _compressProfileImage(file);

      if (!mounted) return;
      setState(() {
        _isUploadingProfile = true;
      });

      final multipartFile = await mediaController.fileToMultipart(
        compressedFile,
      );
      final profileKey = await mediaController.uploadProfileImage(
        file: multipartFile,
        userId: current.id,
      );

      if (profileKey == null) {
        _showProfileSnackBar(
          tr('profile.snackbar.upload_failed', context: context),
        );
        return;
      }

      final updatedUser = await userController.updateprofileImageUrl(
        userId: current.id,
        profileImageKey: profileKey,
      );

      if (updatedUser != null) {
        userController.setCurrentUser(updatedUser);
      }

      await userController.refreshCurrentUser();

      // 카테고리 캐시 무효화 및 재로딩
      if (mounted) {
        // 카테고리 컨트롤러 가져오기
        final categoryController = context.read<CategoryController>();

        // 캐시 무효화
        categoryController.invalidateCache();

        // 카테고리 재로딩
        await categoryController.loadCategories(current.id, forceReload: true);
      }

      final newProfileImageUrl = await mediaController.getPresignedUrl(
        profileKey,
      );

      if (!mounted) return;

      final refreshedUser = userController.currentUser;
      final resolvedProfileKey =
          refreshedUser?.profileImageUrlKey ?? profileKey;

      setState(() {
        _profileImageUrlKey = resolvedProfileKey;
        _profileImageUrl = newProfileImageUrl;
        _profileImageRetryCount = 0; // 재시도 카운트 초기화
        _profileImageLoadFailed = false; // 프로필 이미지 로드에 실패하였을 때, false로 초기화
        _userInfo = refreshedUser ?? updatedUser ?? _userInfo;
      });

      _showProfileSnackBar(
        tr('profile.snackbar.profile_updated', context: context),
      );
    } catch (e) {
      debugPrint('프로필 이미지 업데이트 오류: $e');
      if (mounted) {
        _showProfileSnackBar(
          tr('profile.snackbar.profile_update_failed', context: context),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingProfile = false;
        });
      }
    }
  }

  /// 프로필 이미지를 업로드하기 전에 압축한다.
  Future<File> _compressProfileImage(File file) async {
    try {
      final targetPath =
          '${file.parent.path}/profile_${DateTime.now().millisecondsSinceEpoch}.webp';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1080,
        minHeight: 1080,
        format: CompressFormat.webp,
      );

      // XFile을 File로 변환
      if (compressedFile != null) {
        return File(compressedFile.path);
      }

      return file;
    } catch (e) {
      debugPrint('프로필 이미지 압축 오류: $e');
      return file;
    }
  }

  /// 로그아웃 바텀시트 표시
  void _showLogoutDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF323232),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 34.h),
              Text(
                tr('profile.logout.title', context: context),
                style: TextStyle(
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w700,
                  fontSize: 19.8.sp,
                  color: const Color(0xFFF9F9F9),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 28.h),
              SizedBox(
                width: 344.w,
                height: 38.h,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _performLogout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF9F9F9),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                  child: Text(
                    tr('profile.logout.confirm', context: context),
                    style: TextStyle(
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w600,
                      fontSize: 17.8.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              SizedBox(
                width: 344.w,
                height: 38.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF323232),
                    elevation: 0,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                  child: Text(
                    tr('common.cancel', context: context),
                    style: TextStyle(
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w500,
                      fontSize: 17.8.sp,
                      color: const Color(0xFFCCCCCC),
                    ),
                  ),
                ),
              ),
              SizedBox(height: (16.5).h),
            ],
          ),
        );
      },
    );
  }

  /// 실제 로그아웃 수행
  Future<void> _performLogout() async {
    try {
      final apiUserController = context.read<UserController>();

      // UserController 로그아웃 (SharedPreferences 정리 + currentUser null)
      await apiUserController.logout();

      if (mounted) {
        // 로그아웃시, 피드의 캐시를 비운다.
        context.read<FeedDataManager>().reset();
      }

      if (mounted) {
        // 로그아웃 성공 시 로그인 화면으로 이동
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/start', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showSnackBar(
          context,
          tr('profile.snackbar.logout_failed', context: context),
        );
      }
    }
  }

  /// 계정 삭제 바텀시트 표시
  void _showDeleteAccountDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF323232),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 26.h),
              Text(
                tr('profile.delete_account.title', context: context),
                style: TextStyle(
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w700,
                  fontSize: 19.8.sp,
                  color: const Color(0xFFF9F9F9),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Text(
                  tr('profile.delete_account.description', context: context),
                  style: TextStyle(
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w500,
                    fontSize: 15.8.sp,
                    height: 1.6,
                    color: const Color(0xFFF9F9F9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 28.h),
              SizedBox(
                width: 344.w,
                height: 38.h,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _performDeleteAccount();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF9F9F9),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                  child: Text(
                    tr('profile.delete_account.confirm', context: context),
                    style: TextStyle(
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w600,
                      fontSize: 17.8.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              SizedBox(
                width: 344.w,
                height: 38.h,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: const Color(0xFF323232),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                  child: Text(
                    tr('common.cancel', context: context),
                    style: TextStyle(
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w500,
                      fontSize: 17.8.sp,
                      color: const Color(0xFFCCCCCC),
                    ),
                  ),
                ),
              ),
              SizedBox(height: (16.5).h),
            ],
          ),
        );
      },
    );
  }

  /// 실제 계정 삭제 수행
  Future<void> _performDeleteAccount() async {
    try {
      final apiUserController = context.read<UserController>();

      // 로딩 표시
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        );
      }

      // 계정 삭제 실행 (비동기 시작)
      final deletion = apiUserController.deleteUser(
        apiUserController.currentUser!.id,
      );

      // 회원탈퇴시, 피드의 캐시를 비운다.
      if (mounted) {
        context.read<FeedDataManager>().reset();
      }

      if (mounted) {
        // 로딩 다이얼로그 닫기 후 즉시 시작 화면으로 이동
        Navigator.of(context).pop();
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/start', (route) => false);
      }

      // 백그라운드에서 삭제 진행 에러는 로깅만
      // ignore: unawaited_futures
      deletion.catchError((e) {
        debugPrint('계정 삭제 백그라운드 오류: $e');
        return e;
      });
    } catch (e) {
      if (mounted) {
        // 로딩 다이얼로그 닫기
        Navigator.of(context).pop();

        // 에러 메시지 표시
        SnackBarUtils.showSnackBar(
          context,
          tr(
            'profile.snackbar.delete_account_failed',
            context: context,
            namedArgs: {'error': e.toString()},
          ),
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Color(0xffd9d9d9)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              tr('profile.title', context: context),
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 20.sp,
                color: const Color(0xFFD9D9D9),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD9D9D9)),
              )
            : SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 17.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(),
                      _buildAccountSection(),
                      SizedBox(height: 36.h),
                      _buildAppSettingsSection(),
                      SizedBox(height: 36.h),
                      _buildUsageGuideSection(),
                      SizedBox(height: 36.h),
                      _buildOtherSection(),
                      SizedBox(height: 49.h),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: _updateProfileImage,
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFD9D9D9),
                ),
                child: Stack(
                  children: [
                    // 프로필 이미지 또는 기본 아이콘
                    _profileImageUrl != null &&
                            _profileImageUrl!.isNotEmpty &&
                            !_profileImageLoadFailed
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: _profileImageUrl!,
                              memCacheWidth: (96 * 4).round(),
                              maxWidthDiskCache: (96 * 4).round(),
                              fit: BoxFit.cover,
                              width: 96,
                              height: 96,

                              // 로딩 중일 때는 shimmer 효과 표시
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: const Color(0xFF2A2A2A),
                                highlightColor: const Color(0xFF3A3A3A),
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF2A2A2A),
                                  ),
                                ),
                              ),

                              // 에러 시 재시도 로직
                              errorWidget: (context, error, stackTrace) {
                                // 두 번째 시도까지 재시도
                                if (_profileImageRetryCount < 2) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      setState(() {
                                        _profileImageRetryCount++;
                                      });
                                      // 캐시 클리어 후 다시 로드
                                      CachedNetworkImage.evictFromCache(
                                        _profileImageUrl!,
                                      );
                                    }
                                  });
                                  return Shimmer.fromColors(
                                    baseColor: const Color(0xFF2A2A2A),
                                    highlightColor: const Color(0xFF3A3A3A),
                                    child: Container(
                                      width: 96,
                                      height: 96,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF2A2A2A),
                                      ),
                                    ),
                                  );
                                }
                                // 두 번 시도 후 실패하면 아이콘 표시
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) {
                                    setState(() {
                                      _profileImageLoadFailed = true;
                                    });
                                  }
                                });
                                return Icon(
                                  Icons.person,
                                  size: 76.sp,
                                  color: Colors.white,
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.person,
                              size: 76.sp,
                              color: Colors.white,
                            ),
                          ),
                    // 업로딩 중일 때 로딩 표시
                    if (_isUploadingProfile)
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0.w,
              bottom: 4.h,
              child: GestureDetector(
                onTap: _updateProfileImage,
                child: Image.asset(
                  'assets/pencil.png',
                  width: (25.41).w,
                  height: (25.41).h,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 16.w),
            Text(
              tr('profile.section.account', context: context),
              style: TextStyle(
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w700,
                fontSize: 20.sp,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        _buildAccountCard(
          tr('profile.account.id_label', context: context),
          _userInfo?.userId ?? '',
        ),
        SizedBox(height: 7.h),
        _buildAccountCard(
          tr('profile.account.name_label', context: context),
          _userInfo?.name ?? '',
        ),
        SizedBox(height: 7.h),
        _buildAccountCard(
          tr('profile.account.birth_label', context: context),
          _userInfo?.birthDate ?? '',
        ),
        // 전화번호는 현재 표시하지 않음.
        /*
        SizedBox(height: 7.h),
        _buildAccountCard(
          tr('profile.account.phone_label', context: context),
          (_userInfo?.phoneNumber ?? '') == '010-000-0000'
              ? ''
              : (_userInfo?.phoneNumber ?? ''),
        ),
        */
      ],
    );
  }

  Widget _buildAccountCard(String label, String value) {
    return Container(
      width: double.infinity,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.symmetric(horizontal: 19.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w400,
              fontSize: 13.sp,
              color: const Color(0xFFCCCCCC),
            ),
          ),
          SizedBox(height: 7.h),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w400,
                  fontSize: 16.sp,
                  color: const Color(0xFFF9F9F9),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 16.w),
            Text(
              tr('profile.section.app_settings', context: context),
              style: TextStyle(
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w700,
                fontSize: 20.sp,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              /*  _buildSettingsItem('알림 설정', hasToggle: true),
              Divider(height: 1, color: const Color(0xFF323232)),*/
              _buildSettingsItem(
                tr('profile.settings.language', context: context),
                value: tr('profile.settings.language_ko', context: context),
              ),
              Divider(height: 1, color: const Color(0xFF323232)),
              _buildSettingsItem(
                tr('profile.settings.privacy', context: context),
                value: '',
                onTap: () {
                  Navigator.pushNamed(context, '/privacy_protect');
                },
              ),
              Divider(height: 1, color: const Color(0xFF323232)),
              _buildSettingsItem(
                tr('profile.settings.post_management', context: context),
                value: '',
                onTap: () {
                  Navigator.pushNamed(context, '/post_management');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsageGuideSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 16.w),
            Text(
              tr('profile.section.usage_guide', context: context),
              style: TextStyle(
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w700,
                fontSize: 20.sp,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildSettingsItem(
                tr('profile.usage.privacy_policy', context: context),
                onTap: () {
                  Navigator.pushNamed(context, '/privacy_policy');
                },
              ),
              Divider(height: 1, color: const Color(0xFF323232)),
              _buildSettingsItem(
                tr('profile.usage.terms_of_service', context: context),
                onTap: () {
                  Navigator.pushNamed(context, '/terms_of_service');
                },
              ),
              Divider(height: 1, color: const Color(0xFF323232)),
              _buildSettingsItem(
                tr('profile.usage.app_version', context: context),
                value: tr('profile.usage.app_version_value', context: context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOtherSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(width: 16.w),
            Text(
              tr('profile.section.other', context: context),
              style: TextStyle(
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w700,
                fontSize: 20.sp,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildSettingsItem(
                tr('profile.other.app_info_consent', context: context),
              ),
              Divider(height: 1, color: const Color(0xFF323232)),

              _buildSettingsItem(
                tr('profile.other.delete_account', context: context),
                isRed: true,
                onTap: _showDeleteAccountDialog,
              ),
              Divider(height: 1, color: const Color(0xFF323232)),
              _buildSettingsItem(
                tr('profile.other.logout', context: context),
                isRed: true,
                onTap: _showLogoutDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(
    String title, {
    String? value,
    bool hasToggle = false,
    bool isRed = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w400,
                  fontSize: 16.sp,
                  color: isRed
                      ? const Color(0xFFFF0000)
                      : const Color(0xFFF9F9F9),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasToggle)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isNotificationEnabled = !_isNotificationEnabled;
                  });
                },
                child: _profileSwitch(_isNotificationEnabled),
              )
            else if (value != null)
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Pretendard Variable',
                    fontWeight: FontWeight.w400,
                    fontSize: 16.sp,
                    color: const Color(0xFFF9F9F9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _profileSwitch(bool isNotificationEnabled) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 50.w,
      height: 26.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13.r),
        color: isNotificationEnabled
            ? const Color(0xffffffff)
            : const Color(0xff5a5a5a),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        alignment: isNotificationEnabled
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: Container(
          width: 22.w,
          height: 22.h,
          margin: EdgeInsets.symmetric(horizontal: 2.w),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xff000000),
          ),
        ),
      ),
    );
  }

  void _showProfileSnackBar(String message) {
    if (!mounted) return;
    SnackBarUtils.showSnackBar(context, message);
  }
}
