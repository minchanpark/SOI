import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../api/controller/friend_controller.dart';
import '../../api/controller/media_controller.dart';
import '../../api/controller/user_controller.dart';
import '../../api/models/friend.dart';
import '../../api/models/user.dart';

class BlockedFriendListScreen extends StatefulWidget {
  const BlockedFriendListScreen({super.key});

  @override
  State<BlockedFriendListScreen> createState() =>
      _BlockedFriendListScreenState();
}

class _BlockedFriendListScreenState extends State<BlockedFriendListScreen> {
  final List<User> _blockedUsers = [];
  final Map<int, String> _resolvedProfileUrlsByUserId = {};
  final Map<String, String> _presignedUrlCacheByKey = {};
  int _shimmerPlaceholderCount = 6;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadBlockedFriends();
    });
  }

  /// 차단된 사용자 목록을 불러옵니다.
  Future<void> _loadBlockedFriends() async {
    setState(() {
      _isLoading = true;
      _error = null;
      if (_blockedUsers.isNotEmpty) {
        _shimmerPlaceholderCount = _blockedUsers.length;
      }
    });

    try {
      // 컨트롤러 인스턴스 가져오기
      final userController = context.read<UserController>();
      final friendController = context.read<FriendController>();
      final mediaController = context.read<MediaController>();
      final currentUserId = userController.currentUserId;

      if (currentUserId == null) {
        setState(() {
          _error = '로그인이 필요합니다.';
          _isLoading = false;
        });
        return;
      }

      // 차단된 친구 목록 불러오기
      final blockedUsers = await friendController.getAllFriends(
        userId: currentUserId,
        status: FriendStatus.blocked,
      );

      // 프로필 이미지 URL 해상
      final resolvedProfileUrlsByUserId = await _resolveProfileUrlsByUserId(
        blockedUsers,
        mediaController: mediaController,
      );

      if (!mounted) return;
      setState(() {
        // 차단된 사용자 목록 업데이트
        // 기존 목록을 클리어하고 새로 불러온 목록으로 교체
        _blockedUsers
          ..clear()
          ..addAll(blockedUsers);

        // 프로필 이미지 URL 매핑 업데이트
        // 기존 매핑을 클리어하고 새로 해상된 매핑으로 교체
        _resolvedProfileUrlsByUserId
          ..clear()
          ..addAll(resolvedProfileUrlsByUserId);
        _shimmerPlaceholderCount = blockedUsers.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '차단된 친구를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  /// 사용자 목록에서 프로필 이미지 URL을 매핑해서 반환합니다.
  ///
  /// Parameters:
  ///   - [users]: 프로필 이미지 URL을 해상할 사용자 목록
  ///   - [mediaController]: 미디어 컨트롤러 인스턴스
  Future<Map<int, String>> _resolveProfileUrlsByUserId(
    List<User> users, {
    required MediaController mediaController,
  }) async {
    final resolvedByUserId = <int, String>{};
    final keysToResolve = <String>{}; // insertion-ordered
    final keyByUserId = <int, String>{};

    for (final user in users) {
      final keyOrUrl = user.profileImageUrlKey;
      if (keyOrUrl == null || keyOrUrl.isEmpty) continue;

      final uri = Uri.tryParse(keyOrUrl);
      if (uri != null && uri.hasScheme) {
        resolvedByUserId[user.id] = keyOrUrl;
        continue;
      }

      final cachedUrl = _presignedUrlCacheByKey[keyOrUrl];
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        resolvedByUserId[user.id] = cachedUrl;
        continue;
      }

      keyByUserId[user.id] = keyOrUrl;
      keysToResolve.add(keyOrUrl);
    }

    if (keysToResolve.isNotEmpty) {
      final keys = keysToResolve.toList(growable: false);
      final urls = await mediaController.getPresignedUrls(keys);
      final int count = urls.length < keys.length ? urls.length : keys.length;

      for (int i = 0; i < count; i++) {
        final url = urls[i];
        if (url.isEmpty) continue;
        _presignedUrlCacheByKey[keys[i]] = url;
      }

      keyByUserId.forEach((userId, key) {
        final url = _presignedUrlCacheByKey[key];
        if (url != null && url.isNotEmpty) {
          resolvedByUserId[userId] = url;
        }
      });
    }

    return resolvedByUserId;
  }

  Future<void> _unblockUser(User user) async {
    final userController = context.read<UserController>();
    final friendController = context.read<FriendController>();
    final currentUserId = userController.currentUserId;
    if (currentUserId == null) return;

    final success = await friendController.unblockFriend(
      requesterId: currentUserId,
      receiverId: user.id,
    );

    if (success && mounted) {
      setState(() {
        _blockedUsers.removeWhere((u) => u.id == user.id);
        _resolvedProfileUrlsByUserId.remove(user.id);
      });
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
        title: Text(
          '차단된 친구',
          textAlign: TextAlign.start,
          style: TextStyle(
            color: const Color(0xFFF8F8F8),
            fontSize: 20.sp,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingShimmer();
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
            100.h,
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
              _BlockedUserItem(
                user: _blockedUsers[i],
                profileImageUrl:
                    _resolvedProfileUrlsByUserId[_blockedUsers[i].id],
                onUnblock: () => _unblockUser(_blockedUsers[i]),
              ),
              if (i < _blockedUsers.length - 1)
                Divider(color: const Color(0xFF333333), height: 24.h),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    final int placeholderCount = _shimmerPlaceholderCount == 0
        ? 6
        : (_shimmerPlaceholderCount > 20 ? 20 : _shimmerPlaceholderCount);

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
            for (int i = 0; i < placeholderCount; i++) ...[
              const _BlockedUserShimmerItem(),
              if (i < placeholderCount - 1)
                Divider(color: const Color(0xFF333333), height: 24.h),
            ],
          ],
        ),
      ),
    );
  }
}

class _BlockedUserShimmerItem extends StatelessWidget {
  const _BlockedUserShimmerItem();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF333333),
      highlightColor: const Color(0xFF555555),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF333333),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14.h,
                  width: 120.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  height: 10.h,
                  width: 80.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            width: 84.w,
            height: 29,
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(13.r),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedUserItem extends StatelessWidget {
  final User user;
  final VoidCallback onUnblock;
  final String? profileImageUrl;

  const _BlockedUserItem({
    required this.user,
    required this.onUnblock,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final profileUrl = profileImageUrl ?? user.profileImageUrlKey ?? '';

    return Row(
      children: [
        Container(
          width: 44.w,
          height: 44.w,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF333333),
          ),
          child: profileUrl.isNotEmpty
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: profileUrl,
                    fit: BoxFit.cover,
                    memCacheHeight: (44 * 4).round(),
                    maxWidthDiskCache: (44 * 4).round(),
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: const Color(0xFF333333),
                      highlightColor: const Color(0xFF555555),
                      child: Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) =>
                        const _ProfileFallback(),
                  ),
                )
              : const _ProfileFallback(),
        ),
        SizedBox(width: 12.w),
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
                user.userId,
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
        SizedBox(
          width: 84.w,
          height: 29,
          child: TextButton(
            onPressed: onUnblock,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFF8F8F8),
              foregroundColor: const Color(0xFF1C1C1C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              padding: EdgeInsets.zero,
            ),
            child: Text(
              '차단 해제',
              style: TextStyle(
                fontSize: 13.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileFallback extends StatelessWidget {
  const _ProfileFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFd9d9d9),
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 26),
    );
  }
}
