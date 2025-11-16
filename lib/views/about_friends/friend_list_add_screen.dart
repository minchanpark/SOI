import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:soi/api_firebase/controllers/category_member_controller.dart';
import '../../api_firebase/controllers/friend_controller.dart';
import '../../api_firebase/controllers/category_controller.dart';
import '../../api_firebase/controllers/auth_controller.dart';
import '../../api_firebase/models/friend_model.dart';
import '../../api_firebase/models/selected_friend_model.dart';

/// 친구 추가 화면
class FriendListAddScreen extends StatefulWidget {
  final String? categoryId; // 카테고리에 친구를 추가할 때 사용
  final List<String>? categoryMemberUids; // 이미 카테고리에 추가된 멤버들의 UID 목록
  final bool allowDeselection; // 이미 선택된 친구들의 해제 허용 여부 (새 카테고리 만들기에서 true)

  const FriendListAddScreen({
    super.key,
    this.categoryId,
    this.categoryMemberUids,
    this.allowDeselection = false, // 기본값은 false (기존 카테고리에 추가)
  });

  @override
  State<FriendListAddScreen> createState() => _FriendListAddScreenState();
}

class _FriendListAddScreenState extends State<FriendListAddScreen> {
  // 선택된 친구들의 UID를 저장하는 Set
  final Set<String> _selectedFriendUids = <String>{};

  // 검색 컨트롤러
  final TextEditingController _searchController = TextEditingController();

  // Navigator 중복 호출 방지 플래그
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_onSearchChanged);

    // 새 카테고리 만들기 모드에서 이미 선택된 친구들을 초기 선택 상태로 설정
    if (widget.allowDeselection && widget.categoryMemberUids != null) {
      _selectedFriendUids.addAll(widget.categoryMemberUids!);
    }

    // FriendController 초기화 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final friendController = context.read<FriendController>();
      if (!friendController.isInitialized) {
        debugPrint('FriendController 초기화되지 않음 - 초기화 시작');
        friendController.initialize();
      }
    });
  }

  @override
  void dispose() {
    _isNavigating = true; // dispose 시작 시 플래그 설정
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      debugPrint('검색어 변경: "${_searchController.text}"');
    });
  }

  void _toggleFriendSelection(String friendUid) {
    // 새 카테고리 만들기 모드가 아닌 경우, 이미 카테고리에 포함된 멤버는 선택 불가
    if (!widget.allowDeselection &&
        widget.categoryMemberUids?.contains(friendUid) == true) {
      return;
    }

    setState(() {
      if (_selectedFriendUids.contains(friendUid)) {
        _selectedFriendUids.remove(friendUid);
      } else {
        _selectedFriendUids.add(friendUid);
      }
    });
  }

  void _onConfirmPressed() async {
    // 이미 Navigator가 진행 중이면 중복 실행 방지
    if (_isNavigating) return;

    if (widget.categoryId != null) {
      // 카테고리에 친구들 추가
      try {
        final categoryMemberController = context
            .read<CategoryMemberController>();
        final categoryController = context.read<CategoryController>();

        // 선택된 각 친구의 UID를 카테고리 mates에 추가
        for (final friendUid in _selectedFriendUids) {
          await categoryMemberController.addUidToCategory(
            widget.categoryId!,
            friendUid,
          );
        }

        // CategoryController 강제 새로고침 - 즉시 UI 업데이트를 위해
        final authController = context.read<AuthController>();
        final userId = authController.getUserId;
        if (userId != null) {
          await categoryController.loadUserCategories(
            userId,
            forceReload: true,
          );
        }

        if (mounted && !_isNavigating) {
          // 성공 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_selectedFriendUids.length}명의 친구가 카테고리에 추가되었습니다.',
              ),
              backgroundColor: const Color(0xFF5A5A5A),
              duration: const Duration(seconds: 2),
            ),
          );

          // Navigator 플래그 설정 후 안전하게 pop - 다음 프레임에서 실행
          _isNavigating = true;
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      } catch (e) {
        if (mounted && !_isNavigating) {
          // 에러 메시지 표시
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('친구 추가 중 오류가 발생했습니다: $e'),
              backgroundColor: const Color(0xFF5A5A5A),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      // 단순히 선택된 친구들의 정보와 함께 이전 화면으로 돌아가기
      if (mounted && !_isNavigating) {
        final friendController = context.read<FriendController>();
        final selectedFriends = <SelectedFriendModel>[];

        // 선택된 UID들을 기반으로 친구 정보 수집
        for (final uid in _selectedFriendUids) {
          final friend = friendController.friends.firstWhere(
            (friend) => friend.userId == uid,
            orElse: () => FriendModel(
              userId: uid,
              name: '알 수 없음',
              id: uid,
              status: FriendStatus.active,
              isFavorite: false,
              addedAt: DateTime.now(),
            ),
          );

          selectedFriends.add(
            SelectedFriendModel(
              uid: friend.userId,
              name: friend.name,
              profileImageUrl: friend.profileImageUrl,
            ),
          );
        }

        for (final friend in selectedFriends) {
          debugPrint('- ${friend.name} (${friend.uid})');
        }

        // Navigator 플래그 설정 후 안전하게 pop - 다음 프레임에서 실행
        _isNavigating = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pop(selectedFriends);
          }
        });
      }
    }
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
            color: const Color(0xfff9f9f9),
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            fontFamily: 'Pretendard',
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
                padding: EdgeInsets.symmetric(horizontal: 19.w),
                child: Container(
                  width: double.infinity,
                  height: 47,
                  decoration: BoxDecoration(
                    color: const Color(0xff1e1e1e),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      SizedBox(width: 7.w),
                      Icon(
                        Icons.search,
                        color: const Color(0xffd9d9d9),
                        size: 24.w,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                            color: const Color(0xfff9f9f9),
                            fontSize: 16.sp,
                          ),
                          cursorColor: const Color(0xfff9f9f9),
                          decoration: InputDecoration(
                            hintText: '친구 검색하기',
                            hintStyle: TextStyle(
                              color: const Color(0xffd9d9d9),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Pretendard',
                            ),

                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 38.h),
              // 친구 목록
              Expanded(
                child: friendController.isLoading
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
                    : SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xff1c1c1c),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Column(
                              children: [
                                SizedBox(height: (14).h),
                                Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(8.r),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/contact_manager',
                                      );
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 18.w,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Color(0xff4a4a4a),
                                            ),
                                            child: Icon(
                                              Icons.add,
                                              size: 25.sp,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Text(
                                            "친구 추가",
                                            style: TextStyle(
                                              color: const Color(0xfff9f9f9),
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w900,
                                              fontFamily: 'Pretendard',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: displayFriends.asMap().entries.map((
                                    entry,
                                  ) {
                                    final index = entry.key;
                                    final friend = entry.value;
                                    final isSelected = _selectedFriendUids
                                        .contains(friend.userId);
                                    final isAlreadyMember =
                                        !widget.allowDeselection &&
                                        widget.categoryMemberUids?.contains(
                                              friend.userId,
                                            ) ==
                                            true;

                                    return _buildFriendItem(
                                      friend: friend,
                                      isSelected: isSelected,
                                      isAlreadyMember: isAlreadyMember,
                                      index: index,
                                      isLast:
                                          index == displayFriends.length - 1,
                                      onTap: () =>
                                          _toggleFriendSelection(friend.userId),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),

              // 완료 버튼
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                child: SizedBox(
                  height: 48.h,
                  child: ElevatedButton(
                    onPressed: () {
                      // 새 카테고리 만들기 모드에서는 빈 선택도 허용
                      // 기존 카테고리에 추가하는 모드에서는 최소 1명은 선택해야 함
                      if (widget.allowDeselection ||
                          _selectedFriendUids.isNotEmpty) {
                        _onConfirmPressed();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          // 새 카테고리 만들기 모드에서는 항상 활성화
                          // 기존 카테고리 추가 모드에서는 선택된 친구가 있을 때만 활성화
                          (_selectedFriendUids.isNotEmpty)
                          ? const Color(0xffffffff)
                          : const Color(0xff5a5a5a),
                      foregroundColor:
                          (widget.allowDeselection ||
                              _selectedFriendUids.isNotEmpty)
                          ? const Color(0xff000000)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      '완료',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Pretendard',
                        color: _selectedFriendUids.isNotEmpty
                            ? Colors.black
                            : Color(0xfff8f8f8),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFriendItem({
    required FriendModel friend,
    required bool isSelected,
    required bool isAlreadyMember,
    required int index,
    required bool isLast,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isAlreadyMember ? null : onTap, // 이미 멤버이고 해제 불가인 경우만 터치 불가
      behavior: HitTestBehavior.opaque, // 빈 공간에서도 탭 감지되도록 설정
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
        child: Row(
          children: [
            // 프로필 이미지
            SizedBox(
              width: 44,
              height: 44,
              child: CircleAvatar(
                radius: 24.r,
                backgroundColor: const Color(0xff323232),
                backgroundImage: friend.profileImageUrl != null
                    ? NetworkImage(friend.profileImageUrl!)
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
                          fontFamily: 'Pretendard',
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
                      color: const Color(0xfff9f9f9),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Pretendard',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Text(
                        friend.id,
                        style: TextStyle(
                          color: const Color(0xff999999),
                          fontSize: 14.sp,
                          fontFamily: 'Pretendard',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 체크박스 또는 상태 표시
            Container(
              width: 24.w,
              height: 24.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAlreadyMember
                    ? Color(0xffffffff)
                    : isSelected
                    ? Color(0xffffffff)
                    : Color(0xff5a5a5a),
              ),
              child: Icon(
                Icons.check,
                color: isAlreadyMember
                    ? Color(0xff000000)
                    : isSelected
                    ? Color(0xff000000)
                    : Color(0xfff9f9f9),
                size: 16.w,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
