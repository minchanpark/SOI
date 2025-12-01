import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../api_firebase/models/user_search_model.dart';
import '../../api_firebase/controllers/user_matching_controller.dart';
import '../../api_firebase/controllers/friend_request_controller.dart';

/// ID로 친구 추가 화면
/// 기존 다이얼로그(AddByIdDialog)를 대체하며
/// UserMatchingController / FriendRequestController 의 기존 비즈니스 로직을 재사용한다.
class AddFriendByIdScreen extends StatefulWidget {
  const AddFriendByIdScreen({super.key});

  @override
  State<AddFriendByIdScreen> createState() => _AddFriendByIdScreenState();
}

class _AddFriendByIdScreenState extends State<AddFriendByIdScreen> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  bool _isSearching = false;
  List<UserSearchModel> _results = [];
  Map<String, String> _friendshipStatus = {};
  final Map<String, _CachedSearchResult> _searchCache = {};
  final Set<String> _sending = {}; // 요청 버튼 로딩 대상

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.removeListener(_onQueryChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    final query = _textController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _friendshipStatus = {};
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final cached = _searchCache[query];
    if (cached != null) {
      setState(() {
        _results = cached.results;
        _friendshipStatus = cached.status;
        _isSearching = false;
      });
      return;
    }

    final userMatchingController = Provider.of<UserMatchingController>(
      context,
      listen: false,
    );
    final friendRequestController = Provider.of<FriendRequestController>(
      context,
      listen: false,
    );

    setState(() => _isSearching = true);
    try {
      // Controller의 기존 ID 검색 로직 재사용
      final list = await userMatchingController.searchUserById(query) ?? [];
      _results = list;

      // 상태 일괄 조회 (비즈니스 로직 재사용)
      if (list.isNotEmpty) {
        final statusMap = await friendRequestController
            .getBatchFriendshipStatus(list.map((e) => e.uid).toList());
        _friendshipStatus = statusMap;
      } else {
        _friendshipStatus = {};
      }

      _searchCache[query] = _CachedSearchResult(
        _results,
        _friendshipStatus,
      );
    } catch (e) {
      // 실패 시 결과 비우기 (UI는 '없는 아이디' 메시지 그대로 활용)
      _results = [];
      _friendshipStatus = {};
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendFriendRequest(UserSearchModel user) async {
    final friendRequestController = Provider.of<FriendRequestController>(
      context,
      listen: false,
    );
    setState(() => _sending.add(user.uid));
    try {
      final success = await friendRequestController.sendFriendRequest(
        receiverUid: user.uid,
        message: 'ID로 친구 요청을 보냅니다.',
      );
      if (success) {
        setState(() {
          _friendshipStatus[user.uid] = 'sent';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('친구 요청을 보냈습니다'),
              backgroundColor: Color(0xFF5A5A5A),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('친구 요청 실패'),
            backgroundColor: Color(0xFF5A5A5A),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending.remove(user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const double referenceWidth = 393;
    final double scale = screenWidth / referenceWidth;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              'ID로 추가하기',
              style: TextStyle(
                color: const Color(0xFFD9D9D9),
                fontSize: 20,
                fontFamily: GoogleFonts.inter().fontFamily,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xffd9d9d9)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(scale),
            Expanded(child: _buildResultsArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(double scale) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xff1c1c1c),
          borderRadius: BorderRadius.circular(8 * scale),
        ),
        child: Row(
          children: [
            SizedBox(width: 12),
            Icon(Icons.search, color: const Color(0xffd9d9d9), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                style: TextStyle(color: const Color(0xfff9f9f9), fontSize: 15),
                cursorColor: const Color(0xfff9f9f9),
                decoration: InputDecoration(
                  hintText: '친구 아이디 찾기',
                  hintStyle: TextStyle(
                    color: const Color(0xFFD9D9D9),
                    fontSize: 18.02,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.only(bottom: 2),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => _performSearch(v.trim()),
              ),
            ),
            if (_textController.text.isNotEmpty)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close,
                  color: const Color(0xff9a9a9a),
                  size: 18.sp,
                ),
                onPressed: () {
                  _textController.clear();
                  setState(() {
                    _results = [];
                    _friendshipStatus = {};
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsArea() {
    if (_textController.text.isEmpty) {
      // 초기 상태: 아무 것도 표시하지 않음 (디자인 상 빈 화면)
      return const SizedBox.shrink();
    }
    if (_isSearching) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Colors.white,
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          '없는 아이디 입니다. 다시 입력해주세요',
          style: TextStyle(color: const Color(0xff9a9a9a), fontSize: 14.sp),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
      itemBuilder: (context, index) {
        final user = _results[index];
        final status = _friendshipStatus[user.uid] ?? 'none';
        final isSending = _sending.contains(user.uid);
        return _UserResultTile(
          user: user,
          status: status,
          isSending: isSending,
          onAdd: () => _sendFriendRequest(user),
        );
      },
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemCount: _results.length,
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({
    required this.user,
    required this.status,
    required this.isSending,
    required this.onAdd,
  });

  final UserSearchModel user;
  final String status; // 'none' | 'sent' | 'received' | 'friends'
  final bool isSending;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1c1c1c),
        borderRadius: BorderRadius.circular(12.r),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      child: Row(
        children: [
          _buildAvatar(devicePixelRatio),
          SizedBox(width: 12.w),
          Expanded(child: _buildTexts()),
          _buildActionButton(context),
        ],
      ),
    );
  }

  Widget _buildAvatar(double devicePixelRatio) {
    final placeholder = Container(
      width: 44.w,
      height: 44.w,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xffd9d9d9),
      ),
      /* child: Center(
        child: Text(
          user.name.isNotEmpty ? user.name.characters.first : 'U',
          style: TextStyle(
            color: const Color(0xfff9f9f9),
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),*/
      child: Icon(Icons.person, size: 26, color: Colors.white),
    );
    if (user.profileImageUrl == null || user.profileImageUrl!.isEmpty) {
      return placeholder;
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: user.profileImageUrl!,
        width: 44.w,
        height: 44.w,
        memCacheWidth: (44 * 2).round(),
        maxWidthDiskCache: (44 * 2).round(),
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }

  Widget _buildTexts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          user.name.isNotEmpty ? user.name : user.id,
          style: TextStyle(
            color: const Color(0xfff9f9f9),
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            height: 1.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 4.h),
        Text(
          user.id,
          style: TextStyle(
            color: const Color(0xff9a9a9a),
            fontSize: 12.sp,
            height: 1.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    String label;
    bool enabled = false;
    switch (status) {
      case 'friends':
        label = '친구';
        enabled = false;
        break;
      case 'sent':
        label = '요청됨';
        enabled = false;
        break;
      case 'received':
        label = '수락 대기'; // 별도 수락 플로우는 기존 화면에서 처리
        enabled = false;
        break;
      default:
        label = '친구 추가';
        enabled = true;
    }

    final child = isSending
        ? SizedBox(
            width: 16.w,
            height: 16.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(
            label,
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
          );

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: 72.w),
      child: SizedBox(
        height: 32.h,
        child: ElevatedButton(
          onPressed: enabled && !isSending ? onAdd : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: enabled
                ? const Color(0xffffffff)
                : const Color(0xff3a3a3a),
            foregroundColor: enabled
                ? const Color(0xff000000)
                : const Color(0xffc9c9c9),
            disabledBackgroundColor: const Color(0xff3a3a3a),
            disabledForegroundColor: const Color(0xffc9c9c9),
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            minimumSize: Size(0, 32.h),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            elevation: 0,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 메모이제이션된 검색 결과 구조체
class _CachedSearchResult {
  _CachedSearchResult(this.results, this.status);

  final List<UserSearchModel> results;
  final Map<String, String> status;
}
