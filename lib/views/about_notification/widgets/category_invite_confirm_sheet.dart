import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';
import 'package:easy_localization/easy_localization.dart';

import 'category_invitee_preview.dart';

class CategoryInviteConfirmSheet extends StatelessWidget {
  final String categoryName;
  final String categoryImageUrl;
  final List<CategoryInviteePreview> invitees;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onViewFriends;

  const CategoryInviteConfirmSheet({
    super.key,
    required this.categoryName,
    required this.categoryImageUrl,
    required this.invitees,
    required this.onAccept,
    required this.onDecline,
    this.onViewFriends,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28.r),
          topRight: Radius.circular(28.r),
        ),
      ),
      padding: EdgeInsets.only(top: 7.h),
      child: SafeArea(
        top: false,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                ),

                SizedBox(height: 24.h),
                _buildCategoryThumbnail(),

                if (invitees.isNotEmpty) SizedBox(height: 24.h),
                SizedBox(height: 24.h),
                Text(
                  tr(
                    'notification.invite.title',
                    context: context,
                    namedArgs: {'name': categoryName},
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFF8F8F8),
                    fontSize: 19.78,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  tr('notification.invite.message', context: context),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFF8F8F8),
                    fontSize: 14,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.40,
                  ),
                ),
                SizedBox(height: 28.h),
                ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,

                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                  child: SizedBox(
                    width: 344,
                    height: 38,
                    child: Center(
                      child: Text(
                        tr('notification.invite.accept', context: context),
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 17.78,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                ElevatedButton(
                  onPressed: onDecline,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(19),
                    ),
                  ),
                  child: SizedBox(
                    width: 344,
                    height: 38,
                    child: Center(
                      child: Text(
                        tr('common.cancel', context: context),
                        style: TextStyle(
                          color: const Color(0xFFCBCBCB),
                          fontSize: 17.78,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (invitees.isNotEmpty)
              Positioned(top: 80, child: _buildInviteeContainer()),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryThumbnail() {
    if (categoryImageUrl.isEmpty) {
      return _placeholder();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6.61),
      child: CachedNetworkImage(
        width: 64,
        height: 64,
        memCacheWidth: (64 * 2).round(),
        maxWidthDiskCache: (64 * 2).round(),
        imageUrl: categoryImageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => _shimmerPlaceholder(),
        errorWidget: (context, url, error) => _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: ShapeDecoration(
        color: const Color(0xE5C4C4C4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6.61),
        ),
      ),
      child: Icon(Icons.image, color: const Color(0xFF595959), size: 28.sp),
    );
  }

  Widget _shimmerPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6.61),
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF2A2A2A),
        highlightColor: const Color(0xFF3A3A3A),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(6.61),
          ),
        ),
      ),
    );
  }

  Widget _buildInviteeContainer() {
    // 최대 2개의 프로필만 표시
    final displayInvitees = invitees.take(2).toList();
    final profileSize = 19.31;
    final overlapDistance = 12.0;
    final containerPadding = 6.0; // 좌우 패딩

    // 전체 너비 계산: 패딩 + 프로필들 + 아이콘(겹침) + 패딩
    final contentWidth =
        profileSize + (displayInvitees.length - 1) * overlapDistance;
    final containerWidth = contentWidth + (containerPadding * 2);

    return Column(
      children: [
        // NOTE: 초대된 유저 목록 보기 기능은 일단 비활성화합니다.
        Container(
          width: containerWidth,
          height: 23,
          decoration: ShapeDecoration(
            color: const Color(0xFF808080),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: Center(
            child: SizedBox(
              height: profileSize,
              width: contentWidth,
              child: Stack(
                children: [
                  ...displayInvitees.asMap().entries.map((entry) {
                    final index = entry.key;
                    final invitee = entry.value;

                    return Positioned(
                      left: index * overlapDistance,
                      child: _buildInviteeAvatar(invitee),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        /* TextButton(
          onPressed: onViewFriends,
          child: Text(
            '친구 확인',
            style: TextStyle(
              color: const Color(0xFFEDEDED),
              fontSize: 12.sp,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              letterSpacing: -0.25,
            ),
          ),
        ),*/
      ],
    );
  }

  Widget _buildInviteeAvatar(CategoryInviteePreview invitee) {
    return Container(
      width: 19.31,
      height: 19.31,
      decoration: BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: invitee.profileImageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: invitee.profileImageUrl,
                memCacheWidth: (19.31 * 4).round(),
                maxWidthDiskCache: (19.31 * 4).round(),
                fit: BoxFit.cover,
                placeholder: (context, url) => _shimmerAvatarPlaceholder(),
                errorWidget: (context, url, error) => _avatarPlaceholder(),
              )
            : _avatarPlaceholder(),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFd9d9d9),
      ),
      child: Icon(Icons.person, size: 16.sp, color: Colors.white),
    );
  }

  Widget _shimmerAvatarPlaceholder() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: const Color(0xFF3A3A3A),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF2A2A2A),
        ),
      ),
    );
  }
}
