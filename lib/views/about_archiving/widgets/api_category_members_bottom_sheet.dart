import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:soi/api/controller/media_controller.dart';
import '../../../api/models/category.dart';

/// API 버전 카테고리 멤버들을 보여주는 바텀시트
///
/// 바텀시트가 열릴 때 최신 카테고리 정보를 서버에서 가져와
/// 새로운 presigned URL로 프로필 이미지를 표시합니다.
class ApiCategoryMembersBottomSheet extends StatefulWidget {
  final Category category;
  final VoidCallback? onAddFriendPressed;

  const ApiCategoryMembersBottomSheet({
    super.key,
    required this.category,
    this.onAddFriendPressed,
  });

  @override
  State<ApiCategoryMembersBottomSheet> createState() =>
      _ApiCategoryMembersBottomSheetState();
}

class _ApiCategoryMembersBottomSheetState
    extends State<ApiCategoryMembersBottomSheet> {
  // presigned URL 캐시
  final Map<String, String> _presignedUrlCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // 빌드 완료 후 presigned URL 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPresignedUrls();
    });
  }

  /// 모든 프로필 이미지의 presigned URL을 미리 로드
  Future<void> _loadPresignedUrls() async {
    final mediaController = Provider.of<MediaController>(
      context,
      listen: false,
    );
    final profileUrlKeys = widget.category.usersProfileKey;

    for (final key in profileUrlKeys) {
      if (key.isNotEmpty) {
        try {
          final url = await mediaController.getPresignedUrl(key);
          if (url != null) {
            _presignedUrlCache[key] = url;
          }
        } catch (e) {
          debugPrint('[ApiCategoryMembersBottomSheet] presigned URL 로드 실패: $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileUrlKeys = widget.category.usersProfileKey;
    final totalMemberCount = widget.category.totalUserCount;
    final memberNickNames = widget.category.nickNames;

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

          // 멤버 목록 (로딩 중이면 shimmer 표시)
          _isLoading
              ? _buildLoadingGrid(totalMemberCount)
              : _buildMembersGrid(
                  context,
                  profileUrlKeys,
                  totalMemberCount,
                  memberNickNames,
                ),

          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  /// 로딩 중 그리드 (shimmer)
  Widget _buildLoadingGrid(int totalMemberCount) {
    final itemCount = totalMemberCount + 1;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.8,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 12.w,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == totalMemberCount) {
            return _buildAddFriendButton(context);
          }
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMemberShimmer(),
              SizedBox(height: (5.86).h),
              Container(
                width: 40.w,
                height: 12.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 멤버 그리드 위젯
  Widget _buildMembersGrid(
    BuildContext context,
    List<String> profileUrlKeys,
    int totalMemberCount,
    List<String> memberNickNames,
  ) {
    // 친구 추가 버튼 포함 총 아이템 수
    // +1 친구 추가 버튼 --> 추가하기 버튼을 위해서
    final itemCount = totalMemberCount + 1;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.8,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 12.w,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == totalMemberCount) {
            return _buildAddFriendButton(context);
          }

          final profileUrlKey = index < profileUrlKeys.length
              ? profileUrlKeys[index]
              : '';

          final memberNickName = index < memberNickNames.length
              ? memberNickNames[index]
              : '멤버 ${index + 1}';

          // 캐시에서 presigned URL 가져오기
          final profileUrl = _presignedUrlCache[profileUrlKey] ?? '';

          return _buildMemberItem(profileUrl, memberNickName, index);
        },
      ),
    );
  }

  /// 개별 멤버 아이템
  Widget _buildMemberItem(String profileUrl, String memberNickName, int index) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 프로필 이미지
        ClipOval(
          child: SizedBox(
            width: 60,
            height: 60,
            child: profileUrl.isNotEmpty
                // 프로필 이미지가 있으면, ChachedNetworkImage 사용
                ? CachedNetworkImage(
                    imageUrl: profileUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: (60 * 4).round(),
                    maxWidthDiskCache: (60 * 4).round(),
                    placeholder: (context, url) => _buildMemberShimmer(),
                    errorWidget: (context, url, error) {
                      debugPrint(
                        '[ApiCategoryMembersBottomSheet] 이미지 로드 에러: $error',
                      );
                      return _buildMemberFallback();
                    },
                  )
                // 프로필 이미지가 없으면, 기본 프로필 이미지 표시
                : _buildMemberFallback(),
          ),
        ),

        SizedBox(height: (5.86).h),

        // 이름 (임시)
        Text(
          memberNickName,
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
  Widget _buildAddFriendButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 바텀시트 닫기
        Navigator.pop(context);

        // 친구 추가 콜백 호출 (다음 프레임에서 실행)
        if (widget.onAddFriendPressed != null) {
          Future.microtask(widget.onAddFriendPressed!);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // + 버튼
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFffffff),
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

  /// Shimmer 로딩 위젯
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

  /// 기본 프로필 이미지 (fallback)
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
}

/// ApiCategoryMembersBottomSheet를 표시하는 헬퍼 함수
void showApiCategoryMembersBottomSheet(
  BuildContext context, {
  required Category category,
  VoidCallback? onAddFriendPressed,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => ApiCategoryMembersBottomSheet(
      category: category,
      onAddFriendPressed: onAddFriendPressed,
    ),
  );
}
