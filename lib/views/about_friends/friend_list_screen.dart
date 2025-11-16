import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../api_firebase/controllers/friend_controller.dart';
import '../../api_firebase/models/friend_model.dart';

class FriendListScreen extends StatefulWidget {
  final String? categoryId;

  const FriendListScreen({super.key, this.categoryId});

  @override
  State<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen> {
  // 선택된 친구들의 UID를 저장하는 Set
  final Set<String> _selectedFriendUids = <String>{};

  // 검색 컨트롤러
  final TextEditingController _searchController = TextEditingController();

  // 각 친구별 MenuController를 저장하는 Map
  final Map<String, MenuController> _menuControllers = {};

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    // FriendController 초기화 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final friendController = context.read<FriendController>();
      if (!friendController.isInitialized) {
        friendController.initialize();
      }
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

  void _toggleFriendSelection(String friendUid) {
    setState(() {
      if (_selectedFriendUids.contains(friendUid)) {
        _selectedFriendUids.remove(friendUid);
      } else {
        _selectedFriendUids.add(friendUid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xffd9d9d9)),
        title: Text(
          '친구 목록',
          style: TextStyle(
            color: const Color(0xFFD9D9D9),
            fontSize: 20,
            fontFamily: GoogleFonts.inter().fontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
      ),
      body: Consumer<FriendController>(
        builder: (context, friendController, child) {
          // 검색어에 따라 실시간으로 친구 목록 필터링
          final query = _searchController.text.toLowerCase();
          final displayFriends = query.isEmpty
              ? friendController.friends
              : friendController.friends.where((friend) {
                  return friend.name.toLowerCase().contains(query) ||
                      friend.id.toLowerCase().contains(query);
                }).toList();

          return Column(
            children: [
              // 검색 바
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Container(
                  width: double.infinity,
                  height: 47,
                  decoration: BoxDecoration(
                    color: const Color(0xff1c1c1c),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 16.sp,
                    ),
                    decoration: InputDecoration(
                      hintText: '친구 검색하기',
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
                    "친구 목록",
                    style: TextStyle(
                      color: const Color(0xfff9f9f9),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),
              // 친구 목록
              friendController.isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : !friendController.isInitialized
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16.h),
                          Text(
                            '친구 목록을 불러오는 중...',
                            style: TextStyle(
                              color: const Color(0xff666666),
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    )
                  : displayFriends.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? '친구가 없습니다'
                            : '검색 결과가 없습니다',
                        style: TextStyle(
                          color: const Color(0xff666666),
                          fontSize: 16.sp,
                        ),
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.only(left: 20.w, right: 20.w),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xff1c1c1c).withValues(alpha: 0.80),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        // 친구 목록과 배경 박스의 상단과 하단의 너비를 같게 만들기 위함
                        padding: EdgeInsets.only(bottom: 3.h),
                        child: Column(
                          children: [
                            // 친구 목록
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: displayFriends.asMap().entries.map((
                                entry,
                              ) {
                                final index = entry.key;
                                final friend = entry.value;
                                final isSelected = _selectedFriendUids.contains(
                                  friend.userId,
                                );

                                return _buildFriendItem(
                                  friend: friend,
                                  isSelected: isSelected,
                                  index: index,
                                  isLast: index == displayFriends.length - 1,
                                  onTap: () =>
                                      _toggleFriendSelection(friend.userId),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFriendItem({
    required FriendModel friend,
    required bool isSelected,
    required int index,
    required bool isLast,
    required VoidCallback onTap,
  }) {
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
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xff323232),
                    backgroundImage: friend.profileImageUrl != null
                        ? CachedNetworkImageProvider(friend.profileImageUrl!)
                        : null,
                    child: friend.profileImageUrl == null
                        ? Text(
                            friend.name.isNotEmpty
                                ? friend.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: const Color(0xfff9f9f9),
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
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
                        friend.id,
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
                        _menuControllers[friend.userId] = controller;
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
                      friend.userId,
                      friend.profileImageUrl,
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
    String friendUserId,
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
        width: 173.w,
        height: 88.h,

        decoration: BoxDecoration(
          color: Color(0xff363636),
          borderRadius: BorderRadius.circular(9.14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
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
                    '친구 삭제',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.3517.sp,
                      fontFamily: "Pretendard",
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Color(0xff5a5a5a), thickness: 1.sp),
            InkWell(
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
                  SizedBox(width: 13.96.w),
                  Image.asset(
                    'assets/block.png',
                    width: 11.16.sp,
                    height: 12.56.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '차단',
                    style: TextStyle(
                      color: Color(0xfff40202),
                      fontSize: 15.3517.sp,
                      fontFamily: "Pretendard",
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
                          '취소',
                          style: TextStyle(
                            color: Color(0xFFcbcbcb),
                            fontSize: 17.78,
                            fontFamily: 'Pretendard Variable',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
    String friendUid,
  ) {
    _showFriendActionModal(
      profileImageUrl: profileImageUrl,
      friendName: friendName,
      title: "$friendName님을 삭제하시겠습니까?",
      description: "삭제시, 추가된 카테고리에서 삭제될 수 있습니다.",
      actionButtonText: "삭제",
      onActionPressed: () => _handleDeleteFriend(friendUid),
      actionButtonTextColor: Colors.black,
    );
  }

  /// 친구 차단 모달 호출
  void _showBlockFriendModal(
    String? profileImageUrl,
    String friendName,
    String friendUid,
  ) {
    _showFriendActionModal(
      profileImageUrl: profileImageUrl,
      friendName: friendName,
      title: "$friendName님을 차단하시겠습니까?",
      description: "차단시, 이 친구는 더 이상 나를 카테고리에\n초대하거나 친구 요청을 할 수 없습니다.",
      actionButtonText: "차단",
      onActionPressed: () => _handleBlockFriend(friendUid),
      actionButtonTextColor: Color(0xffff0000),
    );
  }

  /// 친구 삭제 처리
  void _handleDeleteFriend(String friendUid) async {
    final friendController = context.read<FriendController>();

    try {
      final success = await friendController.removeFriend(friendUid);

      if (success) {
        // 성공 메시지 표시 (선택사항)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('친구가 삭제되었습니다.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // 실패 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendController.error ?? '친구 삭제에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('친구 삭제 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 친구 차단 처리
  void _handleBlockFriend(String friendUid) async {
    final friendController = context.read<FriendController>();

    try {
      final success = await friendController.blockFriend(friendUid);

      if (success) {
        // 성공 메시지 표시 (선택사항)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('친구가 차단되었습니다.'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // 실패 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendController.error ?? '친구 차단에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('친구 차단 중 오류가 발생했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
