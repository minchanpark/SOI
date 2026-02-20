import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:soi/views/about_friends/friend_management_screen.dart';

import '../../api/controller/friend_controller.dart' as api_friend;
import '../../api/controller/user_controller.dart';
import '../../api/models/selected_friend_model.dart';
import '../../api/models/user.dart';
import '../../utils/snackbar_utils.dart';
import 'models/add_category_draft.dart';

/// 카테고리 추가 화면
class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({super.key});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final TextEditingController _categoryNameController = TextEditingController();
  final TextEditingController _friendSearchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _categoryFocusNode = FocusNode();

  final ImagePicker _imagePicker = ImagePicker();

  final Map<int, SelectedFriendModel> _selectedFriendsById =
      <int, SelectedFriendModel>{};

  List<User> _friends = const [];
  File? _selectedCoverImageFile;

  bool _isLoadingFriends = false;
  bool _isClosing = false;
  bool _isSubmitting = false;
  String? _friendLoadError;

  @override
  void initState() {
    super.initState();
    _friendSearchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFriends();
    });
  }

  @override
  void dispose() {
    _categoryNameController.dispose();
    _friendSearchController.removeListener(_handleSearchChanged);
    _friendSearchController.dispose();
    _scrollController.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _handleConfirmPressed() {
    if (_isClosing || _isSubmitting) return;

    final categoryName = _categoryNameController.text.trim();
    if (categoryName.isEmpty) {
      SnackBarUtils.showSnackBar(
        context,
        tr('archive.create_category_name_required', context: context),
      );
      return;
    }

    final userController = context.read<UserController>();
    final currentUser = userController.currentUser;

    if (currentUser == null) {
      SnackBarUtils.showSnackBar(
        context,
        tr('common.login_required_relogin', context: context),
      );
      return;
    }

    final draft = AddCategoryDraft(
      requesterId: currentUser.id,
      categoryName: categoryName,
      selectedFriends: _selectedFriendsById.values.toList(growable: false),
      selectedCoverImageFile: _selectedCoverImageFile,
    );

    setState(() {
      _isSubmitting = true;
      _isClosing = true;
    });

    _categoryFocusNode.unfocus();
    Navigator.of(context).pop(draft);
  }

  Future<void> _handleSelectCoverImage() async {
    if (_isClosing || _isSubmitting) return;

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null || !mounted) return;

      setState(() {
        _selectedCoverImageFile = File(image.path);
      });
    } catch (_) {
      if (!mounted) return;
      SnackBarUtils.showSnackBar(
        context,
        tr('category.cover.gallery_error', context: context),
      );
    }
  }

  Future<void> _loadFriends() async {
    if (!mounted) return;

    setState(() {
      _isLoadingFriends = true;
      _friendLoadError = null;
    });

    try {
      final userController = context.read<UserController>();
      final currentUserId = userController.currentUser?.id;

      if (currentUserId == null) {
        setState(() {
          _friends = const [];
          _friendLoadError = tr('common.login_info_required', context: context);
        });
        return;
      }

      final friendController = context.read<api_friend.FriendController>();
      final friends = await friendController.getAllFriends(
        userId: currentUserId,
      );

      if (!mounted) return;
      setState(() {
        _friends = friends;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _friendLoadError = tr('friends.load_failed', context: context);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }
    }
  }

  Future<void> _handleAddFriends() async {
    if (_isClosing || _isSubmitting) return;

    final result = await Navigator.push<List<SelectedFriendModel>>(
      context,
      MaterialPageRoute(builder: (context) => FriendManagementScreen()),
    );

    if (result == null || !mounted) return;

    final selectedById = <int, SelectedFriendModel>{};
    for (final friend in result) {
      final parsedId = int.tryParse(friend.uid);
      if (parsedId == null) continue;
      selectedById[parsedId] = friend;
    }

    setState(() {
      _selectedFriendsById
        ..clear()
        ..addAll(selectedById);
    });
  }

  List<User> get _displayFriends {
    final query = _friendSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _friends;

    return _friends
        .where((friend) {
          final name = friend.name.toLowerCase();
          final nickname = friend.userId.toLowerCase();
          return name.contains(query) || nickname.contains(query);
        })
        .toList(growable: false);
  }

  void _toggleFriendSelection(User friend) {
    final isSelected = _selectedFriendsById.containsKey(friend.id);

    setState(() {
      if (isSelected) {
        _selectedFriendsById.remove(friend.id);
      } else {
        _selectedFriendsById[friend.id] = SelectedFriendModel(
          uid: friend.id.toString(),
          name: friend.name,
          profileImageUrl: friend.profileImageUrlKey,
        );
      }
    });
  }

  Widget _buildCoverSection() {
    final selectedCoverImageFile = _selectedCoverImageFile;

    return Center(
      child: SizedBox(
        width: 174,
        height: 174,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: GestureDetector(
                onTap: _handleSelectCoverImage,
                child: Container(
                  width: 174,
                  height: 174,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: selectedCoverImageFile == null
                        ? Border.all(color: const Color(0xFF5D5D5D), width: 1)
                        : null,
                    image: selectedCoverImageFile != null
                        ? DecorationImage(
                            image: FileImage(selectedCoverImageFile),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -10.w,
              bottom: -10.h,
              child: GestureDetector(
                onTap: _handleSelectCoverImage,
                child: Container(
                  width: 31.w,
                  height: 31.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B3B3B),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/category_edit.svg',
                      width: (14.93).sp,
                      height: (14.93).sp,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '스페이스 이름',
          style: TextStyle(
            color: Color(0xffcccccc),
            fontSize: 18.sp,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 14.sp),
        Container(
          height: 53.sp,
          padding: EdgeInsets.symmetric(horizontal: 18.sp),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _categoryNameController,
                  cursorColor: Colors.white,
                  focusNode: _categoryFocusNode,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: '스페이스 이름',
                    hintStyle: TextStyle(
                      color: const Color(0xFF909090),
                      fontSize: 16.sp,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  maxLength: 20,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) {
                        return null;
                      },
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _categoryNameController,
                builder: (context, value, child) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: _categoryNameController.clear,
                    child: SvgPicture.asset(
                      'assets/category_edit_cancel.svg',
                      width: (23.75).sp,
                      height: (23.75).sp,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Container(
      height: 62.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: const Color(0xFFD4D4D4), size: 30.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: TextField(
              controller: _friendSearchController,
              cursorColor: Colors.white,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: tr('friends.search_hint', context: context),
                hintStyle: TextStyle(
                  color: const Color(0xFF9C9C9C),
                  fontSize: 16.sp,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendAvatar(User friend) {
    final profileUrl = friend.profileImageUrlKey;
    final hasProfileImage = profileUrl != null && profileUrl.isNotEmpty;

    if (hasProfileImage) {
      return CircleAvatar(
        radius: 23.r,
        backgroundColor: const Color(0xFF323232),
        backgroundImage: CachedNetworkImageProvider(profileUrl),
      );
    }

    return CircleAvatar(
      radius: 23.r,
      backgroundColor: const Color(0xFF323232),
      child: Text(
        friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: const Color(0xFFF8F8F8),
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          fontFamily: 'Pretendard',
        ),
      ),
    );
  }

  Widget _buildFriendRow(User friend) {
    final isSelected = _selectedFriendsById.containsKey(friend.id);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggleFriendSelection(friend),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
        child: Row(
          children: [
            _buildFriendAvatar(friend),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFF8F8F8),
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    friend.userId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFFA4A4A4),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 27.sp,
              height: 27.sp,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFFFFFFFF)
                    : const Color(0xFF5D5D5D),
              ),
              child: Icon(
                Icons.check,
                color: isSelected
                    ? const Color(0xFF000000)
                    : const Color(0xFFF4F4F4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsCard() {
    if (_isLoadingFriends) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 36.h),
        decoration: BoxDecoration(
          color: const Color(0xFF161719),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_friendLoadError != null) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 28.h),
        decoration: BoxDecoration(
          color: const Color(0xFF161719),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          _friendLoadError!,
          style: TextStyle(
            color: const Color(0xFFB4B4B4),
            fontSize: 14.sp,
            fontFamily: 'Pretendard',
          ),
        ),
      );
    }

    final displayFriends = _displayFriends;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF161719),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _handleAddFriends,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.fromLTRB(18.sp, 10.sp, 0, 12.sp),
              child: Row(
                children: [
                  Container(
                    width: 44.sp,
                    height: 44.sp,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2F2F31),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      color: const Color(0xFFD9D9D9),
                      size: 28.sp,
                    ),
                  ),
                  SizedBox(width: 7.w),
                  Text(
                    '친구 추가',
                    style: TextStyle(
                      color: const Color(0xFFCBCBCB),
                      fontSize: 16.sp,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (displayFriends.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(18.sp, 10.sp, 0, 22.sp),
              child: Text(
                _friendSearchController.text.trim().isEmpty
                    ? tr('friends.empty', context: context)
                    : tr('common.search_empty', context: context),
                style: TextStyle(
                  color: const Color(0xFF9C9C9C),
                  fontSize: 14.sp,
                  fontFamily: 'Pretendard',
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayFriends.length,
              itemBuilder: (context, index) {
                final friend = displayFriends[index];
                return _buildFriendRow(friend);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFFffffff)),
        title: Text(
          "스페이스 만들기",
          style: TextStyle(
            color: const Color(0xFFF8F8F8),
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            fontFamily: 'Pretendard Variable',
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: 56.w,
            height: 29.h,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleConfirmPressed,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFFf8f8f8),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: const Color(0xFF1c1c1c),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(
                '확인',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Pretendard Variable',
                ),
              ),
            ),
          ),
        ],
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(20.sp, 10.sp, 20.sp, 24.sp),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 17.sp),
              _buildCoverSection(),
              SizedBox(height: 28.h),
              _buildNameInputSection(),
              SizedBox(height: 26.h),
              Text(
                '친구 목록',
                style: TextStyle(
                  color: const Color(0xFFCBCBCB),
                  fontSize: 18.sp,
                  fontFamily: 'Pretendard Variable',
                ),
              ),
              SizedBox(height: 14.h),
              _buildSearchBox(),
              SizedBox(height: 12.h),
              _buildFriendsCard(),
            ],
          ),
        ),
      ),
    );
  }
}
