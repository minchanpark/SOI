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
  final bool isLast;

  const ApiNotificationItemWidget({
    super.key,
    required this.notification,
    this.profileUrl,
    this.imageUrl,
    required this.onTap,
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
            if (notification.hasImage) ...[
              SizedBox(width: 23.w),
              _buildThumbnail(),
            ],
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
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF2A2A2A),
        ),
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
}
