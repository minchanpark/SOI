import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

import 'category_invitee_preview.dart';

/// 카테고리 초대 친구 목록 시트
class CategoryInviteFriendListSheet extends StatelessWidget {
  final List<CategoryInviteePreview> invitees;
  final ValueChanged<CategoryInviteePreview>? onInviteeTap;

  const CategoryInviteFriendListSheet({
    super.key,
    required this.invitees,
    this.onInviteeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF323232),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.8),
          topRight: Radius.circular(24.8),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 7.h),
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
            SizedBox(height: 16.h),
            Text(
              '친구 확인',
              style: TextStyle(
                color: const Color(0xFFF8F8F8),
                fontSize: 19.78,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 10.h),
            Divider(
              color: const Color(0xFF464646).withValues(alpha: 0.7),
              indent: 29.w,
              endIndent: 29.w,
            ),

            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                itemBuilder: (context, index) {
                  final invitee = invitees[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _FriendAvatar(imageUrl: invitee.profileImageUrl),
                    title: Text(
                      invitee.displayName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      invitee.id,
                      style: TextStyle(
                        color: const Color(0xFFD9D9D9),
                        fontSize: 10,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    onTap: onInviteeTap != null
                        ? () => onInviteeTap!(invitee)
                        : null,
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: invitees.length,
              ),
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  final String imageUrl;

  const _FriendAvatar({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                memCacheWidth: (44 * 4).round(),
                maxWidthDiskCache: (44 * 4).round(),
                fit: BoxFit.cover,
                placeholder: (context, url) => _shimmerPlaceholder(),
                errorWidget: (context, url, error) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFd9d9d9),
      ),
      child: Icon(Icons.person, color: Colors.white, size: 26),
    );
  }

  Widget _shimmerPlaceholder() {
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
