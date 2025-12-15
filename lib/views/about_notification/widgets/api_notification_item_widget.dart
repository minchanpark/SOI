import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

import '../../../api/models/notification.dart';

/// API 기반 개별 알림 아이템 위젯
class ApiNotificationItemWidget extends StatelessWidget {
  final AppNotification notification;
  final String? profileUrl;
  final String? imageUrl;
  final VoidCallback onTap;
  final VoidCallback? onConfirm;
  final bool isLast;

  const ApiNotificationItemWidget({
    super.key,
    required this.notification,
    this.profileUrl,
    this.imageUrl,
    required this.onTap,
    this.onConfirm, // 카테고리 초대 알림 확인 버튼 콜백
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(left: 18.w, right: 18.w, bottom: 28.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildProfileImage(),
            SizedBox(width: 9.w),
            Expanded(child: _buildNotificationText()),
            SizedBox(width: 12.w),
            if (notification.type == AppNotificationType.categoryInvite)
              _buildConfirmButton()
            else if (notification.hasImage)
              _buildThumbnail(),
          ],
        ),
      ),
    );
  }

  /// 프로필 이미지 구성
  Widget _buildProfileImage() {
    debugPrint("(notification item)profileUrl: $profileUrl");
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: profileUrl != null && profileUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: profileUrl!,
                width: 44,
                height: 44,
                memCacheHeight: (44 * 4).round(),
                maxWidthDiskCache: (44 * 4).round(),
                fit: BoxFit.cover,
                placeholder: (context, url) => _shimmerWidget(),
                errorWidget: (context, url, error) => _profilePlaceholder(),
              )
            : _profilePlaceholder(),
      ),
    );
  }

  Widget _profilePlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xffd9d9d9),
      ),
      child: const Icon(Icons.person, size: 26, color: Colors.white),
    );
  }

  // 로딩시에 사용할 shimmer 위젯
  Widget _shimmerWidget() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2A2A2A),
      highlightColor: const Color(0xFF3A3A3A),
      child: Container(
        decoration: const BoxDecoration(color: Color(0xFF2A2A2A)),
      ),
    );
  }

  /// 알림 텍스트 구성
  Widget _buildNotificationText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notification.text ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFFD9D9D9),
            fontSize: 14,
            fontFamily: 'Pretendard Variable',
            fontWeight: FontWeight.w500,
            letterSpacing: -0.40,
          ),
        ),
      ],
    );
  }

  /// 썸네일 이미지 구성
  Widget _buildThumbnail() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        color: Colors.grey[700],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                width: 44,
                height: 44,
                memCacheHeight: (44 * 2).round(),
                maxWidthDiskCache: (44 * 2).round(),
                fit: BoxFit.cover,
                placeholder: (context, url) => _shimmerWidget(),
                errorWidget: (context, url, error) => _thumbnailPlaceholder(),
              )
            : _thumbnailPlaceholder(),
      ),
    );
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        color: const Color(0xFF323232),
      ),
      child: Icon(Icons.image, size: 24.sp, color: const Color(0xffd9d9d9)),
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: 44.w,
      height: 29.h,
      child: TextButton(
        onPressed: onConfirm ?? onTap,
        style: TextButton.styleFrom(
          backgroundColor: const Color(0xFFF3F3F3),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(19.70),
          ),
        ),
        child: Text(
          '확인',
          style: TextStyle(
            color: const Color(0xFF1C1C1C),
            fontSize: 12.sp,
            fontFamily: 'Pretendard Variable',
            fontWeight: FontWeight.w700,
            letterSpacing: -0.40,
          ),
        ),
      ),
    );
  }
}
