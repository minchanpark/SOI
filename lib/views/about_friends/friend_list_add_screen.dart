import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:soi/api/controller/category_controller.dart' as api_category;
import 'package:soi/api/controller/friend_controller.dart' as api_friend;
import 'package:soi/api/controller/user_controller.dart';
import 'package:soi/api/models/selected_friend_model.dart';
import 'package:soi/api/models/user.dart';

/// 친구 추가 화면 (REST API 버전)
class FriendListAddScreen extends StatefulWidget {
  final String? categoryId; // 카테고리에 친구를 추가할 때 사용
  final List<String>? categoryMemberUids; // 이미 카테고리에 포함된 사용자 ID 목록
  final bool allowDeselection; // 새 카테고리 만들기에서 true

  const FriendListAddScreen({
    super.key,
    this.categoryId,
    this.categoryMemberUids,
    this.allowDeselection = false,
  });

  @override
  State<FriendListAddScreen> createState() => _FriendListAddScreenState();
}

class _FriendListAddScreenState extends State<FriendListAddScreen> {
  final Set<int> _selectedFriendIds = <int>{};
  final TextEditingController _searchController = TextEditingController();
  bool _isNavigating = false;

  List<User> _friends = [];
  bool _isLoadingFriends = false;
  String? _friendLoadErrorKey;
  Set<int> _existingMemberIds = <int>{};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _existingMemberIds = _parseUidsToIds(widget.categoryMemberUids);

    // 이미 카테고리에 포함된 사용자는 기본 선택 상태로 표시한다.
    // 편집 화면에서는 allowDeselection=false로 전달되어 해제 불가(잠금) 처리된다.
    _selectedFriendIds.addAll(_existingMemberIds);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFriends();
    });
  }

  @override
  void dispose() {
    _isNavigating = true;
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      debugPrint('검색어 변경: "${_searchController.text}"');
    });
  }

  Future<void> _loadFriends() async {
    if (!mounted) return;

    setState(() {
      _isLoadingFriends = true;
      _friendLoadErrorKey = null;
    });

    try {
      final userController = context.read<UserController>();
      final currentUserId = userController.currentUser?.id;

      if (currentUserId == null) {
        setState(() {
          _friends = [];
          _friendLoadErrorKey = 'common.login_info_required';
        });
        return;
      }

      final friendController = context.read<api_friend.FriendController>();
      final friends = await friendController.getAllFriends(
        userId: currentUserId,
      );

      if (mounted) {
        setState(() {
          _friends = friends;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _friendLoadErrorKey = 'friends.load_failed';
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

  void _toggleFriendSelection(int friendId) {
    // 이미 포함된 멤버는(편집 화면) 선택 해제가 불가능해야 한다.
    if (!widget.allowDeselection && _existingMemberIds.contains(friendId)) {
      return;
    }
    if (!_selectedFriendIds.contains(friendId)) {
      _selectedFriendIds.add(friendId);
    } else {
      _selectedFriendIds.remove(friendId);
    }
    setState(() {});
  }

  Future<void> _onConfirmPressed() async {
    if (_isNavigating) return;

    if (widget.categoryId != null) {
      await _inviteFriendsToCategory();
    } else {
      _returnSelectedFriends();
    }
  }

  Future<void> _inviteFriendsToCategory() async {
    final parsedCategoryId = int.tryParse(widget.categoryId ?? '');

    if (parsedCategoryId == null) {
      _showSnackBar(tr('archive.category_info_invalid', context: context));
      return;
    }

    final userController = context.read<UserController>();
    final requesterId = userController.currentUser?.id;

    if (requesterId == null) {
      _showSnackBar(tr('common.login_required', context: context));
      return;
    }

    final receiverIds = _selectedFriendIds
        .where((id) => !_existingMemberIds.contains(id))
        .toList();

    if (receiverIds.isEmpty) {
      _showSnackBar(tr('friends.select_to_add', context: context));
      return;
    }

    try {
      final categoryController = context
          .read<api_category.CategoryController>();
      final success = await categoryController.inviteUsersToCategory(
        categoryId: parsedCategoryId,
        requesterId: requesterId,
        receiverIds: receiverIds,
      );

      if (!success) {
        throw Exception('친구 초대 실패');
      }

      _existingMemberIds.addAll(receiverIds);

      await categoryController.loadCategories(requesterId, forceReload: true);

      if (!mounted || _isNavigating) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'friends.invite_sent',
              context: context,
              namedArgs: {'count': receiverIds.length.toString()},
            ),
          ),
          backgroundColor: const Color(0xFF5A5A5A),
          duration: const Duration(seconds: 2),
        ),
      );

      _isNavigating = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    } catch (e) {
      _showSnackBar(
        tr(
          'friends.invite_error_with_reason',
          context: context,
          namedArgs: {'error': e.toString()},
        ),
      );
    }
  }

  void _returnSelectedFriends() {
    if (!mounted || _isNavigating) return;

    final selectedFriends = <SelectedFriendModel>[];

    for (final friendId in _selectedFriendIds) {
      final friend = _findFriendById(friendId);
      final friendName = friend?.name ?? tr('common.unknown', context: context);
      final profileUrl = friend?.profileImageUrlKey;

      selectedFriends.add(
        SelectedFriendModel(
          uid: friendId.toString(),
          name: friendName,
          profileImageUrl: profileUrl,
        ),
      );
    }

    _isNavigating = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(selectedFriends);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.toLowerCase();
    final hasQuery = query.isNotEmpty;
    final displayFriends = hasQuery
        ? _friends.where((friend) {
            final name = friend.name.toLowerCase();
            final nickname = friend.userId.toLowerCase();
            return name.contains(query) || nickname.contains(query);
          }).toList()
        : _friends;

    final hasSelection = _selectedFriendIds.isNotEmpty;
    final canComplete = widget.allowDeselection || hasSelection;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xffd9d9d9)),
        title: Text(
          'friends.list_title',
          style: TextStyle(
            color: const Color(0xfff9f9f9),
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            fontFamily: 'Pretendard',
          ),
        ).tr(),
        centerTitle: false,
      ),
      body: Column(
        children: [
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
                        hintText: tr('friends.search_hint', context: context),
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
          Expanded(
            child: _isLoadingFriends
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _friendLoadErrorKey != null
                ? Center(
                    child: Text(
                      _friendLoadErrorKey!,
                      style: TextStyle(
                        color: const Color(0xff666666),
                        fontSize: 14.sp,
                      ),
                    ).tr(),
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
                            SizedBox(height: 14.h),
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
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Color(0xff4a4a4a),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          size: 25,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Text(
                                        "friends.add_friend",
                                        style: TextStyle(
                                          color: const Color(0xfff9f9f9),
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w900,
                                          fontFamily: 'Pretendard',
                                        ),
                                      ).tr(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: displayFriends.map((friend) {
                                final isSelected = _selectedFriendIds.contains(
                                  friend.id,
                                );
                                final isAlreadyMember =
                                    !widget.allowDeselection &&
                                    _existingMemberIds.contains(friend.id);

                                return _buildFriendItem(
                                  friend: friend,
                                  isSelected: isSelected,
                                  isAlreadyMember: isAlreadyMember,
                                  onTap: () =>
                                      _toggleFriendSelection(friend.id),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            child: SizedBox(
              height: 48.h,
              child: ElevatedButton(
                onPressed: canComplete ? _onConfirmPressed : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasSelection
                      ? const Color(0xffffffff)
                      : const Color(0xff5a5a5a),
                  disabledBackgroundColor: hasSelection
                      ? const Color(0xffffffff)
                      : const Color(0xff5a5a5a),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'common.done',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Pretendard',
                    color: hasSelection
                        ? Colors.black
                        : const Color(0xfff8f8f8),
                  ),
                ).tr(),
              ),
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildFriendItem({
    required User friend,
    required bool isSelected,
    required bool isAlreadyMember,
    required VoidCallback onTap,
  }) {
    final profileUrl = friend.profileImageUrlKey;
    final hasProfileImage = profileUrl != null && profileUrl.isNotEmpty;

    return GestureDetector(
      onTap: isAlreadyMember ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: hasProfileImage
                  ? CircleAvatar(
                      radius: 24.r,
                      backgroundColor: const Color(0xff323232),
                      backgroundImage: CachedNetworkImageProvider(profileUrl),
                    )
                  : CircleAvatar(
                      radius: 24.r,
                      backgroundColor: const Color(0xff323232),
                      child: Text(
                        friend.name.isNotEmpty
                            ? friend.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: const Color(0xfff9f9f9),
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                    ),
            ),
            SizedBox(width: 12.w),
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
                  Text(
                    friend.userId,
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
            ),
            Container(
              width: 24.w,
              height: 24.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isAlreadyMember
                    ? const Color(0xffffffff)
                    : isSelected
                    ? const Color(0xffffffff)
                    : const Color(0xff5a5a5a),
              ),
              child: Icon(
                Icons.check,
                color: isAlreadyMember
                    ? const Color(0xff000000)
                    : isSelected
                    ? const Color(0xff000000)
                    : const Color(0xfff9f9f9),
                size: 16.w,
              ),
            ),
          ],
        ),
      ),
    );
  }

  User? _findFriendById(int friendId) {
    try {
      return _friends.firstWhere((friend) => friend.id == friendId);
    } catch (_) {
      return null;
    }
  }

  Set<int> _parseUidsToIds(List<String>? uids) {
    if (uids == null) return <int>{};
    final ids = <int>{};
    for (final uid in uids) {
      final parsed = int.tryParse(uid);
      if (parsed != null) {
        ids.add(parsed);
      }
    }
    return ids;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF5A5A5A),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
