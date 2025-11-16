import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../api_firebase/controllers/auth_controller.dart';
import '../../../api_firebase/models/category_data_model.dart';
import '../../../api_firebase/models/auth_model.dart';
import '../../about_friends/friend_list_add_screen.dart';

/// 카테고리 멤버들을 보여주는 바텀시트
class CategoryMembersBottomSheet extends StatefulWidget {
  final CategoryDataModel category;

  const CategoryMembersBottomSheet({super.key, required this.category});

  @override
  State<CategoryMembersBottomSheet> createState() =>
      _CategoryMembersBottomSheetState();
}

class _CategoryMembersBottomSheetState
    extends State<CategoryMembersBottomSheet> {
  Map<String, AuthModel> _membersInfo = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembersInfo();
  }

  /// 멤버들의 정보를 로드
  Future<void> _loadMembersInfo() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authController = context.read<AuthController>();
      final Map<String, AuthModel> membersInfo = {};

      for (String mateUid in widget.category.mates) {
        try {
          final userInfo = await authController.getUserInfo(mateUid);
          if (userInfo != null) {
            membersInfo[mateUid] = userInfo;
          }
        } catch (e) {
          // 개별 사용자 로드 실패 시 로그만 출력하고 계속 진행
          debugPrint('멤버 정보 로드 실패 ($mateUid): $e');
        }
      }

      if (mounted) {
        setState(() {
          _membersInfo = membersInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 7.h),
          // 핸들바
          Container(
            width: 56.w,
            height: 2.9.h,
            decoration: BoxDecoration(
              color: const Color(0xFFCCCCCC),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          SizedBox(height: 24.h),

          // 멤버 목록
          if (_isLoading) _buildLoadingWidget() else _buildMembersGrid(),

          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  /// 로딩 위젯
  Widget _buildLoadingWidget() {
    final matesCount = widget.category.mates.length;
    final itemCount = matesCount + 1; // +1 for 친구 추가 버튼

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.8,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 12.w,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // 마지막 아이템은 친구 추가 버튼
          if (index == matesCount) {
            return _buildAddFriendButton();
          }

          // Shimmer 멤버 아이템
          return _buildShimmerMemberItem();
        },
      ),
    );
  }

  /// Shimmer 멤버 아이템
  Widget _buildShimmerMemberItem() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade800,
      highlightColor: Colors.grey.shade700,
      period: const Duration(milliseconds: 1500),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 프로필 이미지 shimmer
          Container(
            width: 60.w,
            height: 60.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade800,
            ),
          ),

          SizedBox(height: 8.h),

          // 이름 shimmer
          Container(
            width: 40.w,
            height: 12.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
        ],
      ),
    );
  }

  /// 멤버 그리드 위젯
  Widget _buildMembersGrid() {
    final members = _membersInfo.values.toList();
    final itemCount = members.length + 1; // +1 for 친구 추가 버튼

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.8,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 12.w,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // 마지막 아이템은 친구 추가 버튼
          if (index == members.length) {
            return _buildAddFriendButton();
          }

          // 멤버 아이템
          final member = members[index];
          return _buildMemberItem(member);
        },
      ),
    );
  }

  /// 개별 멤버 아이템
  Widget _buildMemberItem(AuthModel member) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 프로필 이미지
        ClipOval(
          child: SizedBox(
            width: 60,
            height: 60,
            child: member.profileImage.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: member.profileImage,
                    fit: BoxFit.cover,
                    memCacheWidth: (60 * 4).round(),
                    maxWidthDiskCache: (60 * 4).round(),
                    placeholder: (context, url) => _buildMemberShimmer(),
                    errorWidget: (context, url, error) =>
                        _buildMemberFallback(),
                  )
                : _buildMemberFallback(),
          ),
        ),

        SizedBox(height: (5.86).h),

        // 이름
        Text(
          member.name.isNotEmpty ? member.name : '사용자',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            fontFamily: 'Pretendard',
            letterSpacing: -0.4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// 친구 추가 버튼
  Widget _buildAddFriendButton() {
    return GestureDetector(
      onTap: () async {
        // 바텀시트 닫기
        Navigator.pop(context);

        // 친구 추가 화면으로 이동
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FriendListAddScreen(
              categoryId: widget.category.id,
              categoryMemberUids: widget.category.mates,
            ),
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // + 버튼
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFffffff),
            ),
            child: Center(
              child: Image.asset(
                'assets/plus_icon.png',
                width: 25.5,
                height: 25.5,
                fit: BoxFit.cover,
              ),
            ),
          ),

          SizedBox(height: 8.h),

          // 텍스트
          Text(
            '추가하기',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              fontFamily: 'Pretendard',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

Widget _buildMemberShimmer() {
  return Shimmer.fromColors(
    baseColor: Colors.grey.shade700,
    highlightColor: Colors.grey.shade500,
    child: Container(
      width: 60,
      height: 60,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
    ),
  );
}

Widget _buildMemberFallback() {
  return Container(
    width: 60,
    height: 60,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFd9d9d9),
    ),
    child: const Icon(Icons.person, color: Colors.white, size: 44),
  );
}
