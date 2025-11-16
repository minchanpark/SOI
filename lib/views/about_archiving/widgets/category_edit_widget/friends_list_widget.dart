import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../api_firebase/models/category_data_model.dart';
import '../../../../api_firebase/models/auth_model.dart';
import '../../../about_friends/friend_list_add_screen.dart';

class FriendsListWidget extends StatelessWidget {
  final CategoryDataModel category;
  final Map<String, AuthModel> friendsInfo;
  final bool isLoadingFriends;
  final bool isExpanded;
  final VoidCallback onExpandToggle;
  final VoidCallback onCollapseToggle;
  final VoidCallback? onFriendAdded; // 친구 추가 후 콜백 추가

  const FriendsListWidget({
    super.key,
    required this.category,
    required this.friendsInfo,
    required this.isLoadingFriends,
    required this.isExpanded,
    required this.onExpandToggle,
    required this.onCollapseToggle,
    this.onFriendAdded,
  });

  @override
  Widget build(BuildContext context) {
    // 최대 5개까지만 표시 (나머지는 "+더보기"로 표시)
    const int maxDisplayCount = 5;
    final totalMates = category.mates.length;
    final displayMates = isExpanded
        ? category.mates
        : category.mates.take(maxDisplayCount).toList();
    final hasMore = totalMates > maxDisplayCount && !isExpanded;

    return Container(
      width: double.infinity,

      padding: EdgeInsets.only(left: 18.w, top: 20.3.h, right: 18.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1c1c1c),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // 헤더
          InkWell(
            onTap: () async {
              // FriendListAddScreen으로 이동
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FriendListAddScreen(
                    categoryId: category.id,
                    categoryMemberUids: category.mates,
                  ),
                ),
              );

              // 돌아온 후 부모에게 새로고침 알림
              if (onFriendAdded != null) {
                onFriendAdded!();
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF323232),
                  ),
                  child: Icon(Icons.add, color: Colors.white, size: 27.sp),
                ),
                SizedBox(width: 12.w),
                Text(
                  "친구 추가",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 16.h),

          // 로딩 상태 표시
          if (isLoadingFriends) ...[
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20.h),
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.0,
                ),
              ),
            ),
          ] else ...[
            // 친구 목록을 ListView로 구성
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount:
                  (displayMates.length * 2) + // 친구들과 그 사이 간격들
                  (hasMore ? 2 : 0) + // 더보기 버튼과 그 앞 간격
                  (isExpanded && totalMates > maxDisplayCount ? 2 : 0),
              itemBuilder: (context, index) {
                // 홀수 인덱스는 간격
                if (index.isOdd) {
                  return SizedBox(height: 17.h);
                }

                // 짝수 인덱스는 실제 아이템
                final itemIndex = index ~/ 2;

                // 친구 아이템들
                if (itemIndex < displayMates.length) {
                  final mateUid = displayMates[itemIndex];
                  final friendInfo = friendsInfo[mateUid];
                  // 로딩 중이거나 정보가 없을 때 로딩 상태로 표시
                  final isLoadingThis = isLoadingFriends || friendInfo == null;

                  return _FriendListItem(
                    mateUid: mateUid,
                    friendInfo: friendInfo,
                    isLoading: isLoadingThis,
                  );
                }

                // "+더보기" 버튼
                if (hasMore && itemIndex == displayMates.length) {
                  return GestureDetector(
                    onTap: onExpandToggle,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Divider(color: const Color(0xFF666666), indent: 0),
                        SizedBox(height: 2.h), // 간격 줄임
                        Padding(
                          padding: EdgeInsets.only(left: 18.w),
                          child: Text(
                            '+ 더보기',
                            style: TextStyle(
                              color: const Color(0xFFCCCCCC),
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Pretendard Variable',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // "접기" 버튼
                if (isExpanded && totalMates > maxDisplayCount) {
                  return SizedBox(
                    child: GestureDetector(
                      onTap: onCollapseToggle,
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF444444),
                              border: Border.all(
                                color: const Color(0xFF666666),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            '접기',
                            style: TextStyle(
                              color: const Color(0xFFCCCCCC),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Pretendard Variable',
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _FriendListItem extends StatelessWidget {
  final String mateUid;
  final AuthModel? friendInfo;
  final bool isLoading;

  const _FriendListItem({
    required this.mateUid,
    required this.friendInfo,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // 로딩 중일 때 Shimmer 효과 표시
    if (isLoading) {
      return Row(
        children: [
          // 프로필 이미지 Shimmer
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF444444),
            ),
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF666666),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          // 텍스트 정보 Shimmer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 이름 Shimmer
                Container(
                  width: 100.w,
                  height: 16.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF444444),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 4.h),
                // ID Shimmer
                Container(
                  width: 80.w,
                  height: 12.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        // 프로필 이미지
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFd9d9d9),
          ),
          child:
              friendInfo?.profileImage != null &&
                  friendInfo!.profileImage.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: friendInfo!.profileImage,
                  width: 40.w,
                  height: 40.w,
                  fit: BoxFit.cover,
                  memCacheWidth: (40 * 4).round(),
                  maxWidthDiskCache: (40 * 4).round(),
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.grey.shade600,
                    highlightColor: Colors.grey.shade400,
                    child: Container(
                      width: 40.w,
                      height: 40.h,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 40.w,
                    height: 40.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFd9d9d9),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                )
              : Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFd9d9d9),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
        ),
        SizedBox(width: 12.w),
        // 텍스트 정보
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 이름
              Text(
                friendInfo?.name ??
                    (isLoading || friendInfo == null
                        ? '로딩 중...'
                        : '이름을 알 수 없습니다'),
                style: TextStyle(
                  color: friendInfo?.name != null
                      ? Color(0xffd9d9d9)
                      : Color(0xFF888888),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Pretendard',
                  height: 1.0,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              SizedBox(height: (4.76).h),
              // ID
              Text(
                friendInfo?.id ??
                    (isLoading || friendInfo == null
                        ? '정보를 가져오는 중...'
                        : '알 수 없음'),
                style: TextStyle(
                  color: friendInfo?.id != null
                      ? const Color(0xFFAAAAAA)
                      : const Color(0xFF666666),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Pretendard',
                  height: 1.0,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
