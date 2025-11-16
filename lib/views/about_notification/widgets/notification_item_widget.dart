import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../../api_firebase/models/notification_model.dart';

/// 개별 알림 아이템 위젯
class NotificationItemWidget extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isLast;
  final Future<List<String>> Function()? loadUnknownMembers;
  final Future<void> Function()? onConfirm;

  const NotificationItemWidget({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDelete,
    this.isLast = false,
    this.loadUnknownMembers,
    this.onConfirm,
  });

  @override
  State<NotificationItemWidget> createState() => _NotificationItemWidgetState();
}

class _NotificationItemWidgetState extends State<NotificationItemWidget> {
  Future<List<String>>? _unknownMembersFuture;

  @override
  void initState() {
    super.initState();
    _primeUnknownMembersFuture();
  }

  @override
  void didUpdateWidget(NotificationItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final notificationChanged =
        oldWidget.notification.id != widget.notification.id;
    final loaderChanged =
        oldWidget.loadUnknownMembers != widget.loadUnknownMembers;
    if (notificationChanged || loaderChanged) {
      _primeUnknownMembersFuture();
    }
  }

  void _primeUnknownMembersFuture() {
    if (widget.notification.type == NotificationType.categoryInvite &&
        widget.loadUnknownMembers != null) {
      final pending = widget.notification.pendingCategoryMemberIds;
      if (pending != null) {
        _unknownMembersFuture = Future.value(pending);
      } else {
        _unknownMembersFuture = widget.loadUnknownMembers!();
      }
    } else {
      _unknownMembersFuture = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notification.type == NotificationType.categoryInvite &&
        _unknownMembersFuture != null) {
      return FutureBuilder<List<String>>(
        future: _unknownMembersFuture,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final hasUnknown = (snapshot.data?.isNotEmpty ?? false);
          if (!hasUnknown && !isLoading) {
            return _buildDefaultItem();
          }
          return _buildCategoryInviteItem(
            isLoading: isLoading,
            hasUnknown: hasUnknown,
          );
        },
      );
    }

    return _buildDefaultItem();
  }

  Widget _buildDefaultItem() {
    return InkWell(
      onTap: widget.onTap,
      child: Container(
        padding: EdgeInsets.only(left: 18.w, right: 18.w, bottom: 28.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildProfileImage(),
            SizedBox(width: 9.w),
            Expanded(child: _buildNotificationText()),
            SizedBox(width: 23.w),
            _buildThumbnail(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryInviteItem({
    required bool isLoading,
    required bool hasUnknown,
  }) {
    return InkWell(
      onTap: widget.onTap,
      child: Container(
        padding: EdgeInsets.only(left: 18.w, right: 18.w, bottom: 28.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildProfileImage(),
            SizedBox(width: 9.w),
            Expanded(child: _buildNotificationText()),
            SizedBox(width: 12.w),
            // 오른쪽에 로딩/확인 버튼 또는 썸네일 표시
            if (isLoading)
              SizedBox(
                width: 44.w,
                height: 44.h,
                child: Center(
                  child: SizedBox(
                    width: 24.w,
                    height: 24.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (hasUnknown || widget.notification.requiresAcceptance)
              _buildConfirmButton()
            else
              _buildThumbnail(),
          ],
        ),
      ),
    );
  }

  /// 프로필 이미지 구성
  Widget _buildProfileImage() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: widget.notification.actorProfileImage ?? '',
          width: 44,
          height: 44,
          memCacheHeight: (44 * 4).round(),
          maxWidthDiskCache: (44 * 4).round(),
          fit: BoxFit.cover,
          placeholder: (context, url) => _shimmerWidget(),
          errorWidget: (context, url, error) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xffd9d9d9),
            ),
            child: Icon(Icons.person, size: 26, color: Colors.white),
          ),
        ),
      ),
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
    final userName = widget.notification.actorName ?? '사용자';
    final remainingText = _getNotificationText();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(
                text: userName,
                style: TextStyle(
                  color: const Color(0xFFF8F8F8),
                  fontSize: 14,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.40,
                ),
              ),
              TextSpan(
                text: remainingText,
                style: TextStyle(
                  color: const Color(0xFFD9D9D9),
                  fontSize: 14,
                  fontFamily: 'Pretendard Variable',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.40,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 썸네일 이미지 구성
  Widget _buildThumbnail() {
    switch (widget.notification.type) {
      case NotificationType.categoryInvite:
        return _buildCategoryThumbnail();
      case NotificationType.photoAdded:
        return _buildPhotoThumbnail();
      case NotificationType.voiceCommentAdded:
        return _buildVoiceCommentThumbnail();
      case NotificationType.friendRequest:
        return _buildFriendRequestThumbnail();
    }
  }

  /// 카테고리 썸네일
  Widget _buildCategoryThumbnail() {
    final categoryImageUrl = widget.notification.categoryThumbnailUrl;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        color: Colors.grey[700],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: categoryImageUrl != null && categoryImageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: categoryImageUrl,
                width: 44,
                height: 44,
                memCacheHeight: (44 * 2).round(),
                maxWidthDiskCache: (44 * 2).round(),
                fit: BoxFit.cover,
                placeholder: (context, url) => _shimmerWidget(),
                errorWidget: (context, url, error) => _buildCategoryIcon(),
              )
            : _buildCategoryIcon(),
      ),
    );
  }

  /// 사진 썸네일
  Widget _buildPhotoThumbnail() {
    final thumbnailUrl = widget.notification.photoThumbnailUrl;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        color: Colors.grey[700],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: thumbnailUrl,
                width: 44,
                height: 44,
                memCacheHeight: (44 * 2).round(),
                maxWidthDiskCache: (44 * 2).round(),
                fit: BoxFit.cover,
                placeholder: (context, url) => _shimmerWidget(),
                errorWidget: (context, url, error) => _buildPhotoIcon(),
              )
            : _buildPhotoIcon(),
      ),
    );
  }

  /// 음성 댓글 썸네일
  Widget _buildVoiceCommentThumbnail() {
    return SizedBox(
      width: 44,
      height: 44,
      child: ClipRRect(
        child: Image.asset("assets/record_notification_icon.png"),
      ),
    );
  }

  /// 친구 요청 썸네일
  Widget _buildFriendRequestThumbnail() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.r),
        color: const Color(0xFF323232),
      ),
      child: Icon(Icons.person_add_alt, size: 24, color: Color(0xffd9d9d9)),
    );
  }

  /// 알림 타입별 텍스트 반환
  String _getNotificationText() {
    switch (widget.notification.type) {
      case NotificationType.categoryInvite:
        return widget.notification.requiresAcceptance
            ? '님이 새 카테고리에 초대했습니다. 수락하시겠어요?'
            : '님이 새 카테고리에 초대했습니다.';
      case NotificationType.photoAdded:
        return '님이 "${widget.notification.categoryName}" 카테고리에 사진을 추가하였습니다.';
      case NotificationType.voiceCommentAdded:
        return '님이 음성 댓글을 달았습니다.';
      case NotificationType.friendRequest:
        return '님이 친구 요청을 보냈습니다.';
    }
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: 44.w,
      height: 29.h,
      child: TextButton(
        onPressed: widget.onConfirm == null ? null : () => widget.onConfirm!(),
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

  /// 공통 위젯들
  Widget _buildCategoryIcon() {
    return Icon(Icons.folder_outlined, size: 24.sp, color: Color(0xffd9d9d9));
  }

  Widget _buildPhotoIcon() {
    return Icon(Icons.photo_outlined, size: 24.sp, color: Color(0xffd9d9d9));
  }
}
