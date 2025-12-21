import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../api/controller/friend_controller.dart';
import '../../../api/controller/notification_controller.dart';
import '../../../api/controller/user_controller.dart';
import '../../../api/models/friend.dart';
import '../../../api/models/notification.dart';

/// REST API 기반 친구 요청 카드
class FriendRequestCard extends StatefulWidget {
  final double scale;

  const FriendRequestCard({super.key, required this.scale});

  @override
  State<FriendRequestCard> createState() => _FriendRequestCardState();
}

class _FriendRequestCardState extends State<FriendRequestCard> {
  bool _isFetching = false;
  bool _initialized = false;
  String? _errorMessage;
  final Set<int> _processingFriendIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadFriendRequests(showSpinner: true);
        }
      });
    }
  }

  Future<void> _loadFriendRequests({bool showSpinner = false}) async {
    final userController = context.read<UserController>();
    final userId = userController.currentUserId;
    if (userId == null) {
      setState(() {
        _errorMessage = '로그인이 필요합니다.';
      });
      return;
    }

    if (showSpinner) {
      setState(() {
        _isFetching = true;
        _errorMessage = null;
      });
    }

    try {
      await context.read<NotificationController>().getFriendNotifications(
        userId: userId,
      );
      if (mounted) {
        setState(() {
          _errorMessage = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = '친구 요청을 불러오지 못했습니다.';
        });
      }
    } finally {
      if (showSpinner && mounted) {
        setState(() {
          _isFetching = false;
        });
      }
    }
  }

  Future<void> _handleRequest(
    AppNotification notification,
    FriendStatus status,
  ) async {
    final userId = context.read<UserController>().currentUserId;
    final friendId = notification.relatedId;
    if (friendId == null) {
      _showSnackBar('요청 정보를 찾을 수 없습니다.');
      return;
    }

    setState(() => _processingFriendIds.add(friendId));
    final friendController = context.read<FriendController>();

    // 친구 상태 업데이트
    final result = await friendController.updateFriendStatus(
      friendId: friendId,
      status: status,
      notificationId: notification.id!,
    );

    if (!mounted) return;

    setState(() => _processingFriendIds.remove(friendId));

    if (result != null && mounted) {
      // 친구 요청 목록 갱신
      await _loadFriendRequests();

      // userId가 null이 아닐 때만 친구 목록 갱신
      if (userId != null && mounted) {
        // 친구 목록 갱신
        await friendController.refreshFriends(userId: userId);
      }
      _showSnackBar(
        status == FriendStatus.accepted ? '친구 요청을 수락했습니다' : '친구 요청을 거절했습니다',
      );
    } else {
      _showSnackBar('요청 처리에 실패했습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF5A5A5A),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationController>(
      builder: (context, notificationController, child) {
        final requests =
            notificationController.cachedFriendNotifications ??
            const <AppNotification>[];
        final showLoading = _isFetching && requests.isEmpty;

        return SizedBox(
          width: 354.w,
          child: Card(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            color: const Color(0xff1c1c1c),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                if (showLoading)
                  _buildStatePlaceholder('친구 요청을 불러오는 중...')
                else if (_errorMessage != null && requests.isEmpty)
                  _buildStatePlaceholder(_errorMessage!)
                else if (requests.isEmpty)
                  _buildStatePlaceholder('받은 친구 요청이 없습니다')
                else
                  ...requests.map(_buildFriendRequestItem),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatePlaceholder(String message) {
    return SizedBox(
      height: 132.h,
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: const Color(0xff666666), fontSize: 14.sp),
        ),
      ),
    );
  }

  Widget _buildFriendRequestItem(AppNotification notification) {
    final friendId = notification.relatedId;
    final isProcessing =
        friendId != null && _processingFriendIds.contains(friendId);
    final canRespond = friendId != null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildProfileAvatar(notification.userProfile),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.text ?? '새로운 친구 요청이 도착했어요',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xffd9d9d9),
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '친구 요청을 수락하거나 거절할 수 있어요',
                  style: TextStyle(
                    color: const Color(0xff8a8a8a),
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          if (isProcessing)
            SizedBox(
              width: 24.w,
              height: 24.h,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xfff9f9f9),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  label: '거절',
                  backgroundColor: const Color(0xff333333),
                  textColor: const Color(0xff999999),
                  onTap: canRespond
                      ? () =>
                            _handleRequest(notification, FriendStatus.cancelled)
                      : null,
                ),
                SizedBox(width: 8.w),
                _buildActionButton(
                  label: '수락',
                  backgroundColor: const Color(0xfff9f9f9),
                  textColor: const Color(0xff1c1c1c),
                  onTap: canRespond
                      ? () =>
                            _handleRequest(notification, FriendStatus.accepted)
                      : null,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(String? profileUrl) {
    final safeUrl = profileUrl ?? '';
    final hasProfile = safeUrl.isNotEmpty;
    return CircleAvatar(
      radius: (22).w,
      backgroundColor: const Color(0xff323232),
      child: ClipOval(
        child: hasProfile
            ? CachedNetworkImage(
                imageUrl: safeUrl,
                fit: BoxFit.cover,
                width: (44).w,
                height: (44).w,
                memCacheHeight: (44 * 4).round(),
                maxWidthDiskCache: (44 * 4).round(),
                errorWidget: (_, __, ___) =>
                    const Icon(Icons.person, color: Colors.white),
              )
            : const Icon(Icons.person, color: Colors.white),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: 50.w,
      height: 30.h,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          padding: EdgeInsets.zero,
          elevation: 0,
          disabledBackgroundColor: const Color(0xff3a3a3a),
          disabledForegroundColor: const Color(0xff777777),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            fontFamily: 'Pretendard',
          ),
        ),
      ),
    );
  }
}
