import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../api/controller/friend_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/user.dart';

class FriendListCard extends StatefulWidget {
  final double scale;

  const FriendListCard({super.key, required this.scale});

  @override
  State<FriendListCard> createState() => _FriendListCardState();
}

class _FriendListCardState extends State<FriendListCard> {
  bool _initialized = false;
  int? _refreshingUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshFriends());
  }

  /// API를 통해 친구 목록 로드 + Provider 캐시 갱신
  Future<void> _refreshFriends() async {
    try {
      // 현재 사용자 ID 가져오기
      final userController = Provider.of<UserController>(
        context,
        listen: false,
      );
      final currentUserId = userController.currentUser?.id;

      if (currentUserId == null) {
        debugPrint('로그인된 사용자가 없습니다.');
        return;
      }

      if (_refreshingUserId == currentUserId) {
        return;
      }
      _refreshingUserId = currentUserId;

      final friendController = Provider.of<FriendController>(
        context,
        listen: false,
      );

      await friendController.refreshFriends(userId: currentUserId);
      if (mounted) {
        _refreshingUserId = null;
      }
    } catch (e) {
      debugPrint('친구 목록 로드 실패: $e');
      if (mounted) {
        _refreshingUserId = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserController, FriendController>(
      builder: (context, userController, friendController, _) {
        final currentUserId = userController.currentUser?.id;
        if (!_initialized) {
          _initialized = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _refreshFriends(),
          );
        }

        if (currentUserId != null &&
            friendController.cachedFriendsUserId != currentUserId) {
          if (_refreshingUserId != currentUserId) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _refreshFriends(),
            );
          }
        }

        final friends =
            currentUserId == null ||
                friendController.cachedFriendsUserId != currentUserId
            ? const <User>[]
            : friendController.cachedFriends;

        return SizedBox(
          width: 354.w,
          child: Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            color: const Color(0xff1c1c1c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: friendController.isLoading && friends.isEmpty
                ? SizedBox(
                    height: 132.h,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xfff9f9f9),
                      ),
                    ),
                  )
                : friends.isEmpty
                ? SizedBox(
                    height: 132.h,
                    child: Center(
                      child: Text(
                        '아직 친구가 없습니다',
                        style: TextStyle(
                          color: const Color(0xff666666),
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 18.w,
                              vertical: 8.h,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: (44).w,
                                  height: (44).w,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xff323232),
                                  ),
                                  child: ClipOval(
                                    child: friend.profileImageUrlKey == null ||
                                            friend.profileImageUrlKey!.isEmpty
                                        ? _buildInitialOrIcon(friend)
                                        : Image.network(
                                            friend.profileImageUrlKey!,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (
                                              context,
                                              child,
                                              loadingProgress,
                                            ) {
                                              if (loadingProgress == null) {
                                                return child;
                                              }
                                              return _buildInitialOrIcon(friend);
                                            },
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              return _buildInitialOrIcon(friend);
                                            },
                                          ),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        friend.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: const Color(0xFFD9D9D9),
                                          fontSize: 16,
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      Text(
                                        friend.userId,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: const Color(0xFFD9D9D9),
                                          fontSize: 10,
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pushNamed(context, '/friend_list');
                          },
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, size: (18).sp),
                                  SizedBox(width: (8).w),
                                  Text(
                                    '더보기',
                                    style: TextStyle(
                                      color: const Color(0xffd9d9d9),
                                      fontSize: (16).sp,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: (12).h),
                            ],
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
}

Widget _buildInitialOrIcon(User friend) {
  if (friend.name.isNotEmpty) {
    return Center(
      child: Text(
        friend.name[0],
        style: TextStyle(
          color: const Color(0xfff9f9f9),
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
  return Center(
    child: Icon(
      Icons.person,
      size: (30).sp,
      color: const Color(0xff777777),
    ),
  );
}
