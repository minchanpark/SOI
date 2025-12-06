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
  List<User> _friends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 빌드 완료 후 친구 목록 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 친구 목록을 로드한다.
      _loadFriends();
    });
  }

  /// API를 통해 친구 목록 로드
  Future<void> _loadFriends() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 현재 사용자 ID 가져오기
      final userController = Provider.of<UserController>(
        context,
        listen: false,
      );
      final currentUserId = userController.currentUser?.id;

      if (currentUserId == null) {
        debugPrint('로그인된 사용자가 없습니다.');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // API로 친구 목록 조회
      final friendController = Provider.of<FriendController>(
        context,
        listen: false,
      );

      // 현재 로그인한 사용자 기준으로 친구 관계인 모든 사용자 조회
      final friends = await friendController.getAllFriends(
        userId: currentUserId,
      );

      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('친구 목록 로드 실패: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 354.w,
      child: Card(
        clipBehavior: Clip.antiAliasWithSaveLayer,
        color: const Color(0xff1c1c1c),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: _isLoading
            ? SizedBox(
                height: 132.h,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: const Color(0xfff9f9f9),
                  ),
                ),
              )
            : _friends.isEmpty
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
                  // 친구들 리스트 (세로 리스트)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _friends.length,
                    itemBuilder: (context, index) {
                      final friend = _friends[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18.w,
                          vertical: 8.h,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 프로필 이미지 (고정 크기)
                            CircleAvatar(
                              radius: (22),
                              backgroundColor: const Color(0xff323232),
                              backgroundImage: friend.profileImageUrlKey != null
                                  ? NetworkImage(friend.profileImageUrlKey!)
                                  : null,
                              child: friend.profileImageUrlKey == null
                                  ? Text(
                                      friend.name.isNotEmpty
                                          ? friend.name[0]
                                          : '?',
                                      style: TextStyle(
                                        color: const Color(0xfff9f9f9),
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w600,
                                        height: 1.1,
                                      ),
                                    )
                                  : null,
                            ),
                            SizedBox(width: 12.w),
                            // 이름 + 서브텍스트 영역
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
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

                  // 더보기 링크
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // 친구 목록 전체 화면으로 이동
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
  }
}
