import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../api/controller/notification_controller.dart' as api;
import '../../api/controller/user_controller.dart';
import '../../api/models/notification.dart';
import 'widgets/api_notification_item_widget.dart';

/// 알림 메인 화면 (API 버전)
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late api.NotificationController _notificationController;
  late ScrollController _scrollController;

  bool _isLoading = false;
  String? _error;
  NotificationGetAllResult? _notificationResult;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    PaintingBinding.instance.imageCache.clear();
    super.dispose();
  }

  /// 알림 로드
  Future<void> _loadNotifications() async {
    final userController = context.read<UserController>();
    final user = userController.currentUser;

    if (user == null) {
      setState(() {
        _error = '로그인이 필요합니다';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _notificationController = context.read<api.NotificationController>();
      final result = await _notificationController.getAllNotifications(
        userId: user.id,
      );

      if (mounted) {
        setState(() {
          _notificationResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '알림을 불러올 수 없습니다: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// 새로고침 처리
  Future<void> _onRefresh() async {
    final userController = context.read<UserController>();
    final user = userController.currentUser;

    if (user != null) {
      _notificationController.invalidateCache();
      await _loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          SizedBox(height: 20.h),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// AppBar 구성
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: Color(0xffd9d9d9)),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '알림',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              color: const Color(0xFFF8F8F8),
              fontSize: 20.sp,
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Body 구성
  Widget _buildBody() {
    if (_isLoading && _notificationResult == null) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_notificationResult == null || !_notificationResult!.hasNotifications) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 친구 요청 섹션
        _buildFriendRequestSection(),
        SizedBox(height: 24.h),
        Padding(
          padding: EdgeInsets.only(left: 19.w),
          child: Text(
            "최근 7일",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.02.sp,
              fontFamily: 'Pretendard Variable',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: _buildNotificationList()),
      ],
    );
  }

  /// 친구 요청 섹션
  Widget _buildFriendRequestSection() {
    final requestCount = _notificationResult?.friendRequestCount ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed('/friend_requests');
      },
      child: Padding(
        padding: EdgeInsets.only(left: 19.w),
        child: Container(
          width: 354.w,
          height: 66.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xff1c1c1c),
          ),
          child: Row(
            children: [
              SizedBox(width: 18.w),
              Image.asset(
                'assets/friend_request_icon.png',
                width: 43,
                height: 43,
              ),
              SizedBox(width: 8.w),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '친구 요청',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.08,
                    ),
                  ),
                  Text(
                    requestCount > 0
                        ? '보류 중인 요청 $requestCount명'
                        : '받은 요청이 없습니다',
                    style: TextStyle(
                      color: const Color(0xFFCBCBCB),
                      fontSize: 13.sp,
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (requestCount > 0) ...[
                Container(
                  width: 20.w,
                  height: 20.h,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      requestCount > 99 ? '99+' : '$requestCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
              ],
              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 23.sp),
              SizedBox(width: 12.w),
            ],
          ),
        ),
      ),
    );
  }

  /// 로딩 상태
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xff634D45)),
          SizedBox(height: 16.h),
          Text(
            '알림을 불러오는 중...',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xff535252),
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  /// 에러 상태
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.sp, color: Colors.red),
          SizedBox(height: 16.h),
          Text(
            '알림을 불러올 수 없습니다',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: Colors.white,
              fontSize: 20.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _error ?? '알 수 없는 오류가 발생했습니다',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xff535252),
              fontSize: 16.sp,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: _onRefresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff634D45),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  /// 빈 상태
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64.sp,
            color: const Color(0xff535252).withValues(alpha: 0.5),
          ),
          SizedBox(height: 16.h),
          Text(
            '알림이 없습니다',
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              color: const Color(0xff535252),
              fontSize: 20.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '새로운 알림이 오면 여기에 표시됩니다',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xff535252).withValues(alpha: 0.7),
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }

  /// 알림 목록
  Widget _buildNotificationList() {
    final notifications = _notificationResult?.notifications ?? [];

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xff634D45),
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xff1c1c1c),
            ),
            child: Column(
              children: [
                SizedBox(height: 22.h),
                for (int i = 0; i < notifications.length; i++)
                  ApiNotificationItemWidget(
                    notification: notifications[i],
                    profileUrl: notifications[i].userProfile,
                    imageUrl: notifications[i].imageUrl,
                    onTap: () => _onNotificationTap(notifications[i]),
                    isLast: i == notifications.length - 1,
                  ),
                SizedBox(height: 7.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 알림 탭 처리
  void _onNotificationTap(AppNotification notification) {
    // relatedId를 사용하여 관련 화면으로 이동
    if (notification.relatedId != null) {
      // TODO: relatedId에 따라 적절한 화면으로 이동
      debugPrint('알림 탭: relatedId=${notification.relatedId}');
    }
  }
}
