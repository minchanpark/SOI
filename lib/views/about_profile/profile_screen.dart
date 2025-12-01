import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../api_firebase/controllers/auth_controller.dart';
import '../../api_firebase/controllers/friend_controller.dart';
import '../../api_firebase/models/auth_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AuthModel? _userInfo;
  String? _profileImageUrl;
  bool _isLoading = true;
  bool _isNotificationEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authController = context.read<AuthController>();
    final userId = authController.getUserId;

    if (userId != null) {
      try {
        final userInfo = await authController.getUserInfo(userId);
        final profileImageUrl = await authController
            .getUserProfileImageUrlWithCache(userId);

        setState(() {
          _userInfo = userInfo;
          _profileImageUrl = profileImageUrl;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 프로필 이미지 업데이트 메서드
  Future<void> _updateProfileImage() async {
    final authController = context.read<AuthController>();

    try {
      final success = await authController.updateProfileImage();

      if (success && mounted) {
        // 프로필 이미지 업데이트 성공 시 새로운 이미지 URL 가져오기
        final userId = authController.getUserId;
        if (userId != null) {
          final newProfileImageUrl = await authController
              .getUserProfileImageUrlWithCache(userId);

          setState(() {
            _profileImageUrl = newProfileImageUrl;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('프로필 이미지 업데이트 오류: $e');
      }
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
                '로그아웃 하시겠어요?',
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
                    '확인',
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
                    '취소',
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
      final authController = context.read<AuthController>();
      final friendController = context.read<FriendController>();

      // FriendController 상태 초기화 (새 사용자 로그인 시 새로운 데이터 로드를 위해)
      await friendController.reset();

      await authController.signOut();

      if (mounted) {
        // 로그아웃 성공 시 로그인 화면으로 이동
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/start', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그아웃 중 오류가 발생했습니다.'),
            backgroundColor: Color(0xFF5A5A5A),
          ),
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
                '탈퇴하기',
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
                  '탈퇴 버튼 선택시, 계정은\n삭제되며 복구가 불가능합니다.',
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
                    '탈퇴',
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
                    '취소',
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
      final authController = context.read<AuthController>();

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
      final deletion = authController.deleteUser();

      // 로컬 로그인 상태는 즉시 정리하여 자동로그인 방지
      try {
        await authController.clearLoginState();
      } catch (_) {}

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
      });
    } catch (e) {
      if (mounted) {
        // 로딩 다이얼로그 닫기
        Navigator.of(context).pop();

        // debugPrint('계정 삭제 실패: $e');
        // 에러 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('계정 삭제 중 오류가 발생했습니다: $e'),
            backgroundColor: const Color(0xFF5A5A5A),
            duration: const Duration(seconds: 3),
          ),
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
              '프로필',
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
                    _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: _profileImageUrl!,
                              memCacheWidth: (96 * 4).round(),
                              maxWidthDiskCache: (96 * 4).round(),
                              fit: BoxFit.cover,
                              width: 96,
                              height: 96,
                              errorWidget: (context, error, stackTrace) {
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
                    if (context.watch<AuthController>().isUploading)
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
              '계정',
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
        _buildAccountCard('아이디', _userInfo?.id ?? ''),
        SizedBox(height: 7.h),
        _buildAccountCard('이름', _userInfo?.name ?? ''),
        SizedBox(height: 7.h),
        _buildAccountCard('생일', _userInfo?.birthDate ?? ''),
        SizedBox(height: 7.h),
        _buildAccountCard('전화번호', _userInfo?.phone ?? ''),
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
              '앱 설정',
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
              _buildSettingsItem('알림 설정', hasToggle: true),
              Divider(height: 1, color: const Color(0xFF323232)),
              _buildSettingsItem('언어', value: '한국어'),
              Divider(height: 1, color: const Color(0xFF323232)),
              _buildSettingsItem('개인정보 보호', value: ''),
              Divider(height: 1, color: const Color(0xFF323232)),
              _buildSettingsItem('게시물 관리', value: ''),
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
              '앱 설정',
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
              _buildSettingsItem('개인정보 처리방침'),
              Divider(height: 1, color: const Color(0xFF323232)),
              _buildSettingsItem('서비스 이용 약관'),
              Divider(height: 1, color: const Color(0xFF323232)),
              _buildSettingsItem('앱 버전', value: '1.0.0'),
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
              '기타',
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
              _buildSettingsItem('앱 정보 동의 설정'),
              Divider(height: 1, color: const Color(0xFF323232)),

              _buildSettingsItem(
                '회원 탈퇴',
                isRed: true,
                onTap: _showDeleteAccountDialog,
              ),
              Divider(height: 1, color: const Color(0xFF323232)),
              _buildSettingsItem('로그아웃', isRed: true, onTap: _showLogoutDialog),
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
      onTap:
          onTap ??
          () {
            if (title == '개인정보 보호') {
              Navigator.pushNamed(context, '/privacy_protect');
            } else if (title == '게시물 관리') {
              Navigator.pushNamed(context, '/post_management');
            } else if (title == '개인정보 처리방침') {
              Navigator.pushNamed(context, '/privacy_policy');
            } else if (title == '서비스 이용 약관') {
              Navigator.pushNamed(context, '/terms_of_service');
            }
          },
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
}
