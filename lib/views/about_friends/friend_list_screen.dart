import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/friend_controller.dart';
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/user.dart';

/// 친구 목록 화면
/// 친구 검색 및 친구 선택 기능 포함
class FriendListScreen extends StatefulWidget {
  final String? categoryId;

  const FriendListScreen({super.key, this.categoryId});

  @override
  State<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen> {
  // 선택된 친구들의 UID를 저장하는 Set
  final Set<int> _selectedFriendIds = <int>{};

  // 검색 컨트롤러
  final TextEditingController _searchController = TextEditingController();

  // 각 친구별 MenuController를 저장하는 Map
  final Map<int, MenuController> _menuControllers = {};

  List<User> _friends = [];
  bool _isLoadingFriends = false;
  String? _friendLoadErrorKey;

  /// API를 통해 친구 목록 로드
  Future<void> _loadFriends() async {
    if (!mounted) return;

    setState(() {
      _isLoadingFriends = true;
      _friendLoadErrorKey = null;
    });

    try {
      // 현재 사용자 ID 가져오기
      final userController = context.read<UserController>();
      final currentUserId = userController.currentUser?.id;

      if (currentUserId == null) {
        debugPrint('로그인된 사용자가 없습니다.');
        if (mounted) {
          setState(() {
            _friends = [];
            _friendLoadErrorKey = 'common.login_info_required';
          });
        }
        return;
      }

      // API로 친구 목록 조회
      final friendController = context.read<FriendController>();

      // 현재 로그인한 사용자 기준으로 친구 관계인 모든 사용자 조회
      final friends = await friendController.getAllFriends(
        userId: currentUserId,
      );

      if (mounted) {
        setState(() {
          _friends = friends;
        });
      }
    } catch (e) {
      debugPrint('친구 목록 로드 실패: $e');
      if (mounted) {
        setState(() {
          _friendLoadErrorKey = 'friends.load_failed_detail';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 친구 목록을 로드한다.
      _loadFriends();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  void _toggleFriendSelection(int friendId) {
    setState(() {
      if (_selectedFriendIds.contains(friendId)) {
        _selectedFriendIds.remove(friendId);
      } else {
        _selectedFriendIds.add(friendId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();
    final displayFriends = query.isEmpty
        ? _friends
        : _friends.where((friend) {
            final name = friend.name.toLowerCase();
            final nickname = friend.userId.toLowerCase();
            return name.contains(query) || nickname.contains(query);
          }).toList();
    final hasQuery = query.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xffd9d9d9)),
        title: Text(
          'friends.list_title',
          style: TextStyle(
            color: const Color(0xFFD9D9D9),
            fontSize: 20,
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ).tr(),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // 검색 바
          Padding(
            padding: EdgeInsets.only(left: 20.w, right: 20.w),
            child: Container(
              width: double.infinity,
              height: 47,
              decoration: BoxDecoration(
                color: const Color(0xff1c1c1c),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.only(top: 1.h),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: const Color(0xfff9f9f9),

                  fontSize: 16.sp,
                ),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: tr('friends.search_hint', context: context),
                  hintStyle: TextStyle(
                    color: const Color(0xFFD9D9D9),
                    fontSize: 18.02,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                  ),

                  prefixIcon: Icon(
                    Icons.search,
                    color: const Color(0xffd9d9d9),
                    size: 24.w,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          SizedBox(height: 38.h),
          Row(
            children: [
              SizedBox(width: 27.w),
              Icon(Icons.people_alt_outlined, size: 21.sp),
              SizedBox(width: 11.w),
              Text(
                "friends.list_title",
                style: TextStyle(
                  color: const Color(0xfff9f9f9),
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Pretendard',
                ),
              ).tr(),
            ],
          ),
          SizedBox(height: 18.h),
          _buildFriendListSection(displayFriends, hasQuery),
        ],
      ),
    );
  }

  Widget _buildFriendListSection(List<User> displayFriends, bool hasQuery) {
    return Expanded(
      child: _isLoadingFriends
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : _friendLoadErrorKey != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'friends.load_failed_title',
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 16.sp,
                    ),
                  ).tr(),
                  SizedBox(height: 12.h),
                  Text(
                    _friendLoadErrorKey!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xff666666),
                      fontSize: 14.sp,
                    ),
                  ).tr(),
                  SizedBox(height: 16.h),
                  ElevatedButton(
                    onPressed: _loadFriends,
                    child: Text('common.retry').tr(),
                  ),
                ],
              ),
            )
          : displayFriends.isEmpty
          ? Center(
              child: Text(
                hasQuery
                    ? tr('common.search_empty', context: context)
                    : tr('friends.empty', context: context),
                style: TextStyle(
                  color: const Color(0xff666666),
                  fontSize: 16.sp,
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 24.h),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xff1c1c1c).withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.only(bottom: 3.h),
                  child: Column(
                    children: displayFriends.asMap().entries.map((entry) {
                      final index = entry.key;
                      final friend = entry.value;
                      final isSelected = _selectedFriendIds.contains(friend.id);

                      return _buildFriendItem(
                        friend: friend,
                        isSelected: isSelected,
                        index: index,
                        isLast: index == displayFriends.length - 1,
                        onTap: () => _toggleFriendSelection(friend.id),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFriendItem({
    required User friend,
    required bool isSelected,
    required int index,
    required bool isLast,
    required VoidCallback onTap,
  }) {
    // profileImageUrlKey는 이미 완전한 URL
    final profileUrl = friend.profileImageUrlKey;
    final hasProfileImage = profileUrl != null && profileUrl.isNotEmpty;

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
            child: Row(
              children: [
                // 프로필 이미지
                SizedBox(
                  width: 44,
                  height: 44,
                  child: hasProfileImage
                      ? CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xff323232),
                          backgroundImage: CachedNetworkImageProvider(
                            profileUrl,
                          ),
                        )
                      : CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xff323232),
                          child: Text(
                            friend.name.isNotEmpty
                                ? friend.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: const Color(0xfff9f9f9),
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                SizedBox(width: 12.w),

                // 친구 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.name,
                        style: TextStyle(
                          color: const Color(0xFFD9D9D9),
                          fontSize: 16,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        friend.userId,
                        style: TextStyle(
                          color: const Color(0xFFD9D9D9),
                          fontSize: 10,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w300,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                MenuAnchor(
                  style: MenuStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.transparent),
                    shadowColor: WidgetStatePropertyAll(Colors.transparent),

                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9.14),
                      ),
                    ),
                  ),
                  builder:
                      (
                        BuildContext context,
                        MenuController controller,
                        Widget? child,
                      ) {
                        // 각 친구별로 MenuController 저장
                        _menuControllers[friend.id] = controller;
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: IconButton(
                            onPressed: () {
                              if (controller.isOpen) {
                                controller.close();
                              } else {
                                controller.open();
                              }
                            },
                            icon: Icon(
                              Icons.more_vert,
                              size: 25.sp,
                              color: Color(0xfff9f9f9),
                            ),
                          ),
                        );
                      },
                  menuChildren: [
                    _menuItem(
                      friend.id,
                      friend.profileImageUrlKey,
                      friend.name,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuItem(
    int friendUserId,
    String? profileImageUrl,
    String friendName,
  ) {
    return MenuItemButton(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9.14),
            side: BorderSide.none,
          ),
        ),
      ),
      child: Container(
        width: 173.sp,
        height: 88.sp,
        decoration: BoxDecoration(
          color: Color(0xff323232),
          borderRadius: BorderRadius.circular(9.14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: InkWell(
                onTap: () {
                  debugPrint("친구 삭제");
                  _showDeleteFriendModal(
                    profileImageUrl,
                    friendName,
                    friendUserId,
                  );
                  final controller = _menuControllers[friendUserId];
                  if (controller != null && controller.isOpen) {
                    controller.close();
                  }
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 13.96.w),
                    Padding(
                      padding: EdgeInsets.only(bottom: 1.h),
                      child: Image.asset(
                        'assets/trash_bin.png',
                        width: (11.16).sp,
                        height: (12.56).sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'friends.menu.delete',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.3517.sp,
                        fontFamily: "Pretendard",
                      ),
                    ).tr(),
                  ],
                ),
              ),
            ),
            Divider(color: Color(0xff5a5a5a), thickness: 1.sp),
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: InkWell(
                onTap: () {
                  _showBlockFriendModal(
                    profileImageUrl,
                    friendName,
                    friendUserId,
                  );

                  debugPrint("차단");
                  final controller = _menuControllers[friendUserId];
                  if (controller != null && controller.isOpen) {
                    controller.close();
                  }
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 11.57.w),
                    Image.asset(
                      'assets/block.png',
                      width: 16.sp,
                      height: 16.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'friends.menu.block',
                      style: TextStyle(
                        color: Color(0xfff40202),
                        fontSize: 15.3517.sp,
                        fontFamily: "Pretendard",
                      ),
                    ).tr(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 재사용 가능한 친구 액션 모달
  void _showFriendActionModal({
    required String? profileImageUrl,
    required String friendName,
    required String title,
    required String description,
    required String actionButtonText,
    required VoidCallback onActionPressed,
    required Color actionButtonTextColor,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 358.sp,
          decoration: BoxDecoration(
            color: const Color(0xff323232),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.8),
              topRight: Radius.circular(24.8),
            ),
          ),
          child: Center(
            child: Column(
              children: [
                SizedBox(height: 10.h),
                Container(
                  width: 56.w,
                  height: 3.h,
                  decoration: ShapeDecoration(
                    color: const Color(0xFFCBCBCB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.80),
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    // 프로필 이미지
                    ClipOval(
                      child:
                          profileImageUrl != null && profileImageUrl.isNotEmpty
                          ? Image(
                              image: NetworkImage(profileImageUrl),
                              width: 70.sp,
                              height: 70.sp,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar(friendName);
                              },
                            )
                          : _buildDefaultAvatar(friendName),
                    ),
                    SizedBox(height: 20.h),

                    // 제목
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFF8F8F8),
                        fontSize: 19.78.sp,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // 설명
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFFF8F8F8),
                        fontSize: 16.sp,
                        fontFamily: 'Pretendard Variable',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // 액션 버튼
                    ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          const Color(0xFFf8f8f8),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(19),
                          ),
                        ),
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                      ),
                      child: Container(
                        width: 294.w,
                        height: 38.h,
                        alignment: Alignment.center,
                        child: Text(
                          actionButtonText,
                          style: TextStyle(
                            color: actionButtonTextColor,
                            fontSize: 17.78.sp,
                            fontFamily: 'Pretendard Variable',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onActionPressed();
                      },
                    ),
                    SizedBox(height: 10.h),

                    // 취소 버튼
                    ElevatedButton(
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(
                          const Color(0xFF323232),
                        ),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(19),
                          ),
                        ),
                        elevation: WidgetStateProperty.all(0),
                      ),
                      child: Container(
                        width: 294.w,
                        height: 38.h,
                        alignment: Alignment.center,
                        child: const Text(
                          'common.cancel',
                          style: TextStyle(
                            color: Color(0xFFcbcbcb),
                            fontSize: 17.78,
                            fontFamily: 'Pretendard Variable',
                            fontWeight: FontWeight.w600,
                          ),
                        ).tr(),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 기본 아바타 위젯
  Widget _buildDefaultAvatar(String friendName) {
    return Container(
      width: 70.w,
      height: 70.h,
      decoration: BoxDecoration(
        color: const Color(0xff666666),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          friendName.isNotEmpty ? friendName[0].toUpperCase() : '?',
          style: TextStyle(
            color: const Color(0xfff9f9f9),
            fontSize: 28.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 친구 삭제 모달 호출
  void _showDeleteFriendModal(
    String? profileImageUrl,
    String friendName,
    int friendUid,
  ) {
    _showFriendActionModal(
      profileImageUrl: profileImageUrl,
      friendName: friendName,
      title: tr(
        'friends.delete_confirm_title',
        context: context,
        namedArgs: {'name': friendName},
      ),
      description: tr('friends.delete_confirm_desc', context: context),
      actionButtonText: tr('common.delete', context: context),
      onActionPressed: () => _handleDeleteFriend(friendUid),
      actionButtonTextColor: Colors.black,
    );
  }

  /// 친구 차단 모달 호출
  void _showBlockFriendModal(
    String? profileImageUrl,
    String friendName,
    int friendUid,
  ) {
    _showFriendActionModal(
      profileImageUrl: profileImageUrl,
      friendName: friendName,
      title: tr(
        'friends.block_confirm_title',
        context: context,
        namedArgs: {'name': friendName},
      ),
      description: tr('friends.block_confirm_desc', context: context),
      actionButtonText: tr('common.block', context: context),
      onActionPressed: () => _handleBlockFriend(friendUid),
      actionButtonTextColor: Color(0xffff0000),
    );
  }

  /// 친구 삭제 처리
  Future<void> _handleDeleteFriend(int friendId) async {
    final userController = context.read<UserController>();
    final currentUserId = userController.currentUser?.id;

    if (currentUserId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('common.login_info_required', context: context)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final friendController = context.read<FriendController>();

    try {
      final success = await friendController.deleteFriend(
        requesterId: currentUserId,
        receiverId: friendId,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('friends.delete_success', context: context)),
            backgroundColor: Colors.green,
          ),
        );
        await _loadFriends();
      } else {
        final message =
            friendController.errorMessage ??
            tr('friends.delete_failed', context: context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('friends.delete_error', context: context)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 친구 차단 처리
  Future<void> _handleBlockFriend(int friendId) async {
    final userController = context.read<UserController>();
    final currentUserId = userController.currentUser?.id;

    if (currentUserId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('common.login_info_required', context: context)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final friendController = context.read<FriendController>();

    try {
      final success = await friendController.blockFriend(
        requesterId: currentUserId,
        receiverId: friendId,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('friends.block_success', context: context)),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadFriends();
      } else {
        final message =
            friendController.errorMessage ??
            tr('friends.block_failed', context: context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('friends.block_error', context: context)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
