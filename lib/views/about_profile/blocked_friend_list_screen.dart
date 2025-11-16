import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../api_firebase/controllers/friend_controller.dart';
import '../../api_firebase/controllers/auth_controller.dart';
import '../../api_firebase/models/auth_model.dart';

class BlockedFriendListScreen extends StatefulWidget {
  const BlockedFriendListScreen({super.key});

  @override
  State<BlockedFriendListScreen> createState() =>
      _BlockedFriendListScreenState();
}

class _BlockedFriendListScreenState extends State<BlockedFriendListScreen> {
  List<String> _blockedUserIds = [];
  List<AuthModel> _blockedUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBlockedFriends();
  }

  Future<void> _loadBlockedFriends() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final friendController = context.read<FriendController>();
      final authController = context.read<AuthController>();

      // 차단된 사용자 ID 목록 가져오기
      final blockedUserIds = await friendController.getBlockedUsers();

      // 각 차단된 사용자의 정보 가져오기
      final List<AuthModel> blockedUsers = [];
      for (String userId in blockedUserIds) {
        final userInfo = await authController.getUserInfo(userId);
        if (userInfo != null) {
          blockedUsers.add(userInfo);
        }
      }

      setState(() {
        _blockedUserIds = blockedUserIds;
        _blockedUsers = blockedUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(String userId, String userName) async {
    try {
      final friendController = context.read<FriendController>();
      final success = await friendController.unblockFriend(userId);

      if (success) {
        // 성공 시 목록에서 제거
        setState(() {
          _blockedUserIds.remove(userId);
          _blockedUsers.removeWhere((user) => user.uid == userId);
        });
      }
    } catch (e) {
      debugPrint('친구 차단 해제 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '차단된 친구',
              textAlign: TextAlign.start,
              style: TextStyle(
                color: const Color(0xFFF8F8F8),
                fontSize: 20.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '오류가 발생했습니다',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _error!,
              style: TextStyle(
                color: const Color(0xFFB0B0B0),
                fontSize: 14.sp,
                fontFamily: 'Pretendard',
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _loadBlockedFriends,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_blockedUsers.isEmpty) {
      return SizedBox(
        height:
            MediaQuery.of(context).size.height -
            MediaQuery.of(context).padding.top -
            kToolbarHeight -
            100.h, // AppBar와 패딩을 제외한 높이
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64.sp, color: const Color(0xFF666666)),
              SizedBox(height: 16.h),
              Text(
                '차단된 친구가 없습니다',
                style: TextStyle(
                  color: const Color(0xFFB0B0B0),
                  fontSize: 16.sp,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(12.r),
        ),
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < _blockedUsers.length; i++) ...[
              _buildBlockedUserItem(_blockedUsers[i]),
              if (i < _blockedUsers.length - 1)
                Divider(color: const Color(0xFF333333), height: 24.h),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedUserItem(AuthModel user) {
    return Row(
      children: [
        // 프로필 이미지
        FutureBuilder<String>(
          future: context.read<AuthController>().getUserProfileImageUrlById(
            user.uid,
          ),
          builder: (context, snapshot) {
            final imageUrl = snapshot.data ?? '';

            return Container(
              width: 44.sp,
              height: 44.sp,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF333333),
              ),
              child: imageUrl.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: (44 * 4).round(),
                        maxWidthDiskCache: (44 * 4).round(),
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: const Color(0xFF333333),
                          highlightColor: const Color(0xFF555555),
                          child: Container(
                            width: 44.sp,
                            height: 44.sp,
                            decoration: const BoxDecoration(
                              color: Color(0xFF333333),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFd9d9d9),
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFd9d9d9),
                      ),
                      child: Icon(Icons.person, color: Colors.white, size: 26),
                    ),
            );
          },
        ),
        SizedBox(width: 12.w),

        // 사용자 정보
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                style: TextStyle(
                  color: const Color(0xFFD9D9D9),
                  fontSize: 16.sp,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                user.id,
                style: TextStyle(
                  color: const Color(0xFFD9D9D9),
                  fontSize: 9.sp,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),

        // 차단 해제 버튼
        Container(
          width: 84.w,
          height: 29,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(13),
          ),
          child: TextButton(
            onPressed: () => _unblockUser(user.uid, user.name),
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '차단 해제',
              style: TextStyle(
                color: const Color(0xFF1C1C1C),
                fontSize: 13.sp,
                fontFamily: 'Pretendard Variable',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
